import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(NetworkMonitorDashboard());
}

class NetworkMonitorDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Monitor Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // Definindo o tema geral como escuro
      ),
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Lista de IPs e seu status de conexão
  List<Map<String, dynamic>> ipList = [
    {
      'ip': '192.168.0.1',
      'connected': true,
      'mac': '00:1B:44:11:3A:B7',
      'os': 'Windows 10',
      'ports': [22, 80, 443],
      'lastOnline': '2024-09-01 14:22',
    },
    {
      'ip': '192.168.0.2',
      'connected': false,
      'mac': '00:1B:44:11:3A:C8',
      'os': 'Linux Ubuntu 20.04',
      'ports': [21, 8080],
      'lastOnline': '2024-09-01 14:22',
    },
    {
      'ip': '192.168.0.3',
      'connected': true,
      'mac': '00:1B:44:11:3A:D9',
      'os': 'MacOS 11.2',
      'ports': [25, 110, 143, 993],
      'lastOnline': '2024-09-01 14:22',
    },
    {
      'ip': '192.168.0.4',
      'connected': true,
      'mac': '00:1B:44:11:3A:AA',
      'os': 'Windows Server 2016',
      'ports': [3389, 445],
      'lastOnline': '2024-09-01 14:22',
    },
    {
      'ip': '192.168.0.5',
      'connected': false,
      'mac': '00:1B:44:11:3A:BB',
      'os': 'FreeBSD 12',
      'ports': [22, 8081],
      'lastOnline': '2024-09-01 14:22',
    },
  ];

  String? selectedIp;
  String? selectedMac;
  String? selectedOs;
  List<int>? openPorts;

  @override
  void initState() {
    super.initState();
    // Ordena a lista para que os IPs conectados venham antes dos desconectados
    ipList.sort(
        (a, b) => (a['connected'] ? 0 : 1).compareTo(b['connected'] ? 0 : 1));
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
              ...ipList.map((ip) => _buildIpCharts(ip['ip'])).toList(),
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
                    ipInfo['connected'] ? Icons.check_circle : Icons.cancel,
                    color: ipInfo['connected'] ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    ipInfo['ip'],
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    ipInfo['connected'] ? 'Conectado' : 'Desconectado',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    setState(() {
                      selectedIp = ipInfo['ip'];
                      selectedMac = ipInfo['mac'];
                      selectedOs = ipInfo['os'];
                      openPorts = ipInfo['ports'];
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
                        Text(
                          'IP: $selectedIp',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'MAC: $selectedMac',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Sistema Operacional: $selectedOs',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Última vez online: ${ipList.firstWhere((ip) => ip['ip'] == selectedIp)['lastOnline']}',
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
