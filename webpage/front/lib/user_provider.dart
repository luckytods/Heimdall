import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  int? _userId; // ID do usuário logado

  int? get userId => _userId; // Obtém o ID do usuário

  // Método para atualizar o ID do usuário
  void setUserId(int userId) {
    _userId = userId;
    notifyListeners(); // Notifica os ouvintes para atualizar a interface do usuário
  }
}
