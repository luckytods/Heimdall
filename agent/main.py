import nmap
import re
import psutil
import time
import socket
import struct
import threading
import multiprocessing
from easysnmp import Session
from datetime import datetime
import databse_commands as db
from config import community


#-------------------------------------------------#
#--------------Variáveis Globais------------------#
#-------------------------------------------------#


db_thread_lock = threading.Lock()

db_process_lock = multiprocessing.Lock()

hosts_list = None


#-------------------------------------------------#
#--------------Definindo funções------------------#
#-------------------------------------------------#


#Função para encerrar o processo
def encerrar_processo(cod=0):
    print(f'Encerrando processo...')
    exit(cod)

#Transforma uma lista em uma string separado por ESPAÇO
def ips_to_string(ip_list):
    return ' '.join(ip_list)

#Coleta e retorna o Mac, ip e rede deste dispositivo
def get_my_info(): #Retorna IP da máquina, o MAC address e a rede
    # Obter informações sobre as interfaces de rede
    addrs = psutil.net_if_addrs()
    
    # Exibir todas as interfaces disponíveis
   # print("Interfaces disponíveis:", list(addrs.keys()))
    
    # Selecionar automaticamente a primeira interface válida (que possui um IP e não é uma interface de loopback)
    for interface_name, addresses in addrs.items():
        for addr in addresses:
            if addr.family == socket.AF_INET and not addr.address.startswith('127.'):
                ip_address = addr.address
                netmask = addr.netmask
                mac_address = next(
                    (a.address for a in addresses if a.family == psutil.AF_LINK),
                    None
                )
                
                if ip_address and netmask and mac_address:
                    # Calcular a rede
                    ip_bin = struct.unpack('>I', socket.inet_aton(ip_address))[0]
                    mask_bin = struct.unpack('>I', socket.inet_aton(netmask))[0]
                    network = socket.inet_ntoa(struct.pack('>I', ip_bin & mask_bin))
                    
                    # Contar os bits 1 na máscara de sub-rede
                    cidr = sum(bin(int(octet)).count('1') for octet in netmask.split('.'))
                    
                    # Formato final da rede
                    network_cidr = f"{network}/{cidr}"
                    
                    return ip_address, network_cidr, mac_address

    raise ValueError("Nenhuma interface válida encontrada.")

#Realiza a conexão com o DB de forma controlada
def connect_to_db():
    #Tenta se conectar ao bd 10 vezes no maximo
    for tentativas in range(10):
        print(f'\t({tentativas+1})Conectando ao Banco de Dados...\n')
        conn = db.create_connection()
        print(f'Conexão com Banco de Dados: {conn}')
        if conn.is_connected():
            break
        print(f'\tTentando novamente...\n')

    #Caso a conexão tenha falhado, encerra o processo.
    if not conn.is_connected():
        print(f'Não foi possivel se conectar ao Banco de Dados. Verifique se as informações inseridas em config.py estão corretas.')
        encerrar_processo(1)

    if db.execute_login(conn): #Caso login feito, segue com o programa
        print(f'\nLogin feito com sucesso.')
        return conn
    
    print(f'\nNome de usuário ou senha inválida. Por favor confira as informações na tela de configuração e tente de novo.\n')
    encerrar_processo(2)
    
#Salva informações na tabela devices
def save_scan_info(conn, host, mac, os):

    timestamp = datetime.now()
    row = db.fetch_by_ip(conn, host)
    db.update_agent_timestamp(conn, timestamp)

    if row:
        if row[4] == mac:
            if (os == None) or (row[5] != None and row[7] == 1):
                updates = {"last_online": timestamp,
                           "status": "online"}
            else:
                updates = {"last_online": timestamp,
                           "os": os,
                           "status": "online"}
            db.update_device(conn, row[0], updates)
            return

        else:
            updates = { "ip_address": None,
                        "last_online": timestamp,
                        "status": "online"}
            
            db.update_device(conn, row[0], updates)
    
    row = db.fetch_by_mac(conn, mac)
    if row:
        if (os == None) or (row[5] != None and row[7] == 1):
            updates = { "ip_address": host,
                        "last_online": timestamp,
                        "status": "online"}
        else:
            updates = { "ip_address": host,
                        "os": os,
                        "last_online": timestamp,
                        "status": "online"}
        db.update_device(conn, row[0], updates)
    else:
        db.insert_device(conn, timestamp, host, 0, mac, os)
    
