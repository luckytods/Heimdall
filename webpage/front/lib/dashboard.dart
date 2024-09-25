import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Para formatação de data
import 'login.dart'; // Importe a tela de login

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
  Timer? timer; // Timer para atualizações periódicas
  String agentStatus = "offline"; // Estado inicial do status do agente
  String lastUpdated = ""; // Estado inicial do timestamp do último update

  @override
  void initState() {
    super.initState();
    fetchDevices(); // Busca os dados inicialmente
    fetchAgentStatus(); // Busca o status do agente
    // Configura um timer para atualizar os dados a cada 10 segundos
    timer = Timer.periodic(Duration(seconds: 10), (Timer t) {
      fetchDevices();
      fetchAgentStatus();
    });
  }

  @override
  void dispose() {
    timer?.cancel(); // Cancela o timer quando o widget é destruído
    deviceNameController
        .dispose(); // Limpeza do controlador ao descarregar o widget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Cor de fundo da tela
      appBar: AppBar(
        backgroundColor: Colors.grey[850], // Cor de fundo do AppBar
        title: Row(
          children: [
            Text(
              'Agent Status: ',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white), // Cor alterada para o tom de branco
            ),
            if (agentStatus == 'online') ...[
              Icon(Icons.circle,
                  color: Colors.green, size: 14), // Símbolo de "online"
              SizedBox(width: 4),
              Text(
                'Online',
                style: TextStyle(color: Colors.green, fontSize: 18),
              ),
            ] else ...[
              Icon(Icons.circle,
                  color: Colors.red, size: 14), // Símbolo de "offline"
              SizedBox(width: 4),
              Text(
                'Offline', // Mostra "Offline" antes do horário
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
              SizedBox(width: 4),
              Text(
                lastUpdated, // Timestamp formatado do último update
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18), // Mesma cor do texto "Agent Status:"
              ),
            ]
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.power_settings_new,
                color: Colors.red), // Ícone de logoff
            onPressed: _logOff, // Função para logoff
          ),
        ],
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

  // Função para fazer logoff e navegar de volta para a tela de login
  void _logOff() {
    setState(() {
      // Aqui você pode limpar o estado e o userId
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              LoginPage()), // Substitua pela navegação para a tela de login
    );
  }

  // Função para buscar o status do agente da API
  Future<void> fetchAgentStatus() async {
    try {
      var url = Uri.parse(
          'http://localhost:5000/agent-status?user_id=${widget.userId}'); // Inclui o user_id como parâmetro
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        setState(() {
          String? rawLastUpdated =
              responseData['last_updated']; // Recebe o timestamp ou null

          if (rawLastUpdated != null) {
            DateTime lastUpdateTime = DateTime.parse(rawLastUpdated);
            lastUpdated = _formatDateTime(
                lastUpdateTime); // Formata a data/hora de forma amigável
            DateTime now = DateTime.now();

            // Determina o status com base na diferença de tempo
            if (now.difference(lastUpdateTime).inSeconds <= 30) {
              agentStatus = 'online';
            } else {
              agentStatus = 'offline';
            }
          } else {
            agentStatus = 'offline';
            lastUpdated =
                '--/--'; // Define como "--/--" se o timestamp estiver ausente
          }
        });
      } else {
        _showError('Erro ao buscar status do agente: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Erro de conexão ao buscar status do agente: $e');
    }
  }

  // Função para formatar a data/hora de uma forma amigável
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutos atrás';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} horas atrás';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm')
          .format(dateTime); // Formato mais detalhado
    }
  }

  // Função para exibir mensagens de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Função para buscar dispositivos da API
  Future<void> fetchDevices() async {
    try {
      var url = Uri.parse(
          'http://localhost:5000/user/devices?user_id=${widget.userId}');
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          setState(() {
            ipList = List<Map<String, dynamic>>.from(responseData['devices']);

            // Ordena os dispositivos: online primeiro, offline depois
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

  // Função para criar a caixa de informações do IP selecionado
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
                        // Nome do dispositivo e botão de edição
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
                                        '';
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
                                icon: Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  _saveDeviceName(); // Função para salvar o nome no bd
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel, color: Colors.red),
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
                        SizedBox(height: 8),
                        // Informação sobre o monitoramento SNMP
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Monitoramento por SNMP:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            // Botão para mostrar o status do SNMP
                            ElevatedButton(
                              onPressed: () {
                                _showSnmpDialog();
                              },
                              child: Text(
                                ipList.firstWhere((ip) =>
                                            ip['ip_address'] ==
                                            selectedIp)['is_snmp_enabled'] ==
                                        1
                                    ? 'Ativado'
                                    : 'Desativado',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ipList.firstWhere((ip) =>
                                            ip['ip_address'] ==
                                            selectedIp)['is_snmp_enabled'] ==
                                        1
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'IP: $selectedIp',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'MAC: ${selectedMac ?? 'N/A'}',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Sistema Operacional: ${selectedOs ?? 'N/A'}',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Última vez online: ${ipList.firstWhere((ip) => ip['ip_address'] == selectedIp)['last_online'] ?? 'Desconhecido'}', // Verifica nullidade
                          style: TextStyle(color: Colors.white),
                        ),
                        // Adicionando a exibição de 'first_online'
                        Text(
                          'Primeira vez online: ${ipList.firstWhere((ip) => ip['ip_address'] == selectedIp)['first_online'] ?? 'Desconhecido'}', // Verifica nullidade
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

// Função para mostrar o pop-up de SNMP
  void _showSnmpDialog() {
    final isSnmpEnabled = ipList
        .firstWhere((ip) => ip['ip_address'] == selectedIp)['is_snmp_enabled'];
    final textController = TextEditingController();
    final confirmationText = isSnmpEnabled == 1 ? 'DESATIVAR' : 'ATIVAR';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              title: Text(
                isSnmpEnabled == 1
                    ? 'Desativar Monitoramento por SNMP'
                    : 'Ativar Monitoramento por SNMP',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSnmpEnabled == 1
                        ? 'Ao continuar você está confirmando que deseja desativar o monitoramento por SNMP deste dispositivo.'
                        : 'Ao continuar você confirma que deseja iniciar o monitoramento por SNMP deste dispositivo e que o mesmo está devidamente configurado para isso.',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Digite '$confirmationText' para confirmar sua escolha.",
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: textController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Digite $confirmationText',
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    onChanged: (value) {
                      setState(
                          () {}); // Atualiza o estado para verificar a entrada
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancelar', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Fecha o pop-up
                  },
                ),
                ElevatedButton(
                  child: Text('Confirmar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSnmpEnabled == 1
                        ? const Color.fromARGB(255, 236, 132, 34)
                        : Colors.green,
                  ),
                  onPressed: textController.text == confirmationText
                      ? () {
                          _updateSnmpStatus(isSnmpEnabled == 1 ? 0 : 1);
                          Navigator.of(context).pop(); // Fecha o pop-up
                        }
                      : null, // Desabilita o botão se o texto não estiver correto
                ),
              ],
            );
          },
        );
      },
    );
  }

