import nmap
import psutil
import sched
import time

# Inicializa o scanner
nm = nmap.PortScanner()

# Define o alvo
target_network = '192.168.0.0/24'
scan_arguments = '-sS -p 1-1024 -sV'

try:
    # Realiza uma varredura SYN nas portas 1-1024
    nm.scan(hosts=target_network, arguments=scan_arguments)

    # Verifica se a varredura encontrou hosts
    if not nm.all_hosts():
        print("Nenhum host encontrado.")
    else:
        # Imprime os resultados das portas
        for host in nm.all_hosts():
            print(f'Host: {host}')
            if 'tcp' in nm[host]:
                for port in nm[host]['tcp']:
                    port_info = nm[host]['tcp'][port]
                    service_name = port_info.get('name', 'unknown')
                    service_version = port_info.get('version', 'unknown')
                    print(f'Port: {port}\tState: {port_info["state"]}\tService: {service_name}\tVersion: {service_version}')
            else:
                print(f'Nenhuma informação de portas TCP encontrada para {host}')
except nmap.PortScannerError as e:
    print(f'Erro ao executar o nmap: {e}')
except Exception as e:
    print(f'Ocorreu um erro: {e}')
