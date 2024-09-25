import tkinter as tk
from tkinter import ttk
import config


class ConfigApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Configurações do App")
        self.root.minsize(400, 300)
        self.create_widgets()
        self.load_config()  # Carrega as configurações ao iniciar

    def create_widgets(self):
        # Area referene ao loging do sistema
        login_frame = ttk.LabelFrame(self.root, text="Configuração de Login")
        login_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")

        ttk.Label(login_frame, text="Usuário:").grid(row=0, column=0, padx=5, pady=5, sticky="e")
        self.username = ttk.Entry(login_frame)
        self.username.grid(row=0, column=1, padx=5, pady=5, sticky="ew")

        ttk.Label(login_frame, text="Senha:").grid(row=1, column=0, padx=5, pady=5, sticky="e")
        self.password = ttk.Entry(login_frame, show="*")
        self.password.grid(row=1, column=1, padx=5, pady=5, sticky="ew")

        self.show_password_var = tk.BooleanVar()
        show_password_cb = ttk.Checkbutton(
            login_frame, text="Mostrar a senha", variable=self.show_password_var, command=self.toggle_password_visibility
        )
        show_password_cb.grid(row=2, column=1, padx=5, pady=5, sticky="w")

        # Area para config do SNMP
        snmp_frame = ttk.LabelFrame(self.root, text="Configuração SNMP")
        snmp_frame.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")

        ttk.Label(snmp_frame, text="Community:").grid(row=0, column=0, padx=5, pady=5, sticky="e")
        self.snmp_community = ttk.Entry(snmp_frame, show="*")
        self.snmp_community.grid(row=0, column=1, padx=5, pady=5, sticky="ew")

        self.show_community_var = tk.BooleanVar()
        show_community_cb = ttk.Checkbutton(
            snmp_frame, text="Mostrar Community", variable=self.show_community_var, command=self.toggle_community_visibility
        )
        show_community_cb.grid(row=1, column=1, padx=5, pady=5, sticky="w")

        ###################################################################################################

        # Botão de Salvar
        save_button = ttk.Button(self.root, text="Salvar Configurações", command=self.save_config)
        save_button.grid(row=2, column=0, padx=10, pady=10, sticky="ew")

        self.root.grid_rowconfigure(0, weight=1)
        self.root.grid_rowconfigure(1, weight=1)
        self.root.grid_rowconfigure(2, weight=0)
        self.root.grid_columnconfigure(0, weight=1)

        login_frame.grid_columnconfigure(1, weight=1)
        snmp_frame.grid_columnconfigure(1, weight=1)

    def toggle_password_visibility(self):
        if self.show_password_var.get():
            self.password.config(show="")
        else:
            self.password.config(show="*")

    def toggle_community_visibility(self):
        if self.show_community_var.get():
            self.snmp_community.config(show="")
        else:
            self.snmp_community.config(show="*")

    def load_config(self):
        self.username.insert(0, config.USER.get('username', ''))
        self.password.insert(0, config.USER.get('password', ''))
        self.snmp_community.insert(0, config.community)

    def save_config(self):
        user_config = {
            'username': self.username.get(),
            'password': self.password.get()
        }
        snmp_community = self.snmp_community.get()

        with open("config.py", "w") as config_file:
            config_file.write(f"USER = {user_config}\n")
            config_file.write(f"community = '{snmp_community}'\n")

        print("Configurações Salvas com Sucesso!")


if __name__ == "__main__":
    root = tk.Tk()
    app = ConfigApp(root)
    root.mainloop()
