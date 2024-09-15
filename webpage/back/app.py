from flask import Flask, request, jsonify
from flask_cors import CORS  # Importe o pacote CORS
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)
CORS(app)  # Habilita o CORS para todas as rotas

# Configurações do banco de dados MySQL na AWS
db_config = {
    'host': 'heimdallmonitoring.chkyymc4suru.us-east-2.rds.amazonaws.com',  # Substitua pelo endereço do seu banco de dados MySQL na AWS
    'database': 'Heimdall_monitoring',  # Nome do banco de dados
    'user': 'webAPI',  # Substitua pelo seu nome de usuário do MySQL
    'password': 'senhaLegal'  # Substitua pela sua senha do MySQL
}

def connect_db():
    """Função para conectar ao banco de dados MySQL."""
    try:
        connection = mysql.connector.connect(**db_config)
        if connection.is_connected():
            print("Conexão ao banco de dados MySQL estabelecida.")
            return connection
    except Error as e:
        print(f"Erro ao conectar ao MySQL: {e}")
        return None

@app.route('/login', methods=['POST'])
def login():
    """
    Endpoint para validar o login de um usuário.
    Recebe dados no formato JSON: {"username": "user", "password": "pass"}
    Retorna JSON: {"success": true, "user_id": <id>} ou {"success": false}
    """
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    # Conectar ao banco de dados
    connection = connect_db()
    if not connection:
        print("Falha na conexão ao banco de dados.")
        return jsonify({'success': False, 'error': 'Failed to connect to database'})

    try:
        cursor = connection.cursor(dictionary=True)
        
        # Consulta SQL para verificar as credenciais do usuário
        query = "SELECT id FROM users WHERE username = %s AND password = %s"
        cursor.execute(query, (username, password))
        user = cursor.fetchone()
        cursor.close()

        if user:
            print(f"Usuário {username} autenticado com sucesso.")
            # Retorna o ID do usuário junto com a resposta de sucesso
            return jsonify({'success': True, 'user_id': user['id']})
        else:
            print(f"Credenciais inválidas para o usuário {username}.")
            return jsonify({'success': False})
    except Error as e:
        print(f"Erro ao consultar o banco de dados: {e}")
        return jsonify({'success': False, 'error': str(e)})
    finally:
        if connection.is_connected():
            connection.close()
            print("Conexão ao banco de dados fechada.")

@app.route('/user/devices', methods=['GET'])
def get_user_devices():
    """
    Endpoint para obter a lista de dispositivos (IPs) e suas informações de um usuário específico.
    Parâmetro de consulta: user_id
    Retorna JSON com informações sobre os dispositivos.
    """
    user_id = request.args.get('user_id')  # Obtém o user_id do parâmetro de consulta
    if not user_id:
        return jsonify({'success': False, 'error': 'Parâmetro user_id é necessário.'}), 400

    connection = connect_db()
    if not connection:
        print("Falha na conexão ao banco de dados.")
        return jsonify({'success': False, 'error': 'Failed to connect to database'})

    try:
        cursor = connection.cursor(dictionary=True)
        
        # Consulta SQL para obter todos os dispositivos de um usuário específico e suas informações
        device_query = """
        SELECT id, device_name, ip_address, mac_address, os, last_online, is_snmp_enabled, status 
        FROM devices
        WHERE created_by = %s
        """
        cursor.execute(device_query, (user_id,))
        devices = cursor.fetchall()
        
        # Para cada dispositivo, obter as portas associadas
        for device in devices:
            port_query = "SELECT port FROM device_ports WHERE device_id = %s"
            cursor.execute(port_query, (device['id'],))
            ports = cursor.fetchall()
            device['ports'] = [port['port'] for port in ports]  # Adiciona as portas ao dicionário de dispositivo

        cursor.close()

        return jsonify({'success': True, 'devices': devices})
    except Error as e:
        print(f"Erro ao consultar o banco de dados: {e}")
        return jsonify({'success': False, 'error': str(e)})
    finally:
        if connection.is_connected():
            connection.close()
            print("Conexão ao banco de dados fechada.")
            

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