#Salva informações na tabela device_ports
def save_ports(conn, host, ports = None):
    row = db.fetch_by_ip(conn, host)
    print(f'row:{row}')
    host_id = row[0]
    print(f'ID:{host_id}')
    db.delete_unused_ports(conn, host_id, ports)
    new_ports = db.get_ports_not_in_db(conn, host_id, ports)
    db.add_ports_to_db(conn, host_id, new_ports)

#função referente ao scan rápido de reconhecimento
def scan_ICMP(nm, target, myIP, MACadd):

    nm.scan(hosts=target, arguments='-sn') #Primeiro Scan para achar dispositivos conectados apenas

    global hosts_list
    hosts_list = nm.all_hosts()

    conn = connect_to_db()

    for host in nm.all_hosts():
        print(f'Host: {host}')
        os = None
        mac = None

        if 'mac' in nm[host]['addresses']:
            mac = nm[host]["addresses"]["mac"]
            print(f'MAC Address: {mac}')
        elif host == myIP:
            mac = MACadd
            print(f'MAC Address: {mac}')
        else:
            print('MAC Address: Não encontrado')
        
        with db_thread_lock:
            print(f'antes do save info')
            save_scan_info(conn, host, mac, os)

        with db_thread_lock:
            db.update_device_status(conn, hosts_list)

    print(f'Sleeping for 10 seconds')
    time.sleep(10)

#função referente ao scan mais intensivo 
def scan_intenssivo(myIP, MACadd):

    nm = nmap.PortScanner()

    conn = connect_to_db()

    scan_arguments = "-O -sS -p 21,22,23,25,53,80,110,139,143,443,445,3389,3306,5900,8080 -T4 --osscan-guess --version-intensity 5"
    global hosts_list
    target = ips_to_string(hosts_list)
    print(f'{target}')

    nm.scan(hosts = target, arguments = scan_arguments) #Scan intenssivo e demorado. Acho q vou reduzir bem sua frequencia
    for host in nm.all_hosts():
        print(f'Host: {host}')
        os = None
        mac = None
        if 'mac' in nm[host]['addresses']:
            mac = nm[host]["addresses"]["mac"]
            print(f'MAC Address: {mac}')
        elif host == myIP:
            mac = MACadd
            print(f'MAC Address: {mac}')
        else:
            print('MAC Address: Não encontrado')
        
        accAux1 = 0
        accAux2 = 0
        if 'osclass' in nm[host]:
            print("Detected OS:")
            for osclass in nm[host]['osclass']:
                print(f"OS: {osclass['osfamily']}")
                print(f"Version: {osclass['osgen']}")
                print(f"Accuracy: {osclass['accuracy']}")
                if int(osclass['accuracy']) > int(accAux1):
                    accAux1 = osclass['accuracy']
                    os = osclass['osfamily']
        elif 'osmatch' in nm[host]:
            print("OS Match:")
            for osmatch in nm[host]['osmatch']:
                print(f"Name: {osmatch['name']}")
                print(f"Accuracy: {osmatch['accuracy']}")
                if int(osmatch['accuracy']) > int(accAux2):
                    accAux2 = osmatch['accuracy']
                    os = osmatch['name']
        else:
            print("No OS information available.")

        open_ports = []
        if 'tcp' in nm[host]:
            for port in nm[host]['tcp']:
                if nm[host]['tcp'][port]['state'] == 'open':
                    open_ports.append(port)

        with db_thread_lock:
            save_scan_info(conn, host, mac, os)
            save_ports(conn, host, open_ports)

    print(f'Sleeping for 40 seconds')
    time.sleep(40)

