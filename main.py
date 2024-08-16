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

hosts = None


#-------------------------------------------------#
#--------------Definindo funções------------------#
#-------------------------------------------------#


#Função para encerrar o processo
def encerrar_processo(cod=0):
    print(f'Encerrando processo...')
    exit(cod)

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

    timestamp = datetime.now()

    row = db.fetch_by_ip(conn, host)

    print(f'{row}\n\n')

    if row:
        if row[3] == mac:
            updates = {"last_online": timestamp}
            db.update_device(conn, row[0], updates)
            return

        else:
            updates = { "ip_address": None,
                        "last_online": timestamp}
            
            db.update_device(conn, row[0], updates)
    
    row = db.fetch_by_mac(conn, mac)
    if row:
        updates = { "ip_address": host,
                    "last_online": timestamp}
        db.update_device(conn, row[0], updates)
    else:
        db.insert_device(conn, timestamp, host, 0, mac, os,)
    
    if 'tcp' in nm[host]:
        for port in nm[host]['tcp']:
            port_info = nm[host]['tcp'][port]
            service_name = port_info.get('name', 'unknown')
            service_version = port_info.get('version', 'unknown')
            print(f'Port: {port}\tState: {port_info["state"]}\tService: {service_name}\tVersion: {service_version}')

def scan_ICMP(conn, nm, target, myIP, MACadd):

    nm.scan(hosts=target, arguments='-sn') #Primeiro Scan para achar dispositivos conectados apenas

    global hosts
    hosts = nm.all_hosts()

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

        if 'osclass' in nm[host]:
            for osclass in nm[host]['osclass']:
                print(f'OS: {osclass["osfamily"]} {osclass["osgen"]} {osclass["osvendor"]} {osclass["osaccuracy"]}%')
                os = nm[host]['osclass']["osfamily"]
        else:
            print(f'Não foi possível detectar o sistema operacional para {host}')
        
        with db_thread_lock:
            save_scan_info(conn, host, mac, os)

def scan_intenssivo():
    scan_arguments = "-O -sS -p 1-65535 -T4 --osscan-guess --version-intensity 5"

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
thread_discovery_scan = threading.Thread(target=scan_ICMP, args=(conn, nm, target, myIP, MACadd))
thread_exploration_scan = threading.Thread(target=scan_ICMP, args=(conn, nm, target, myIP, MACadd))

#primeiro scan feito forá do loop para definir a variavel global "hosts"
scan_ICMP(conn, nm, target, myIP, MACadd)

process_SNMP_monitoring = multiprocessing.Process(target=monitor_device, args=(community, ip_list))

while True:

    if not conn.is_connected(): #garante que está conectado ao bd duranto todo o processo.
        
        thread_discovery_scan.join()
        thread_exploration_scan.join()
        
        with db_process_lock:
            process_SNMP_monitoring.terminate()
            
        process_SNMP_monitoring.join()

        print(f'\n\nConexão com o Banco de dados perdida. Tentando reconectar...\n')
        conn = connect_to_db()
        myIP, target, MACadd = get_my_info()
        process_SNMP_monitoring = multiprocessing.Process(target=monitor_device, args=(community, ip_list))


    if not thread_discovery_scan.is_alive():
        thread_discovery_scan = threading.Thread(target=scan_ICMP, args=(conn, nm, target, myIP, MACadd))
        thread_discovery_scan.start()

    if not thread_exploration_scan.is_alive():
        thread_exploration_scan = threading.Thread(target=scan_ICMP, args=(conn, nm, target, myIP, MACadd))
        thread_exploration_scan.start()

    
