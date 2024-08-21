import nmap
import psutil
import sched
import time
import socket
import struct
import threading
import multiprocessing
from easysnmp import Session, snmp_get, snmp_walk
from datetime import datetime
import databse_commands as db
from config import community, ip_list


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

def ips_to_string(ip_list):
    """
    Converte uma lista de IPs em uma única string, onde os IPs são separados por vírgulas.
    
    :param ip_list: Lista de endereços IP.
    :return: Uma string com os IPs separados por vírgulas.
    """
    print(f'socorro no string')
    return ' '.join(ip_list)


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

    db.create_tables() #Garante que as tabelas necessárias existam

    return conn

def save_scan_info(conn, host, mac, os):

    print(f'Socorro 1')
    timestamp = datetime.now()
    print(f'Socorro 2')
    row = db.fetch_by_ip(conn, host)
    print(f'Socorro 3')

    print(f'{row}\n\n')

    if row:
        if row[3] == mac:
            if os == None:
                updates = {"last_online": timestamp}
            else:
                updates = {"last_online": timestamp,
                           "os": os}
            db.update_device(conn, row[0], updates)
            return

        else:
            updates = { "ip_address": None,
                        "last_online": timestamp}
            
            db.update_device(conn, row[0], updates)
    
    row = db.fetch_by_mac(conn, mac)
    if row:
        if os == None:
            updates = { "ip_address": host,
                        "last_online": timestamp}
        else:
            updates = { "ip_address": host,
                        "os": os,
                        "last_online": timestamp}
        db.update_device(conn, row[0], updates)
    else:
        db.insert_device(conn, timestamp, host, 0, mac, os)
    

def save_ports(conn, host, ports = None):
    row = db.fetch_by_ip(conn, host)
    print(f'row:{row}')
    host_id = row[0]
    print(f'ID:{host_id}')
    db.delete_unused_ports(conn, host_id, ports)
    new_ports = db.get_ports_not_in_db(conn, host_id, ports)
    db.add_ports_to_db(conn, host_id, new_ports)

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
        
        #with db_thread_lock:
        print(f'antes do save info')
        save_scan_info(conn, host, mac, os)

    time.sleep(10)

def scan_intenssivo(myIP, MACadd):

    nm = nmap.PortScanner()

    print(f'Socorro intenso 1')

    conn = connect_to_db()
    print(f'Socorro intenso 1')

    scan_arguments = "-O -sS -p 21,22,23,25,53,80,110,139,143,443,445,3389,3306,5900,8080 -T4 --osscan-guess --version-intensity 5"
    global hosts_list
    print(f'Socorro intenso 1')
    target = ips_to_string(hosts_list)
    print(f'Socorro intenso 1')
    #target = '192.168.0.1'
    print(f'{target}')

    nm.scan(hosts = target, arguments = scan_arguments) #Scan intenssivo e demorado. Acho q vou reduzir bem sua frequencia
    print(f'Antes do for')
    print(f'Hosts: {nm.all_hosts()}')
    for host in nm.all_hosts():
        print(f'Host: {host}')
        os = None
        mac = None
        print(f'antes do mac')
        if 'mac' in nm[host]['addresses']:
            mac = nm[host]["addresses"]["mac"]
            print(f'MAC Address: {mac}')
        elif host == myIP:
            mac = MACadd
            print(f'MAC Address: {mac}')
        else:
            print('MAC Address: Não encontrado')
        
        print(f'antes do os')
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

        print(f'antes da port')
        open_ports = []
        if 'tcp' in nm[host]:
            for port in nm[host]['tcp']:
                if nm[host]['tcp'][port]['state'] == 'open':
                    open_ports.append(port)

        print(f'antes do lock')
        with db_thread_lock:
            print(f'lock - antes do save info')
            save_scan_info(conn, host, mac, os)
            print(f'lock - antes do save ports')
            save_ports(conn, host, open_ports)

    print(f'Antes do sleep')
    time.sleep(45)



def snmp_get_value(community, ip, oid):
    """
    Realiza uma requisição SNMP GET para obter um valor específico de uma OID.

    :param community: A comunidade SNMP (como uma senha) para acessar o dispositivo.
    :param ip: O endereço IP do dispositivo na rede.
    :param oid: A OID (Object Identifier) que você deseja consultar.
    :return: O valor obtido da OID.
    """
    session = Session(hostname=ip, community=community, version=2)
    try:
        result = session.get(oid)
        return result.value
    except Exception as e:
        print(f"Erro ao obter {oid} de {ip}: {e}")
        return None

def monitor_device(community, ip):
    """
    Monitora um dispositivo na rede usando SNMP para coletar várias métricas.

    :param community: A comunidade SNMP.
    :param ip: O endereço IP do dispositivo.
    """
    oids = {
        "sysDescr": "1.3.6.1.2.1.1.1.0",  # Descrição do sistema
        "sysUpTime": "1.3.6.1.2.1.1.3.0",  # Tempo de atividade do sistema
    }

    print(f"Monitorando dispositivo {ip}...")

    for key, oid in oids.items():
        value = snmp_get_value(community, ip, oid)
        if value is not None:
            print(f"{key}: {value}")
        else:
            print(f"Falha ao obter {key} do dispositivo {ip}")



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

process_SNMP_monitoring = multiprocessing.Process(target=monitor_device, args=(community, ip_list))

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
        process_SNMP_monitoring = multiprocessing.Process(target=monitor_device, args=(community, ip_list))


    # if not thread_discovery_scan.is_alive():
    #     print(f'criando thread scan ping')
    #     thread_discovery_scan = threading.Thread(target=scan_ICMP, args=(nm, target, myIP, MACadd))
    #     thread_discovery_scan.start()

    if not thread_exploration_scan.is_alive():
        print(f'criando thread scan inten')
        thread_exploration_scan = threading.Thread(target=scan_intenssivo, args=(myIP, MACadd))
        thread_exploration_scan.start()

    
