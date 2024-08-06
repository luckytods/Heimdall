import mysql.connector

def get_db_connection():
    return mysql.connector.connect(
        host='localhost',
        user='superusuario',
        password='1Ringt0rul3th3m@ll',
        database='Hydra_monitoring'
    )