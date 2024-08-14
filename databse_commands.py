import mysql.connector
from mysql.connector import Error
from config import DB_CONFIG #Arquivo contendo as crdenciais para a conexão

def create_connection():
    """Cria uma conexão com o banco de dados MySQL."""
    connection = None
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        if connection.is_connected():
            print("Conexão com o banco de dados MySQL foi bem-sucedida.")
    except Error as e:
        print(f"Erro ao conectar ao MySQL: {e}")
    return connection

def create_tables():
    conn = create_connection()
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS `devices` (
            `id` int NOT NULL AUTO_INCREMENT,
            `device_name` varchar(255) DEFAULT NULL,
            `ip_address` varchar(45) DEFAULT NULL,
            `mac_address` varchar(17) DEFAULT NULL,
            `os` varchar(100) DEFAULT NULL,
            `last_online` datetime NOT NULL,
            `is_snmp_enabled` tinyint(1) NOT NULL DEFAULT '0',
            PRIMARY KEY (`id`),
            UNIQUE KEY `ip_address` (`ip_address`,`mac_address`)
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS `device_metrics` (
            `id` int NOT NULL AUTO_INCREMENT,
            `device_id` int NOT NULL,
            `recorded_at` datetime NOT NULL,
            `cpu_temperature` decimal(5,2) DEFAULT NULL,
            `cpu_usage` decimal(5,2) DEFAULT NULL,
            `memory_usage` decimal(5,2) DEFAULT NULL,
            `storage_usage` decimal(5,2) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `device_id` (`device_id`),
            KEY `idx_recorded_at` (`recorded_at`),
            CONSTRAINT `device_metrics_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `devices` (`id`)
            )
    ''')
    conn.commit()
    cursor.close()
    conn.close()


def insert_device(connection, last_online, ip_address, is_snmp_enabled=0, mac_address=None, os=None, device_name=None):
    #Insere um novo dispositivo na tabela devices.
    cursor = connection.cursor()
    query = """
    INSERT INTO devices (device_name, ip_address, mac_address, os, last_online, is_snmp_enabled)
    VALUES (%s, %s, %s, %s, %s, %s)
    """
    cursor.execute(query, (device_name, ip_address, mac_address, os, last_online, is_snmp_enabled))
    connection.commit()
    print("Dispositivo inserido com sucesso.")

def insert_device_metrics(connection, device_id, recorded_at, cpu_temperature, cpu_usage, memory_usage, storage_usage):
    #Insere métricas de um dispositivo na tabela device_metrics.
    cursor = connection.cursor()
    query = """
    INSERT INTO device_metrics (device_id, recorded_at, cpu_temperature, cpu_usage, memory_usage, storage_usage)
    VALUES (%s, %s, %s, %s, %s, %s)
    """
    cursor.execute(query, (device_id, recorded_at, cpu_temperature, cpu_usage, memory_usage, storage_usage))
    connection.commit()
    print("Métricas do dispositivo inseridas com sucesso.")

def fetch_by_ip(connection, ip_address):
    """
    Retorna as linhas da tabela 'devices' que correspondem ao IP fornecido.
    
    :param connection: Conexão com o banco de dados MySQL.
    :param ip_address: Endereço IP para buscar.
    :return: Lista de linhas que correspondem ao IP.
    """
    cursor = connection.cursor()
    query = "SELECT * FROM devices WHERE ip_address = %s"
    cursor.execute(query, (ip_address,))
    rows = cursor.fetchone()
    cursor.close()
    return rows

def fetch_by_mac(connection, mac_address):
    """
    Retorna as linhas da tabela 'devices' que correspondem ao MAC fornecido.
    
    :param connection: Conexão com o banco de dados MySQL.
    :param mac_address: Endereço MAC para buscar.
    :return: Lista de linhas que correspondem ao MAC.
    """
    cursor = connection.cursor()
    query = "SELECT * FROM devices WHERE mac_address = %s"
    cursor.execute(query, (mac_address,))
    rows = cursor.fetchone()
    cursor.close()
    return rows

def fetch_by_id(connection, device_id):
    """
    Retorna a linha da tabela 'devices' que corresponde ao ID fornecido.
    
    :param connection: Conexão com o banco de dados MySQL.
    :param device_id: ID do dispositivo para buscar.
    :return: Linha que corresponde ao ID.
    """
    cursor = connection.cursor()
    query = "SELECT * FROM devices WHERE id = %s"
    cursor.execute(query, (device_id,))
    row = cursor.fetchone()  # Usar fetchone() porque ID é único
    cursor.close()
    return row

def update_device(connection, device_id, updates):
    """
    Atualiza informações de um dispositivo na tabela 'devices' com base no ID.
    
    :param connection: Conexão com o banco de dados MySQL.
    :param device_id: ID do dispositivo a ser atualizado.
    :param updates: Dicionário contendo as colunas e os novos valores a serem atualizados.
    :return: None
    """
    cursor = connection.cursor()
    
    # Construir a parte da query que especifica as colunas a serem atualizadas
    set_clause = ", ".join(f"{key} = %s" for key in updates.keys())
    
    # Construir a query SQL completa
    query = f"UPDATE devices SET {set_clause} WHERE id = %s"
    
    # Executar a query com os valores apropriados
    cursor.execute(query, (*updates.values(), device_id))
    connection.commit()
    
    cursor.close()
    print(f"Dispositivo com ID {device_id} atualizado com sucesso.")