# Função para coletar o uso de banda larga
def collect_bandwidth_usage(session, oid_in_octets, oid_out_octets ):

    interval = 20

    try:
        # Obter os valores atuais de bytes recebidos e enviados
        in_octets = int(session.get(oid_in_octets).value)
        out_octets = int(session.get(oid_out_octets).value)
        
        # Pausar por um intervalo de tempo
        time.sleep(interval)
        
        # Obter os valores de bytes recebidos e enviados após o intervalo
        in_octets_new = int(session.get(oid_in_octets).value)
        out_octets_new = int(session.get(oid_out_octets).value)
        
        # Calcular a diferença para obter o uso durante o intervalo
        in_usage = (in_octets_new - in_octets) / interval  # Bytes recebidos por segundo
        out_usage = (out_octets_new - out_octets) / interval  # Bytes enviados por segundo
        
        # Converter para Kilobits por segundo (kbps)
        in_kbps = (in_usage * 8) / 1024
        out_kbps = (out_usage * 8) / 1024
        
        return in_kbps, out_kbps
    
    except Exception as e:
        print(f'Erro ao coletar o uso de banda: {e}')
        return None, None
    
def collect_SO_info(session):
    oid_sys_descr = '1.3.6.1.2.1.1.1.0'
    try:
        # Coletar sysDescr
        sys_descr = session.get(oid_sys_descr).value
        # Filtrar apenas a parte de software do sistema usando expressões regulares
        # Esta regex é apenas um exemplo e pode precisar de ajustes dependendo da string retornada
        so_info = re.search(r'Software: (.*)', sys_descr)
        if so_info:
            return so_info.group(1)  # Retorna apenas a parte de software
        else:
            return "Informação de software não encontrada."
    except Exception as e:
        print(f'Erro ao coletar informações: {e}')
        return None
    
def collect_device_name(session):
    oid_sys_name = '1.3.6.1.2.1.1.5.0'
    try:
        sys_name = session.get(oid_sys_name).value  # Coletar nome do dispositivo
        return sys_name
    except Exception as e:
        print(f'Erro ao coletar informações: {e}')
        return None

def collect_uptime(session):
    oid_sys_uptime = '1.3.6.1.2.1.1.3.0'
    try:
        # Coletar o sysUpTime em centésimos de segundo
        uptime_ticks = int(session.get(oid_sys_uptime).value)
        
        # Converter de centésimos de segundo para segundos
        uptime_seconds = uptime_ticks / 100
        
        return uptime_seconds
    except Exception as e:
        print(f'Erro ao coletar o uptime: {e}')
        return None

def save_bandwidth_monitoring(conn, device_id, in_kbps, out_kbps):
    timestamp = datetime.now()
    db.insert_bandwidth_monitoring(conn, device_id, timestamp, in_kbps, out_kbps)

# Monitorar o uso de banda larga
def monitor_bandwidth_usage(target_id, target, community):
    conn = connect_to_db()
    device_info = db.check_snmp(conn, target_id)
    session = Session(hostname=target, community=community, version=2)

    so_info = collect_SO_info(session)
    if device_info[2] == None:
        device_name = collect_device_name(session)
        if device_name != None:
            if so_info != None:
                updates = {"device_name":device_name,
                           "os": so_info}
            else:
                updates = {"device_name":device_name}
    else:
        if so_info != None:
            updates = {"os": so_info}
        else:
            updates = None
    if updates != None:
        db.update_device(conn, target_id, updates)

    # OIDs de 32 bits para bytes recebidos e enviados na interface (use o índice correto da interface)
    oid_in_octets_start = '1.3.6.1.2.1.2.2.1.10.'  # ifInOctets
    oid_out_octets_start = '1.3.6.1.2.1.2.2.1.16.'  # ifOutOctets

    if device_info[10] != None:
        aux = device_info[10]
        oid_in_octets = f'{oid_in_octets_start}{aux}'
        oid_out_octets = f'{oid_out_octets_start}{aux}'
        flag = False
    
    else:
        flag = True
        aux = 0
        oid_in_octets = f'{oid_in_octets_start}{aux}'
        oid_out_octets = f'{oid_out_octets_start}{aux}'

    while True:
        in_kbps, out_kbps = collect_bandwidth_usage(session, oid_in_octets, oid_out_octets)
        uptime = collect_uptime(session)

        if uptime != None:
            updates = {"upTime":uptime}
            db.update_device(conn, target_id, updates)
        elif device_info[8] != "online":
            uptime = 0
            updates = {"upTime":uptime}
            db.update_device(conn, target_id, updates)
        else:
            print(f"Erro ao coletar o upTime")

        if (in_kbps is not None and out_kbps is not None) and (in_kbps > 0.0 and out_kbps > 0.0):
            print(f'Download: {in_kbps:.2f} kbps | Upload: {out_kbps:.2f} kbps')
            save_bandwidth_monitoring(conn, target_id, in_kbps, out_kbps)
            if flag:
                updates = {"bandwidth_oid_index":aux}
                db.update_device(conn, target_id, updates)
                flag = False

        else:
            print('Erro ao obter dados')
            if device_info[8] == "online":
                if flag:
                    if aux < 40:
                        aux = aux+1
                    else:
                        aux = 0
                    oid_in_octets = f'{oid_in_octets_start}{aux}'
                    oid_out_octets = f'{oid_out_octets_start}{aux}'
                else:
                    updates = {"bandwidth_oid_index":None}
                    db.update_device(conn, target_id, updates)
                    aux = 0
                    flag = True
            else:
                in_kbps=0.0
                out_kbps=0.0
                save_bandwidth_monitoring(conn, target_id, in_kbps, out_kbps)

        if db.check_snmp(conn, target_id) == None:
            break

