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
        query = "SELECT * FROM users WHERE username = %s AND password = %s"
        cursor.execute(query, (username, password))
        user = cursor.fetchone()
        cursor.close()

        if user:
            print(f"Usuário {username} autenticado com sucesso.")
            return jsonify({'success': True})
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
