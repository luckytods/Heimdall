import nmap
import psutil
import sched
import time
import socket
import struct
from datetime import datetime
import databse_commands as db


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


#-------------------------------------------#
#--------------Função main------------------#
#-------------------------------------------#

# Inicializa o scanner
nm = nmap.PortScanner()

conn = connect_to_db()

myIP, target, MACadd = get_my_info()    #Define IP e Mac address da máquine e coleta rede

scan_arguments = '-sP -O' #Ver se isso será necessário

nm.scan(hosts=target, arguments='-sn') #Primeiro Scan para achar dispositivos conectados apenas

hosts = nm.all_hosts()


# Imprime os resultados das portas, SOs e scripts NSE
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


    timestamp = datetime.now()


    row = db.fetch_by_ip(conn, host)

    print(f'{row}\n\n')

    if row:
        if row[3] == mac:
            updates = {"last_online": timestamp}
            db.update_device(conn, row[0], updates)
            continue

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