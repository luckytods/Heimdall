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
            `device_name` varchar(255) NOT NULL,
            `ip_address` varchar(45) NOT NULL,
            `mac_address` varchar(17) NOT NULL,
            `os` varchar(100) NOT NULL,
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


def insert_device(connection, device_name, ip_address, mac_address, os, last_online, is_snmp_enabled):
    """Insere um novo dispositivo na tabela devices."""
    cursor = connection.cursor()
    query = """
    INSERT INTO devices (device_name, ip_address, mac_address, os, last_online, is_snmp_enabled)
    VALUES (%s, %s, %s, %s, %s, %s)
    """
    cursor.execute(query, (device_name, ip_address, mac_address, os, last_online, is_snmp_enabled))
    connection.commit()
    print("Dispositivo inserido com sucesso.")

def insert_device_metrics(connection, device_id, recorded_at, cpu_temperature, cpu_usage, memory_usage, storage_usage):
    """Insere métricas de um dispositivo na tabela device_metrics."""
    cursor = connection.cursor()
    query = """
    INSERT INTO device_metrics (device_id, recorded_at, cpu_temperature, cpu_usage, memory_usage, storage_usage)
    VALUES (%s, %s, %s, %s, %s, %s)
    """
    cursor.execute(query, (device_id, recorded_at, cpu_temperature, cpu_usage, memory_usage, storage_usage))
    connection.commit()
    print("Métricas do dispositivo inseridas com sucesso.")

def fetch_device_metrics(connection, device_id):
    """Busca métricas de um dispositivo específico."""
    cursor = connection.cursor()
    query = """
    SELECT d.device_name, dm.recorded_at, dm.cpu_temperature, dm.cpu_usage, dm.memory_usage, dm.storage_usage
    FROM devices d
    JOIN device_metrics dm ON d.id = dm.device_id
    WHERE d.id = %s
    ORDER BY dm.recorded_at DESC
    """
    cursor.execute(query, (device_id,))
    rows = cursor.fetchall()
    for row in rows:
        print(row)

if __name__ == "__main__":
    conn = create_connection()

    if conn:
        # Inserir um novo dispositivo
        insert_device(conn, 'Device1', '192.168.1.10', 'AA:BB:CC:DD:EE:FF', 'Linux', '2024-08-04 12:00:00', True)

        # Inserir métricas de um dispositivo
        insert_device_metrics(conn, 1, '2024-08-04 12:00:00', 45.5, 20.0, 55.0, 75.0)

        # Consultar métricas de um dispositivo
        fetch_device_metrics(conn, 1)

        conn.close()
