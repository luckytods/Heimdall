from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)
CORS(app)


db_config = {
    'host': 'heimdallmonitoring.chkyymc4suru.us-east-2.rds.amazonaws.com',
    'database': 'Heimdall_monitoring',
    'user': 'webAPI',
    'password': 'senhaLegal'
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

    
    connection = connect_db()
    if not connection:
        print("Falha na conexão ao banco de dados.")
        return jsonify({'success': False, 'error': 'Failed to connect to database'})

    try:
        cursor = connection.cursor(dictionary=True)
        
        
        query = "SELECT id FROM users WHERE username = %s AND password = %s"
        cursor.execute(query, (username, password))
        user = cursor.fetchone()
        cursor.close()

        if user:
            print(f"Usuário {username} logado com sucesso.")
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
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({'success': False, 'error': 'Parâmetro user_id é necessário.'}), 400

    connection = connect_db()
    if not connection:
        print("Falha na conexão ao banco de dados.")
        return jsonify({'success': False, 'error': 'Failed to connect to database'})

    try:
        cursor = connection.cursor(dictionary=True)
        device_query = """
        SELECT id, device_name, ip_address, mac_address, os, last_online, is_snmp_enabled, 
        status, first_online
        FROM devices
        WHERE created_by = %s

        """
        cursor.execute(device_query, (user_id,))
        devices = cursor.fetchall()
        
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


@app.route('/update-device-name', methods=['POST'])
def update_device_name():
    data = request.get_json()
    ip = data.get('ip')
    new_name = data.get('new_name')

    if not ip or not new_name:
        return jsonify({'success': False, 'error': 'Parâmetros "ip" e "new_name" são necessários.'}), 400

    connection = connect_db()
    if not connection:
        print("Falha na conexão ao banco de dados.")
        return jsonify({'success': False, 'error': 'Failed to connect to database'}), 500

    try:
        cursor = connection.cursor()
        
        update_query = "UPDATE devices SET device_name = %s WHERE ip_address = %s"
        cursor.execute(update_query, (new_name, ip))
        connection.commit()

        cursor.close()
        return jsonify({'success': True, 'message': 'Nome do dispositivo atualizado com sucesso.'})
    except Error as e:
        print(f"Erro ao atualizar o nome do dispositivo: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if connection.is_connected():
            connection.close()
            print("Conexão ao banco de dados fechada.")
            

@app.route('/agent-status', methods=['GET'])
def agent_status():
    """
    Endpoint para obter o timestamp do último update do agente para um dado user_id.
    Retorna JSON com 'last_updated' (timestamp) ou None se não houver registros.
    """
    user_id = request.args.get('user_id')  # Obtém o user_id dos parâmetros da URL

    if not user_id:
        return jsonify({'success': False, 'error': 'Parâmetro "user_id" é necessário.'}), 400

    connection = connect_db()
    if not connection:
        return jsonify({'success': False, 'error': 'Falha na conexão com o banco de dados.'}), 500

    try:
        cursor = connection.cursor(dictionary=True)

        # Consulta para obter o timestamp do último update do agente para o user_id fornecido
        query = """
        SELECT update_timestamp AS last_updated 
        FROM last_agent_update 
        WHERE user_id = %s 
        ORDER BY update_timestamp DESC 
        LIMIT 1
        """
        cursor.execute(query, (user_id,))
        result = cursor.fetchone()

        cursor.close()

        if result and result['last_updated']:
            # Formata o timestamp para string
            formatted_last_updated = result['last_updated'].strftime('%Y-%m-%d %H:%M:%S')
            return jsonify({'last_updated': formatted_last_updated})
        else:
            # Nenhum registro encontrado ou timestamp é None
            return jsonify({'last_updated': None})
    except Error as e:
        print(f"Erro ao buscar o timestamp do último update: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if connection.is_connected():
            connection.close()
            print("Conexão ao banco de dados fechada.")

@app.route('/check-username', methods=['POST'])
def check_username():
    """
    Endpoint para verificar se um nome de usuário já existe no banco de dados.
    Espera um JSON com o campo 'username'.
    """
    data = request.get_json()
    username = data.get('username')

    if not username:
        return jsonify({'exists': False, 'error': 'Nome de usuário é necessário.'}), 400

    connection = connect_db()
    if not connection:
        return jsonify({'success': False, 'error': 'Falha na conexão com o banco de dados.'}), 500

    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
        result = cursor.fetchone()
        cursor.close()
        return jsonify({'exists': bool(result)})
    except Error as e:
        print(f"Erro ao verificar o nome de usuário: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if connection.is_connected():
            connection.close()
            print("Conexão ao banco de dados fechada.")

@app.route('/create-user', methods=['POST'])
def create_user():
    """
    Endpoint para criar um novo usuário no banco de dados.
    Espera um JSON com os campos 'username' e 'password'.
    """
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'success': False, 'error': 'Nome de usuário e senha são necessários.'}), 400

    connection = connect_db()
    if not connection:
        return jsonify({'success': False, 'error': 'Falha na conexão com o banco de dados.'}), 500

    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("INSERT INTO users (username, password) VALUES (%s, %s)", (username, password))
        connection.commit()
        user_id = cursor.lastrowid
        cursor.close()
        return jsonify({'success': True, 'user_id': user_id})
    except Error as e:
        print(f"Erro ao criar o usuário: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if connection.is_connected():
            connection.close()
            print("Conexão ao banco de dados fechada.")

@app.route('/update-snmp-status', methods=['POST'])
def update_snmp_status():
    data = request.get_json()
    ip_address = data.get('ip')
    new_status = data.get('is_snmp_enabled')

    if ip_address is None or new_status is None:
        return jsonify({'success': False, 'error': 'Parâmetros inválidos.'}), 400

    connection = connect_db()
    if not connection:
        return jsonify({'success': False, 'error': 'Failed to connect to database'}), 500

    try:
        cursor = connection.cursor()
        update_query = """
        UPDATE devices 
        SET is_snmp_enabled = %s 
        WHERE ip_address = %s
        """
        cursor.execute(update_query, (new_status, ip_address))
        connection.commit()
        cursor.close()
        return jsonify({'success': True})
    except Error as e:
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if connection.is_connected():
            connection.close()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