def SNMP_monitoring(community):
    # Configurações SNMP
    conn = connect_to_db()
    targets = db.fetch_ip_by_snmp(conn)
    print(f'{targets}')
    threads =[]
    for i in range(len(targets)):
        thread = threading.Thread(target=monitor_bandwidth_usage, args=(targets[i][0], targets[i][1], community))
        threads.append(thread)
        thread.start()
    
    while True:
        targets_aux = db.fetch_ip_by_snmp(conn)
        for i in range(len(targets_aux)):
            if targets_aux[i] not in targets:
                thread = threading.Thread(target=monitor_bandwidth_usage, args=(targets_aux[i][0], targets_aux[i][1], community))
                threads.append(thread)
                thread.start()
        targets = targets_aux
        time.sleep(10)

#-------------------------------------------------#
#-----------------Função main---------------------#
#-------------------------------------------------#

# Inicializa o scanner
nm = nmap.PortScanner()

conn = connect_to_db()

myIP, target, MACadd = get_my_info()    #Define IP e Mac address da máquina e coleta rede

#define as threads para compração inicial no loop, porém não inicia
thread_discovery_scan = threading.Thread(target=scan_ICMP, args=(nm, target, myIP, MACadd))
thread_exploration_scan = threading.Thread(target=scan_intenssivo, args=(conn, nm, myIP, MACadd))

#primeiro scan feito forá do loop para definir a variavel global "hosts"
scan_ICMP(nm, target, myIP, MACadd)

process_SNMP_monitoring = multiprocessing.Process(target=SNMP_monitoring, args=(community,))
process_SNMP_monitoring.start()

while True:

    if not conn.is_connected(): #garante que está conectado ao bd duranto todo o processo.

        print(f'Entrou na area de DB desconectado')
        
        thread_discovery_scan.join()
        thread_exploration_scan.join()
        
        with db_process_lock:
            process_SNMP_monitoring.terminate()
            
        process_SNMP_monitoring.join()

        print(f'\n\nConexão com o Banco de dados perdida. Tentando reconectar...\n')
        conn = connect_to_db()
        myIP, target, MACadd = get_my_info()
        process_SNMP_monitoring = multiprocessing.Process(target=SNMP_monitoring, args=(community))
        process_SNMP_monitoring.start()


    if not thread_discovery_scan.is_alive():
        print(f'criando thread scan ping')
        thread_discovery_scan = threading.Thread(target=scan_ICMP, args=(nm, target, myIP, MACadd))
        thread_discovery_scan.start()

    if not thread_exploration_scan.is_alive():
        print(f'criando thread scan inten')
        thread_exploration_scan = threading.Thread(target=scan_intenssivo, args=(myIP, MACadd))
        thread_exploration_scan.start()

    
