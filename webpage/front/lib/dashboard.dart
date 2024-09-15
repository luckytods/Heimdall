import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  final int userId; // Parâmetro userId para o construtor

  DashboardScreen(
      {required this.userId}); // Construtor atualizado para receber o userId

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> ipList =
      []; // Lista de IPs e seu status de conexão
  String? selectedIp;
  String? selectedMac;
  String? selectedOs;
  List<int>? openPorts;
  Timer? timer; // Timer para atualizações periódicas

  @override
  void initState() {
    super.initState();
    fetchDevices(); // Busca os dados inicialmente
    // Configura um timer para atualizar os dados a cada 10 segundos
    timer = Timer.periodic(Duration(seconds: 5), (Timer t) => fetchDevices());
  }

  @override
  void dispose() {
    timer?.cancel(); // Cancela o timer quando o widget é destruído
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
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Alinha os elementos verticalmente ao centro
                          children: [
                            RichText(
                              text: TextSpan(
                                text:
                                    'Nome: ', // Texto "Nome:" antes do nome do dispositivo
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
                                        ? ipList.firstWhere((ip) =>
                                            ip['ip_address'] ==
                                            selectedIp)['device_name']
                                        : '"$selectedIp"', // Exibe o nome ou o IP entre aspas
                                    style: TextStyle(
                                      fontSize:
                                          22, // Tamanho da fonte maior para destacar
                                      fontWeight: FontWeight
                                          .bold, // Negrito para dar destaque
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width:
                                    8), // Espaço pequeno entre o texto e o botão de edição
                            IconButton(
                              icon: Icon(Icons.edit,
                                  color: Colors.orange), // Ícone de lápis
                              onPressed: () {
                                // Ação de edição aqui
                                print('Editar nome do dispositivo');
                              },
                            ),
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
