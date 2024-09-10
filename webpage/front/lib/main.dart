import 'package:flutter/material.dart';
import 'login.dart'; // Importe o arquivo do login criado acima

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(), // Definindo a página de login como a tela inicial
    );
  }
}