// Função para atualizar o status do SNMP
  Future<void> _updateSnmpStatus(int newStatus) async {
    try {
      var url = Uri.parse('http://localhost:5000/update-snmp-status');
      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ip': selectedIp, 'is_snmp_enabled': newStatus}),
      );

      if (response.statusCode == 200) {
        setState(() {
          ipList.firstWhere(
                  (ip) => ip['ip_address'] == selectedIp)['is_snmp_enabled'] =
              newStatus; // Atualiza o status na lista
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status do SNMP atualizado com sucesso!')),
        );
      } else {
        _showError('Falha ao atualizar o status do SNMP.');
      }
    } catch (e) {
      _showError('Erro ao conectar-se ao servidor: $e');
    }
  }

  // Função para salvar o nome do dispositivo no banco de dados
  Future<void> _saveDeviceName() async {
    if (selectedIp != null) {
      String newName = deviceNameController.text;
      try {
        var url = Uri.parse('http://localhost:5000/update-device-name');
        var response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'ip': selectedIp, 'new_name': newName}),
        );

        if (response.statusCode == 200) {
          setState(() {
            ipList.firstWhere(
                    (ip) => ip['ip_address'] == selectedIp)['device_name'] =
                newName;
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
                final ipAddress = ipInfo['ip_address'];
                final deviceName = ipInfo['device_name']; // Nome do dispositivo
                return ListTile(
                  leading: Icon(
                    ipInfo['status'] == 'online'
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: ipInfo['status'] == 'online'
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Row(
                    children: [
                      Text(
                        ipAddress, // Exibe o IP
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      if (deviceName != null && deviceName.isNotEmpty) ...[
                        SizedBox(
                            width:
                                8), // Espaço entre o IP e o nome do dispositivo
                        Text(
                          '($deviceName)', // Exibe o nome do dispositivo ao lado do IP
                          style: TextStyle(
                            color: Colors.white70, // Cor levemente mais escura
                            fontSize: 14, // Fonte levemente menor
                          ),
                        ),
                      ],
                    ],
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
                color: Colors.grey[800],
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
                color: Colors.grey[800],
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
        SizedBox(height: 32),
      ],
    );
  }
}

class LineChartWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
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
            color: Colors.orange,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: Colors.orange,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
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
        backgroundColor: Colors.transparent,
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
