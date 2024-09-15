import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  final int userId; // Parâmetro userId para o construtor

  DashboardScreen({required this.userId});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> ipList =
      []; // Lista de IPs e seus status de conexão
  String? selectedIp;
  String? selectedMac;
  String? selectedOs;
  List<int>? openPorts;
  bool isEditing = false; // Estado para controle de edição
  TextEditingController deviceNameController =
      TextEditingController(); // Controlador para o campo de texto de edição

  @override
  void dispose() {
    deviceNameController
        .dispose(); // Limpeza do controlador ao descarregar o widget
    super.dispose();
  }

  // Função para buscar dispositivos da API
  Future<void> fetchDevices() async {
    try {
      var url = Uri.parse(
          'http://localhost:5000/user/devices?user_id=${widget.userId}'); // Altere para o IP do servidor da API, se necessário
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          setState(() {
            ipList = List<Map<String, dynamic>>.from(responseData['devices']);
            // Ordena a lista para que os IPs conectados venham antes dos desconectados
            ipList.sort((a, b) => (a['status'] == 'online' ? 0 : 1)
                .compareTo(b['status'] == 'online' ? 0 : 1));
          });
        } else {
          _showError(
              'Falha ao carregar dispositivos: ${responseData['error']}');
        }
      } else {
        _showError('Erro ao buscar dados: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Erro de conexão: $e');
    }
  }

  // Função para salvar o nome do dispositivo no banco de dados
  Future<void> _saveDeviceName() async {
    if (selectedIp != null) {
      String newName = deviceNameController.text;
      try {
        var url = Uri.parse(
            'http://localhost:5000/update-device-name'); // Altere para o endpoint correto da sua API
        var response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'ip': selectedIp, 'new_name': newName}),
        );

        if (response.statusCode == 200) {
          setState(() {
            ipList.firstWhere(
                    (ip) => ip['ip_address'] == selectedIp)['device_name'] =
                newName; // Atualiza o nome na lista local
            isEditing = false; // Sai do modo de edição
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Nome do dispositivo atualizado com sucesso!')),
          );
        } else {
          _showError('Falha ao atualizar o nome do dispositivo.');
        }
      } catch (e) {
        _showError('Erro ao conectar-se ao servidor: $e');
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
      backgroundColor: Colors.grey[900], // Cor de fundo da tela
      appBar: AppBar(
        title: Text('Monitoramento de Rede'),
        backgroundColor: Colors.grey[850], // Cor de fundo do AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 300, // Altura fixa para a caixa de IPs
                      child: _buildIpStatusList(),
                    ),
                  ),
                  SizedBox(width: 16), // Espaço entre as caixas
                  Expanded(
                    child: SizedBox(
                      height:
                          300, // Altura fixa para a caixa de informações do IP
                      child: _buildIpDetailsBox(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20), // Espaço entre a lista de IPs e os gráficos
              ...ipList.map((ip) => _buildIpCharts(ip['ip_address'])).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // Método para criar a lista de IPs e seus status de conexão
  Widget _buildIpStatusList() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status de Conexão dos IPs:',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: ipList.length,
              itemBuilder: (context, index) {
                final ipInfo = ipList[index];
                return ListTile(
                  leading: Icon(
                    ipInfo['status'] == 'online'
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: ipInfo['status'] == 'online'
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Text(
                    ipInfo['ip_address'],
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    ipInfo['status'] == 'online' ? 'Conectado' : 'Desconectado',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    setState(() {
                      selectedIp = ipInfo['ip_address'];
                      selectedMac = ipInfo['mac_address'];
                      selectedOs = ipInfo['os'];
                      openPorts = ipInfo['ports'].cast<int>();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Método para criar a caixa de informações do IP selecionado
  Widget _buildIpDetailsBox() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações do IP:',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: selectedIp == null
                  ? Text(
                      'Selecione um IP para ver os detalhes.',
                      style: TextStyle(color: Colors.white70),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (!isEditing) ...[
                              RichText(
                                text: TextSpan(
                                  text: 'Nome: ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ipList.firstWhere((ip) =>
                                                  ip['ip_address'] ==
                                                  selectedIp)['device_name'] !=
                                              null
                                          ? ipList
                                              .firstWhere((ip) =>
                                                  ip['ip_address'] ==
                                                  selectedIp)['device_name']
                                              .toString()
                                          : '"$selectedIp"',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.orange),
                                onPressed: () {
                                  setState(() {
                                    isEditing = true; // Ativa o modo de edição
                                    deviceNameController.text = ipList
                                            .firstWhere((ip) =>
                                                ip['ip_address'] ==
                                                selectedIp)['device_name']
                                            ?.toString() ??
                                        ''; // Preenche o campo de texto com o nome atual
                                  });
                                },
                              ),
                            ] else ...[
                              Expanded(
                                child: TextField(
                                  controller: deviceNameController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Digite o nome do dispositivo',
                                    hintStyle: TextStyle(color: Colors.white54),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    border: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.check,
                                    color: Colors.green), // Botão OK
                                onPressed: () {
                                  _saveDeviceName(); // Função para salvar o nome no banco de dados
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel,
                                    color: Colors.red), // Botão Cancelar
                                onPressed: () {
                                  setState(() {
                                    isEditing =
                                        false; // Cancela a edição e retorna ao modo de visualização
                                  });
                                },
                              ),
                            ]
                          ],
                        ),
                        SizedBox(height: 8), // Espaço abaixo do título
                        Text(
                          'IP: $selectedIp',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'MAC: ${selectedMac ?? 'N/A'}', // Verifica nullidade
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Sistema Operacional: ${selectedOs ?? 'N/A'}', // Verifica nullidade
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Última vez online: ${ipList.firstWhere((ip) => ip['ip_address'] == selectedIp)['last_online'] ?? 'Desconhecido'}', // Verifica nullidade
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Portas Abertas:',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        openPorts != null && openPorts!.isNotEmpty
                            ? ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: openPorts!.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading:
                                        Icon(Icons.lan, color: Colors.orange),
                                    title: Text(
                                      'Porta ${openPorts![index]}',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  );
                                },
                              )
                            : Text(
                                'Nenhuma porta aberta encontrada.',
                                style: TextStyle(color: Colors.white70),
                              ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para criar um conjunto de gráficos lado a lado para cada IP
  Widget _buildIpCharts(String ip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monitoramento de Rede para $ip',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[
                    800], // Cor de fundo levemente mais clara para o gráfico
                child: Column(
                  children: [
                    Text(
                      'Latência (ms)',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 200, child: LineChartWidget()),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16), // Espaço entre os gráficos
            Expanded(
              child: Container(
                color: Colors.grey[
                    800], // Cor de fundo levemente mais clara para o gráfico
                child: Column(
                  children: [
                    Text(
                      'Uso de Largura de Banda (Mbps)',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 200, child: BarChartWidget()),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 32), // Espaçamento entre os conjuntos de gráficos
      ],
    );
  }
}

class LineChartWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        backgroundColor: Colors
            .transparent, // Fundo transparente para combinar com o contêiner
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.orange, strokeWidth: 1),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.orange, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 1),
              FlSpot(1, 3),
              FlSpot(2, 10),
              FlSpot(3, 7),
              FlSpot(4, 12),
              FlSpot(5, 13),
              FlSpot(6, 17),
            ],
            isCurved: true,
            barWidth: 2,
            color: Colors.orange, // Cor laranja para as linhas do gráfico
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3, // Tamanho do ponto
                color: Colors.orange, // Cor do ponto
                strokeWidth: 1.5,
                strokeColor: Colors.white, // Cor da borda do ponto
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BarChartWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        backgroundColor: Colors
            .transparent, // Fundo transparente para combinar com o contêiner
        alignment: BarChartAlignment.spaceBetween,
        barGroups: [
          BarChartGroupData(
              x: 1, barRods: [BarChartRodData(toY: 8, color: Colors.orange)]),
          BarChartGroupData(
              x: 2, barRods: [BarChartRodData(toY: 10, color: Colors.orange)]),
          BarChartGroupData(
              x: 3, barRods: [BarChartRodData(toY: 14, color: Colors.orange)]),
          BarChartGroupData(
              x: 4, barRods: [BarChartRodData(toY: 15, color: Colors.orange)]),
          BarChartGroupData(
              x: 5, barRods: [BarChartRodData(toY: 13, color: Colors.orange)]),
        ],
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.orange, strokeWidth: 1),
        ),
      ),
    );
  }
}
