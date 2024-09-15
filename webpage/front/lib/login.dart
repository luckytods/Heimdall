import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard.dart'; // Importe a página de dashboard

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Indicador de carregamento para requisição de login

  // Função de login usando API
  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading =
            true; // Mostra um indicador de carregamento enquanto a API é chamada
      });

      String username = _usernameController.text;
      String password = _passwordController.text;

      // Fazendo a requisição para a API de login
      var url = Uri.parse(
          'http://localhost:5000/login'); // Altere para o IP do servidor da API se necessário
      try {
        var response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'password': password}),
        );

        if (response.statusCode == 200) {
          var responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            // Login bem-sucedido, captura o user_id retornado
            int userId = responseData['user_id'];
            print('Login bem-sucedido! ID do usuário: $userId');

            // Navegar para o dashboard, passando o user_id como parâmetro
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => DashboardScreen(userId: userId)),
            );
          } else {
            // Exibir mensagem de erro
            _showError('Nome de usuário ou senha inválidos');
          }
        } else {
          // Exibir mensagem de erro para problemas na comunicação com a API
          _showError(
              'Erro na comunicação com o servidor: ${response.statusCode}');
        }
      } catch (e) {
        // Captura erros de rede
        _showError('Erro ao se conectar ao servidor: $e');
      } finally {
        setState(() {
          _isLoading = false; // Remove o indicador de carregamento
        });
      }
    }
  }

  // Função para exibir mensagens de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Fundo cinza escuro como o dashboard
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.grey[850], // Cor do AppBar igual ao dashboard
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Adiciona a logo acima da caixa de login
              Image.asset(
                'assets/logo.png', // Substitua 'logo.png' pelo nome da sua imagem
                height: 100, // Defina a altura da logo conforme necessário
              ),
              SizedBox(height: 10), // Espaço entre a logo e o texto

              // Adiciona o texto abaixo da logo
              Text(
                'Bem-vindo ao Monitoramento de Rede', // Texto a ser exibido
                style: TextStyle(
                  color: Colors.white, // Cor do texto
                  fontSize: 18, // Tamanho da fonte
                  fontWeight: FontWeight.bold, // Estilo da fonte
                ),
              ),
              SizedBox(height: 20), // Espaço entre o texto e a caixa de login

              Container(
                width:
                    300, // Largura limitada para centralizar e tornar compacto
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[850], // Fundo da caixa de login
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // Mantém a altura mínima necessária
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Usuário',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor:
                              Colors.grey[800], // Fundo do campo de texto
                        ),
                        style: TextStyle(color: Colors.white),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira o nome de usuário';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue),
                          ),
                          filled: true,
                          fillColor:
                              Colors.grey[800], // Fundo do campo de texto
                        ),
                        style: TextStyle(color: Colors.white),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira a senha';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 30),
                      _isLoading
                          ? CircularProgressIndicator() // Indicador de carregamento
                          : ElevatedButton(
                              onPressed: _login,
                              child: Text('Login'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    Colors.blue, // Cor do texto do botão
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
