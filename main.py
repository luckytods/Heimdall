import nmap
import psutil
import sched
import time
import databse_commands as db


# Inicializa o scanner
nm = nmap.PortScanner()

conn = db.create_connection()
db.create_tables()

print(f'Conexão com BD: {conn}')

# Define o alvo
target = '192.168.0.0/24'

# Realiza a varredura completa com detecção de SO e argumentos adicionais
scan_arguments = '-sP'

nm.scan(hosts=target, arguments=scan_arguments)

# Imprime os resultados das portas, SOs e scripts NSE
for host in nm.all_hosts():
    print(f'Host: {host}')
    if 'mac' in nm[host]['addresses']:
        print(f'MAC Address: {nm[host]["addresses"]["mac"]}')
    else:
        print('MAC Address: Não encontrado')
    if 'osclass' in nm[host]:
        for osclass in nm[host]['osclass']:
            print(f'OS: {osclass["osfamily"]} {osclass["osgen"]} {osclass["osvendor"]} {osclass["osaccuracy"]}%')
    else:
        print(f'Não foi possível detectar o sistema operacional para {host}')
    
    if 'tcp' in nm[host]:
        for port in nm[host]['tcp']:
            port_info = nm[host]['tcp'][port]
            service_name = port_info.get('name', 'unknown')
            service_version = port_info.get('version', 'unknown')
            print(f'Port: {port}\tState: {port_info["state"]}\tService: {service_name}\tVersion: {service_version}')