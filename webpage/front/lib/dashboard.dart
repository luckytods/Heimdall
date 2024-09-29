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
  List<Map<String, dynamic>> bandwidthData = [];
  // Lista para armazenar os dados de largura de banda
  Map<String, String> selectedTimeframe =
      {}; // Armazena o tempo selecionado para cada IP
  Map<String, List<FlSpot>> downloadData = {};
  Map<String, List<FlSpot>> uploadData = {};

  @override
  void initState() {
    super.initState();
    fetchDevices(); // Busca os dados inicialmente
    fetchAgentStatus(); // Busca o status do agente
    fetchBandwidthData();
    // Configura um timer para atualizar os dados a cada 10 segundos
    timer = Timer.periodic(Duration(seconds: 10), (Timer t) {
      fetchDevices();
      fetchAgentStatus();
      fetchBandwidthData();
    });
  }

  // Define as opções do Dropdown e a opção inicial
  final List<String> timeOptions = [
    "Última semana",
    "Último dia",
    "Última hora"
  ];

  // Define a função para tratar a seleção do tempo
  void _handleTimeframeChange(String ip, String? newValue) {
    setState(() {
      selectedTimeframe[ip] = newValue ?? "Última semana";
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

              // Título antes dos gráficos
              Text(
                'Monitoramento de Rede',
                style: TextStyle(
                  fontSize: 24, // Tamanho maior para o título
                  fontWeight: FontWeight.bold, // Negrito
                  color: Colors.orange, // Cor do título
                ),
              ),
              SizedBox(height: 20), // Espaço entre o título e os gráficos

              // Filtro para exibir gráficos apenas dos IPs com is_snmp_enabled = 1
              ...ipList
                  .where((ip) => ip['is_snmp_enabled'] == 1)
                  .map((ip) => _buildIpCharts(ip['ip_address']))
                  .toList(),

              // Caso não haja dispositivos monitorados por SNMP
              if (ipList.where((ip) => ip['is_snmp_enabled'] == 1).isEmpty)
                Center(
                  child: Text(
                    'Nenhum dispositivo monitorado por SNMP encontrado.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
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

  // Função para coletar dados de monitoramento da API
  Future<void> fetchBandwidthData() async {
    try {
      var url = Uri.parse(
          'http://localhost:5000/user/bandwidth?user_id=${widget.userId}');
      var response = await http.get(url);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        if (responseData is Map && responseData.containsKey('data')) {
          var rawData = responseData['data'] as Map<String, dynamic>;

          setState(() {
            bandwidthData = []; // Reseta a lista de dados de largura de banda

            // Itera sobre cada IP e seus respectivos dados de largura de banda
            rawData.forEach((ip, dataList) {
              if (dataList is List) {
                // Casting para List<Map<String, dynamic>>
                List<Map<String, dynamic>> parsedDataList =
                    dataList.cast<Map<String, dynamic>>();

                for (var item in parsedDataList) {
                  try {
                    // Aqui garantimos que o timestamp seja convertido para UTC
                    String timestamp = item['timestamp'];
                    DateTime parsedTimestamp =
                        DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", "en_US")
                            .parse(timestamp, true)
                            .toUtc(); // Convertemos para UTC

                    DateTime correctedTimestamp =
                        parsedTimestamp.add(Duration(hours: 3));

                    int millisecondsTimestamp =
                        correctedTimestamp.millisecondsSinceEpoch;

                    // Agora usamos millisecondsSinceEpoch (em UTC) para garantir precisão nos cálculos de períodos
                    bandwidthData.add({
                      'ip': ip,
                      'timestamp': millisecondsTimestamp, // Timestamp em UTC
                      'download_usage':
                          double.tryParse(item['download_usage']) ?? 0.0,
                      'upload_usage':
                          double.tryParse(item['upload_usage']) ?? 0.0,
                    });
                  } catch (e) {
                    // Caso ocorra um erro de parsing, exiba uma mensagem
                    _showError('Erro ao converter data: ${item['timestamp']}');
                  }
                }
              }
            });

            // Processa os dados de largura de banda para cada IP monitorado por SNMP
            ipList.forEach((ipInfo) {
              String ip = ipInfo['ip_address'];
              if (ipInfo['is_snmp_enabled'] == 1) {
                // Obter a opção selecionada para o período, com 'Última semana' como padrão
                String selectedOption =
                    selectedTimeframe[ip] ?? 'Última semana';

                // Filtrar os dados de largura de banda para o IP atual
                List<Map<String, dynamic>> ipData =
                    bandwidthData.where((data) => data['ip'] == ip).toList();

                // Processar os dados conforme o período selecionado e atualizar downloadData e uploadData
                List<List<FlSpot>> processedData =
                    processBandwidthData(ipData, selectedOption);

                downloadData[ip] = processedData[0];
                uploadData[ip] = processedData[1];
              }
            });
          });
        } else {
          _showError('Erro ao buscar dados: Estrutura de resposta inesperada.');
        }
      } else {
        _showError(
            'Erro ao buscar dados: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      _showError('Erro ao buscar dados: $e');
    }
  }

  // Função para processar os dados de largura de banda conforme o tempo selecionado
  List<List<FlSpot>> processBandwidthData(
      List<Map<String, dynamic>> ipData, String selectedOption) {
    DateTime now =
        DateTime.now().toUtc(); // Usar UTC para garantir a consistência
    List<FlSpot> downloadSpots = [];
    List<FlSpot> uploadSpots = [];

    int nowMilliseconds = now
        .millisecondsSinceEpoch; // Obtenha o timestamp atual em millisecondsSinceEpoch (UTC)

    if (selectedOption == 'Última semana') {
      // Intervalo de 6 horas para a última semana
      for (int i = 7 * 4; i >= 0; i--) {
        int periodStart = nowMilliseconds -
            (i *
                6 *
                60 *
                60 *
                1000); // Calcula o período em millisecondsSinceEpoch (UTC)
        int periodEnd =
            periodStart + (6 * 60 * 60 * 1000); // Intervalo de 6 horas

        var periodData = ipData.where((data) {
          int timestamp =
              data['timestamp']; // Timestamp já em millisecondsSinceEpoch (UTC)
          return timestamp >= periodStart && timestamp < periodEnd;
        }).toList();

        double downloadAvg = _calculateAverage(periodData, 'download_usage');
        double uploadAvg = _calculateAverage(periodData, 'upload_usage');

        downloadSpots.add(FlSpot(periodStart.toDouble(), downloadAvg));
        uploadSpots.add(FlSpot(periodStart.toDouble(), uploadAvg));
      }
    } else if (selectedOption == 'Último dia') {
      // Intervalo de 1 hora para o último dia
      for (int i = 24; i >= 0; i--) {
        int periodStart = nowMilliseconds -
            (i * 60 * 60 * 1000); // 1 hora em millisecondsSinceEpoch (UTC)
        int periodEnd = periodStart + (60 * 60 * 1000); // Intervalo de 1 hora

        var periodData = ipData.where((data) {
          int timestamp = data['timestamp'];
          return timestamp >= periodStart && timestamp < periodEnd;
        }).toList();

        double downloadAvg = _calculateAverage(periodData, 'download_usage');
        double uploadAvg = _calculateAverage(periodData, 'upload_usage');

        downloadSpots.add(FlSpot(periodStart.toDouble(), downloadAvg));
        uploadSpots.add(FlSpot(periodStart.toDouble(), uploadAvg));
      }
    } else if (selectedOption == 'Última hora') {
      // Intervalo de 2 minutos para a última hora
      for (int i = 30; i >= 0; i--) {
        int periodStart = nowMilliseconds -
            (i * 2 * 60 * 1000); // 2 minutos em millisecondsSinceEpoch (UTC)
        int periodEnd = periodStart + (2 * 60 * 1000); // Intervalo de 2 minutos

        var periodData = ipData.where((data) {
          int timestamp = data['timestamp'];
          return timestamp >= periodStart && timestamp < periodEnd;
        }).toList();

        double downloadAvg = _calculateAverage(periodData, 'download_usage');
        double uploadAvg = _calculateAverage(periodData, 'upload_usage');

        downloadSpots.add(FlSpot(periodStart.toDouble(), downloadAvg));
        uploadSpots.add(FlSpot(periodStart.toDouble(), uploadAvg));
      }
    }

    return [
      downloadSpots,
      uploadSpots
    ]; // Retorna listas de FlSpot para download e upload
  }

// Função auxiliar para calcular a média de um período
  double _calculateAverage(List<Map<String, dynamic>> periodData, String key) {
    if (periodData.isEmpty) {
      print('Nenhum dado disponível para calcular a média para a chave: $key');
      return 0.0;
    }

    double total = 0.0;
    for (var data in periodData) {
      if (data[key] != null) {
        total += data[key];
      } else {
        print('Chave ausente no dado: $data');
      }
    }
    // Retorna a média com duas casas decimais
    double average = total / periodData.length;
    print('Média calculada para $key: ${average.toStringAsFixed(2)}');
    return double.parse(average.toStringAsFixed(2));
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

  String formatUpTime(int seconds) {
    int days = seconds ~/ (24 * 3600); // Calcula dias
    seconds %= (24 * 3600);
    int hours = seconds ~/ 3600; // Calcula horas
    seconds %= 3600;
    int minutes = seconds ~/ 60; // Calcula minutos

    List<String> parts = [];

    if (days > 0) {
      parts.add('${days}d');
    }
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || parts.isEmpty) {
      // Se minutos ou se todas as partes estão vazias
      parts.add('${minutes}m');
    }

    return parts.join(' '); // Junta as partes com espaços
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
    final device = ipList.firstWhere((element) => element['ip_address'] == ip);
    final int upTimeSeconds =
        device['upTime'] ?? 0; // Recupera o upTime em segundos ou 0
    final String formattedUpTime =
        formatUpTime(upTimeSeconds); // Formata o upTime

    // Verifica se o IP tem dados de download e upload
    final downloadSpots = downloadData[ip] ?? [];
    final uploadSpots = uploadData[ip] ?? [];

    // Inicializa o valor padrão de tempo, se ainda não estiver definido
    if (!selectedTimeframe.containsKey(ip)) {
      selectedTimeframe[ip] = "Última semana"; // Definindo como padrão
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              ip,
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Text(
              '(${device['device_name']})',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70), // Nome menor e cor mais clara
            ),
            SizedBox(width: 16), // Espaço entre o nome e o dropdown

            // Adiciona o DropdownButton
            DropdownButton<String>(
              value: selectedTimeframe[ip],
              dropdownColor: Colors.grey[850],
              iconEnabledColor: Colors.white,
              items: timeOptions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                        color: Colors.white), // Estilo do texto do dropdown
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                _handleTimeframeChange(
                    ip, newValue); // Atualiza a seleção do tempo
                // Aqui você pode adicionar lógica para atualizar os dados com base na seleção
                // Por exemplo, buscar novos dados da API para o período selecionado.
              },
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caixa de upTime
            Container(
              width: 70, // Largura e altura para o quadrado
              height: 80,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'UpTime',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      formattedUpTime, // Exibe o upTime formatado
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange, // Cor diferenciada para o upTime
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16), // Espaço entre a caixa de upTime e o gráfico

            // Gráfico de área
            Expanded(
              child: Container(
                color: Colors.grey[800], // Mesma cor da caixa de gráficos
                child: Column(
                  children: [
                    Text(
                      'Download e Upload (kbps)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(
                      height: 200, // Altura do gráfico
                      child: AreaChartWidget(
                        downloadSpots:
                            downloadSpots, // Passando os dados de download
                        uploadSpots: uploadSpots, // Passando os dados de upload
                      ), // Widget do gráfico de área
                    ),
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

class AreaChartWidget extends StatelessWidget {
  final List<FlSpot> downloadSpots;
  final List<FlSpot> uploadSpots;

  AreaChartWidget({required this.downloadSpots, required this.uploadSpots});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.transparent,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.5),
                    strokeWidth: 0.5,
                  ),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.5),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        // Converte o valor de millisecondsSinceEpoch para uma data legível
                        DateTime date =
                            DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        // Formata a data conforme necessário
                        if (value %
                                ((downloadSpots.length / 5).ceilToDouble()) ==
                            0) {
                          return Text(
                            DateFormat('dd/MM HH:mm')
                                .format(date), // Formatação desejada
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          );
                        }
                        return Container(); // Retorna um widget vazio para esconder os rótulos
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        // Formatando o valor do eixo Y com duas casas decimais
                        return Text(
                          '${value.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        DateTime date = DateTime.fromMillisecondsSinceEpoch(
                            touchedSpot.x.toInt());
                        String formattedDate =
                            DateFormat('dd/MM HH:mm').format(date);
                        return LineTooltipItem(
                          'Data: $formattedDate\nValor: ${touchedSpot.y.toStringAsFixed(2)} kbps',
                          TextStyle(color: Colors.white),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: downloadSpots,
                    isCurved: true,
                    barWidth: 2,
                    color: Colors.orange,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  LineChartBarData(
                    spots: uploadSpots,
                    isCurved: true,
                    barWidth: 2,
                    color: Colors.blue,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8), // Espaço entre o gráfico e a legenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Download',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(width: 16),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Upload',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
