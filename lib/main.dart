import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() => runApp(const MeuApp());

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Projeto Integrado',
      theme: ThemeData(primarySwatch: Colors.purple, useMaterial3: true),
      home: const PaginaConfiguracao(),
    );
  }
}

class PaginaConfiguracao extends StatefulWidget {
  const PaginaConfiguracao({super.key});

  @override
  State<PaginaConfiguracao> createState() => _PaginaConfiguracaoState();
}

class _PaginaConfiguracaoState extends State<PaginaConfiguracao> {
  BluetoothDevice? dispositivo;
  String status = 'Nenhum dispositivo selecionado.';
  final _nomeCtrl = TextEditingController();
  final _idadeCtrl = TextEditingController();
  final List<ScanResult> _scanResults = [];
  String? sexo;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<void> _pedirPermissoes() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _scanDispositivos() async {
    await _pedirPermissoes();
    setState(() {
      status = 'Escaneando dispositivos...';
      _scanResults.clear();
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults.clear();
        _scanResults.addAll(results);
      });
    });
    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    setState(() => status = 'Selecione um dispositivo:');
    _mostrarListaDispositivos();
  }

  void _mostrarListaDispositivos() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => ListView(
            children:
                _scanResults.map((r) {
                  final name =
                      r.device.name.isNotEmpty ? r.device.name : r.device.id.id;
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(r.device.id.id),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() => status = 'Conectando a $name...');
                      try {
                        await r.device.connect(
                          timeout: const Duration(seconds: 5),
                        );
                        setState(() {
                          dispositivo = r.device;
                          status = 'Conectado: $name';
                        });
                      } catch (e) {
                        setState(() => status = 'Falha ao conectar: $e');
                      }
                    },
                  );
                }).toList(),
          ),
    );
  }

  Future<void> _desconectar() async {
    if (dispositivo != null) {
      await _enviarComandoDeepSleep();
      await dispositivo!.disconnect();
      setState(() {
        status = 'Nenhum dispositivo selecionado.';
        dispositivo = null;
      });
    }
  }

  Future<void> _enviarComandoDeepSleep() async {
    try {
      final services = await dispositivo!.discoverServices();
      for (var service in services) {
        if (service.uuid == Guid("0000180d-0000-1000-8000-00805f9b34fb")) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid ==
                Guid("00002a3d-0000-1000-8000-00805f9b34fb")) {
              await characteristic.write(utf8.encode("off"));
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao enviar comando deep sleep: $e');
    }
  }

  void _prosseguir() async {
    final nome = _nomeCtrl.text.trim();
    final idade = int.tryParse(_idadeCtrl.text);
    if (nome.isEmpty || idade == null || idade < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e idade válidos.')),
      );
      return;
    }

    if (dispositivo != null) {
      try {
        BluetoothConnectionState currentState = await dispositivo!.state.first;
        if (currentState != BluetoothConnectionState.connected) {
          await dispositivo!.connect(timeout: const Duration(seconds: 5));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao conectar dispositivo BLE: $e')),
        );
        return;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaginaPrincipal(
              device: dispositivo,
              nome: nome,
              idade: idade,
              sexo: sexo ?? '',
              onDisconnect: _enviarComandoDeepSleep,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _nomeCtrl.dispose();
    _idadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração Inicial'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _scanDispositivos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Escanear Dispositivos',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              if (dispositivo != null)
                ElevatedButton(
                  onPressed: _desconectar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Desconectar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              const Divider(height: 40),
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome do Usuário'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _idadeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Idade'),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: sexo,
                decoration: const InputDecoration(labelText: 'Sexo'),
                items: const [
                  DropdownMenuItem(
                    value: 'Masculino',
                    child: Text('Masculino'),
                  ),
                  DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                ],
                onChanged: (value) => setState(() => sexo = value),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _prosseguir,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Prosseguir',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaginaPrincipal extends StatefulWidget {
  final BluetoothDevice? device;
  final String nome;
  final int idade;
  final String sexo;
  final Future<void> Function()? onDisconnect;

  const PaginaPrincipal({
    super.key,
    this.device,
    required this.nome,
    required this.idade,
    required this.sexo,
    this.onDisconnect,
  });

  @override
  State<PaginaPrincipal> createState() => _PaginaPrincipalState();
}

class _PaginaPrincipalState extends State<PaginaPrincipal> {
  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid charUuid = Guid(
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  ); // notify (TX)
  static final Guid cmdCharUuid = Guid(
    '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  ); // write (RX)

  String? esporte;
  String? metodoMonitoramento;
  int? fcRepouso;
  final List<FlSpot> dadosBpm = [];
  int? ultimaLeitura;
  double trimpAcumulado = 0.0;
  DateTime? inicioSessao;
  StreamSubscription<List<int>>? _notificationSub;
  BluetoothCharacteristic? _bpmChar;
  BluetoothCharacteristic? _cmdChar;
  bool sessaoIniciada = false;
  bool bleConnected = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  final TextEditingController _fcRepousoCtrl = TextEditingController();
  List<int> _leituras = [];
  bool medindoFCRepouso = false;
  int tempoRestante = 300;
  Timer? _timerMedicao;
  bool exibindoDados = true;
  DateTime? _ultimoBpmTime;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _connect();
    _setupConnectionListener();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _timerMedicao?.cancel();
    _fcRepousoCtrl.dispose();
    _notificationSub?.cancel();
    _connectionStateSub?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _setupConnectionListener() {
    if (widget.device == null) return;
    _connectionStateSub = widget.device!.connectionState.listen((state) async {
      setState(
        () => bleConnected = state == BluetoothConnectionState.connected,
      );
      if (state == BluetoothConnectionState.disconnected &&
          widget.onDisconnect != null) {
        await widget.onDisconnect!();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dispositivo desconectado')),
          );
        }
      }
    });
  }

  Future<void> _connect() async {
    if (widget.device == null) return;
    try {
      final state = await widget.device!.state.first;
      if (state != BluetoothConnectionState.connected) {
        await widget.device!.connect(timeout: const Duration(seconds: 5));
      }
      await _discoverServices();
      setState(() => bleConnected = true);
    } catch (e) {
      setState(() => bleConnected = false);
    }
  }

  Future<void> _discoverServices() async {
    if (widget.device == null) return;
    final services = await widget.device!.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == charUuid) {
            _bpmChar = characteristic;
          } else if (characteristic.uuid == cmdCharUuid) {
            _cmdChar = characteristic;
          }
        }
      }
    }
  }

  void _subscribeToBpmNotifications() async {
    if (_bpmChar == null) return;
    await _bpmChar!.setNotifyValue(true);
    _notificationSub = _bpmChar!.value.listen((value) {
      if (value.isNotEmpty) {
        final bpm = value[0];
        inicioSessao ??= DateTime.now();
        final agora = DateTime.now();
        ultimaLeitura = bpm;
        _leituras.add(bpm);

        if (metodoMonitoramento == 'TRIMP' && fcRepouso != null) {
          int fcMax = 220 - widget.idade;
          double deltaHR = (bpm - fcRepouso!) / (fcMax - fcRepouso!);
          double y = 0.64 * exp(1.92 * deltaHR);
          if (_ultimoBpmTime != null) {
            final minutos = agora.difference(_ultimoBpmTime!).inSeconds / 60.0;
            trimpAcumulado += minutos * deltaHR * y;
          }
          _ultimoBpmTime = agora;
        }

        dadosBpm.add(
          FlSpot(
            DateTime.now().difference(inicioSessao!).inSeconds.toDouble(),
            bpm.toDouble(),
          ),
        );
        if (exibindoDados && mounted) setState(() {});
      }
    });
  }

  void _cancelNotificationSubscription() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _bpmChar?.setNotifyValue(false);
  }

  void _medirBatimentoRepouso() {
    setState(() {
      medindoFCRepouso = true;
      tempoRestante = 300;
      _fcRepousoCtrl.clear();
      _leituras.clear();
      inicioSessao = DateTime.now();
    });

    _timerMedicao?.cancel();
    _timerMedicao = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (tempoRestante > 0) {
        setState(() => tempoRestante--);
      } else {
        _finalizarMedicao();
        _timerMedicao?.cancel();
      }
    });

    _subscribeToBpmNotifications();
  }

  void _finalizarMedicao() {
    setState(() => medindoFCRepouso = false);
    _timerMedicao?.cancel();
    if (_leituras.isNotEmpty) {
      final media =
          (_leituras.reduce((a, b) => a + b) / _leituras.length).round();
      _fcRepousoCtrl.text = media.toString();
      String ultimaLeituraString =
          (ultimaLeitura != null) ? ultimaLeitura.toString() : 'N/A';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Medição concluída: $media bpm (Última leitura: $ultimaLeituraString bpm)',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma leitura registrada')),
      );
    }
    _cancelNotificationSubscription();
  }

  void _iniciarSessao() {
    final fcRepousoCampo = int.tryParse(_fcRepousoCtrl.text);
    if (esporte == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um esporte antes de iniciar a sessão.'),
        ),
      );
      return;
    }
    if (metodoMonitoramento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um método de monitoramento.')),
      );
      return;
    }
    if (fcRepousoCampo == null || fcRepousoCampo < 30 || fcRepousoCampo > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor válido para FC de repouso.'),
        ),
      );
      return;
    }
    setState(() {
      sessaoIniciada = true;
      exibindoDados = true;
      dadosBpm.clear();
      ultimaLeitura = null;
      fcRepouso = fcRepousoCampo;
      trimpAcumulado = 0.0;
      inicioSessao = DateTime.now();
    });

    if (bleConnected) {
      _subscribeToBpmNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão iniciada, coletando dados do dispositivo BLE'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo BLE não conectado.')),
      );
    }
  }

  void _resetar() {
    setState(() {
      sessaoIniciada = false;
      dadosBpm.clear();
      ultimaLeitura = null;
      trimpAcumulado = 0.0;
      inicioSessao = null;
      exibindoDados = true;
    });
    _cancelNotificationSubscription();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sessão resetada!')));
  }

  Future<void> _sendDeepSleepCommand() async {
    if (_cmdChar == null || widget.device == null) return;
    try {
      await _cmdChar!.write(utf8.encode("off"));
      await widget.device!.disconnect();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comando de deep sleep enviado')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao enviar comando: $e')));
    }
  }

  double _calcularFcMedia() {
    if (dadosBpm.isEmpty) return 0.0;
    double soma = dadosBpm.fold(0, (prev, spot) => prev + spot.y);
    return soma / dadosBpm.length;
  }

  List<double> _zonas() {
    if (fcRepouso == null || fcRepouso! <= 0 || widget.idade <= 0) return [];

    double fcMax = 220.0 - widget.idade;
    final double hrr = fcMax - fcRepouso!; // Heart Rate Reserve

    if (metodoMonitoramento == 'Karvonen') {
      // Retorna os limites (bpm) para 50%, 60%, 70%, 80% e 90% do HRR
      return [
        0.5,
        0.6,
        0.7,
        0.8,
        0.9,
      ].map((p) => fcRepouso! + hrr * p).toList();
    } else if (metodoMonitoramento == 'A-Zonas') {
      // Níveis absolutos ajustados para A‑Zonas
      return [110.0, 130.0, 150.0, 170.0];
    }
    return [];
  }

  String _zonaAtual() {
    if (ultimaLeitura == null ||
        metodoMonitoramento == null ||
        _fcRepousoCtrl.text.isEmpty)
      return 'A iniciar...';
    int fcMax = 220 - widget.idade;
    final fcRepousoUsado =
        int.tryParse(_fcRepousoCtrl.text) ?? (fcRepouso ?? 0);

    if (metodoMonitoramento == 'TRIMP') {
      return 'TRIMP: ${trimpAcumulado.toStringAsFixed(2)}';
    }

    if (metodoMonitoramento == 'Karvonen') {
      int reserva = fcMax - fcRepousoUsado;
      double intensidade =
          (ultimaLeitura! - fcRepousoUsado) / (reserva == 0 ? 1 : reserva);
      String zona;
      if (intensidade < 0.5)
        zona = 'Muito leve';
      else if (intensidade < 0.6)
        zona = 'Leve';
      else if (intensidade < 0.7)
        zona = 'Moderada';
      else if (intensidade < 0.8)
        zona = 'Intensa';
      else
        zona = 'Máxima';
      int perc = (intensidade * 100).round();
      return '$perc% - $zona';
    }

    // A‑Zonas (limiares absolutos ajustados)
    if (ultimaLeitura! < 110) return 'A1 (Regeneração)';
    if (ultimaLeitura! < 130) return 'A2 (Aeróbico)';
    if (ultimaLeitura! < 150) return 'A3 (Limiar)';
    if (ultimaLeitura! < 170) return 'AT (Anaeróbio limiar)';
    return 'AN (Anaeróbio)';
  }

  void _exportarDados(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => RelatorioPage(
              dadosBpm: List<FlSpot>.from(dadosBpm),
              esporte: esporte ?? '',
              fcRepouso:
                  (fcRepouso?.toDouble() ??
                      (int.tryParse(_fcRepousoCtrl.text) ?? 0).toDouble()),
              trimpAcumulado: trimpAcumulado,
              fcMedia: _calcularFcMedia(),
              fcMaxima: 220.0 - widget.idade,
              duracao:
                  inicioSessao != null
                      ? DateTime.now().difference(inicioSessao!)
                      : Duration.zero,
              metodo: metodoMonitoramento ?? '',
              idade: widget.idade,
              sexo: widget.sexo,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zonas = _zonas();
    final double maxY =
        (dadosBpm.isNotEmpty ? dadosBpm.map((e) => e.y).reduce(max) : 100) + 20;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text('Olá, ${widget.nome}'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _cancelNotificationSubscription();
            widget.device?.disconnect();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PaginaConfiguracao()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _sendDeepSleepCommand,
            tooltip: 'Desligar dispositivo',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Selecione o esporte:',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _SportButton(
                      icon: Icons.directions_run,
                      label: 'Corrida',
                      selected: esporte == 'Corrida',
                      onTap:
                          () => setState(() {
                            esporte = 'Corrida';
                            exibindoDados = true;
                          }),
                    ),
                    const SizedBox(width: 30),
                    _SportButton(
                      icon: Icons.directions_bike,
                      label: 'Ciclismo',
                      selected: esporte == 'Ciclismo',
                      onTap:
                          () => setState(() {
                            esporte = 'Ciclismo';
                            exibindoDados = true;
                          }),
                    ),
                    const SizedBox(width: 30),
                    _SportButton(
                      icon: Icons.fitness_center,
                      label: 'Musculação',
                      selected: esporte == 'Musculação',
                      onTap:
                          () => setState(() {
                            esporte = 'Musculação';
                            exibindoDados = true;
                          }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fcRepousoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Batimento de repouso (bpm)',
                        hintText:
                            medindoFCRepouso
                                ? 'Medindo...'
                                : 'Insira manualmente',
                        border: const OutlineInputBorder(),
                      ),
                      readOnly: medindoFCRepouso,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon:
                        medindoFCRepouso
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.timer),
                    onPressed: medindoFCRepouso ? null : _medirBatimentoRepouso,
                    tooltip: 'Medir automático (5min)',
                  ),
                ],
              ),
              if (medindoFCRepouso) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: 1 - (tempoRestante / 300),
                  backgroundColor: Colors.grey[200],
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 10),
                Text(
                  '${(tempoRestante ~/ 60).toString().padLeft(2, '0')}:${(tempoRestante % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (esporte != null)
                Text('Esporte: $esporte', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              const Text(
                'Selecione o método de monitoramento:',
                style: TextStyle(fontSize: 18),
              ),
              DropdownButton<String>(
                value: metodoMonitoramento,
                hint: const Text('Escolha um método'),
                items:
                    <String>['Karvonen', 'A-Zonas', 'TRIMP'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged:
                    (String? newValue) => setState(() {
                      metodoMonitoramento = newValue;
                      exibindoDados = true;
                    }),
              ),
              const SizedBox(height: 30),
              if (sessaoIniciada && exibindoDados) ...[
                const Text(
                  'Estatísticas',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Center(
                  child: InfoCard(
                    title: 'Última Leitura (BPM)',
                    value:
                        ultimaLeitura != null
                            ? '$ultimaLeitura bpm'
                            : 'A iniciar...',
                    icon: Icons.favorite,
                    color: Colors.redAccent,
                    height: 220,
                    width: 250,
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: InfoCard(
                    title:
                        metodoMonitoramento == 'TRIMP'
                            ? 'TRIMP Acumulado'
                            : 'Zona Atual',
                    value: _zonaAtual(),
                    icon: Icons.show_chart,
                    color: Colors.orangeAccent,
                    height: 220,
                    width: 250,
                    enableWrap: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 280,
                  child:
                      dadosBpm.isEmpty
                          ? const Center(
                            child: Text(
                              'Nenhum dado disponível para o gráfico.',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                          : LineChart(
                            LineChartData(
                              minX:
                                  dadosBpm.isNotEmpty
                                      ? (dadosBpm.last.x - 30).clamp(
                                        0,
                                        double.infinity,
                                      )
                                      : 0,
                              maxX: dadosBpm.isNotEmpty ? dadosBpm.last.x : 30,
                              minY: 40,
                              maxY: maxY,
                              lineBarsData: [
                                LineChartBarData(
                                  spots:
                                      dadosBpm
                                          .where(
                                            (spot) =>
                                                spot.x >=
                                                (dadosBpm.last.x - 30),
                                          )
                                          .toList(),
                                  isCurved: true,
                                  barWidth: 4,
                                  color: Colors.redAccent,
                                  dotData: FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.redAccent.withOpacity(0.15),
                                  ),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: 20,
                                    getTitlesWidget:
                                        (value, meta) => Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 5,
                                    getTitlesWidget:
                                        (value, meta) => Text(
                                          '${value.toInt()}s',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                verticalInterval: 5,
                                horizontalInterval: 20,
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: const Border(
                                  left: BorderSide(
                                    color: Colors.redAccent,
                                    width: 2,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.redAccent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              extraLinesData: ExtraLinesData(
                                horizontalLines:
                                    _zonas()
                                        .map(
                                          (z) => HorizontalLine(
                                            y: z,
                                            color: Colors.blueAccent
                                                .withOpacity(0.5),
                                            strokeWidth: 2,
                                            dashArray: [5, 5],
                                            label: HorizontalLineLabel(
                                              show: true,
                                              alignment: Alignment.topRight,
                                              labelResolver:
                                                  (_) => '${z.toInt()} bpm',
                                              style: const TextStyle(
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),
                ),
              ],
              const SizedBox(height: 30),
              Center(
                child: _StandardButton(
                  text: 'Iniciar Sessão',
                  onPressed:
                      (esporte != null &&
                              metodoMonitoramento != null &&
                              !sessaoIniciada)
                          ? _iniciarSessao
                          : null,
                  color: Colors.deepPurple,
                  icon: Icons.play_arrow,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: _StandardButton(
                  text: 'Resetar Sessão',
                  onPressed: sessaoIniciada ? _resetar : null,
                  color: Colors.grey,
                  icon: Icons.refresh,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: _StandardButton(
                  text: 'Parar Treino',
                  onPressed: () => setState(() => exibindoDados = false),
                  color: Colors.orange,
                  icon: Icons.stop,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: _StandardButton(
                  text: 'Exportar Dados',
                  onPressed: () => _exportarDados(context),
                  color: Colors.blue,
                  icon: Icons.file_download,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: _StandardButton(
                  text: 'Desconectar e Desligar',
                  onPressed: _sendDeepSleepCommand,
                  color: Colors.redAccent,
                  icon: Icons.power_settings_new,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SportButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? Colors.deepPurple : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.6),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
            border: Border.all(color: Colors.deepPurple),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 36,
                color: selected ? Colors.white : Colors.deepPurple,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double height;
  final double? width;
  final bool enableWrap;

  const InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.height = 180,
    this.width,
    this.enableWrap = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (enableWrap)
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class RelatorioPage extends StatelessWidget {
  final String esporte;
  final String metodo;
  final Duration duracao;
  final double fcMedia;
  final double fcMaxima;
  final double fcRepouso;
  final double trimpAcumulado;
  final List<FlSpot> dadosBpm;
  final int idade;
  final String sexo;
  final ScreenshotController _screenshotController = ScreenshotController();

  RelatorioPage({
    required this.esporte,
    required this.metodo,
    required this.duracao,
    required this.fcMedia,
    required this.fcMaxima,
    required this.fcRepouso,
    required this.trimpAcumulado,
    required this.dadosBpm,
    required this.idade,
    required this.sexo,
  });

  List<pw.Widget> _buildTabelaAgrupada() {
    if (dadosBpm.isEmpty) return [pw.Text('Nenhum dado disponível.')];
    final tempoTotal = dadosBpm.last.x;
    double intervalo;
    if (tempoTotal > 3600)
      intervalo = 600;
    else if (tempoTotal > 60)
      intervalo = 60;
    else
      intervalo = 10;

    List<pw.Widget> tabelas = [];
    double inicio = 0;
    int grupo = 1;
    while (inicio < tempoTotal) {
      final fim = inicio + intervalo;
      final grupoDados =
          dadosBpm.where((spot) => spot.x >= inicio && spot.x < fim).toList();
      if (grupoDados.isNotEmpty) {
        final titulo =
            tempoTotal > 3600
                ? 'Grupo $grupo: ${inicio ~/ 60} a ${fim ~/ 60} min'
                : tempoTotal > 60
                ? 'Minuto $grupo: ${inicio.toInt()}s a ${fim.toInt()}s'
                : 'Intervalo $grupo: ${inicio.toInt()}s a ${fim.toInt()}s';
        tabelas.add(
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple900,
            ),
          ),
        );
        tabelas.add(
          pw.Table.fromTextArray(
            headers: ['Tempo (s)', 'BPM'],
            data:
                grupoDados
                    .map(
                      (spot) => [
                        spot.x.toStringAsFixed(1),
                        spot.y.toStringAsFixed(1),
                      ],
                    )
                    .toList(),
            cellStyle: pw.TextStyle(fontSize: 12),
            headerStyle: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
            cellAlignment: pw.Alignment.center,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
          ),
        );
        tabelas.add(pw.SizedBox(height: 10));
      }
      inicio = fim;
      grupo++;
    }
    return tabelas;
  }

  List<double> _zonasPdf() {
    if (fcRepouso <= 0) return [];
    int fcMax = 220 - idade;
    if (metodo == 'Karvonen') {
      final double hrr = (fcMax - fcRepouso).toDouble();
      return [0.5, 0.6, 0.7, 0.8, 0.9].map((p) => fcRepouso + hrr * p).toList();
    } else if (metodo == 'A-Zonas') {
      // Níveis absolutos ajustados para A‑Zonas no PDF
      return [110.0, 130.0, 150.0, 170.0];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório da Sessão'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _gerarECompartilharPDF,
            tooltip: 'Gerar PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Resumo da Sessão',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildInfoRow('Esporte:', esporte),
                    _buildInfoRow('Método:', metodo),
                    _buildInfoRow('Duração:', '${duracao.inMinutes} minutos'),
                    _buildInfoRow(
                      'FC Repouso:',
                      '${fcRepouso.toStringAsFixed(0)} bpm',
                    ),
                    _buildInfoRow('Sexo:', sexo),
                    _buildInfoRow(
                      'FC Média:',
                      '${fcMedia.toStringAsFixed(1)} bpm',
                    ),
                    _buildInfoRow(
                      'FC Máxima:',
                      '${fcMaxima.toStringAsFixed(1)} bpm',
                    ),
                    if (metodo == 'TRIMP')
                      _buildInfoRow(
                        'TRIMP:',
                        trimpAcumulado.toStringAsFixed(2),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Evolução do Batimento Cardíaco',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: Screenshot(
                        controller: _screenshotController,
                        child: LineChart(
                          LineChartData(
                            minX: dadosBpm.isNotEmpty ? dadosBpm.first.x : 0,
                            maxX: dadosBpm.isNotEmpty ? dadosBpm.last.x : 60,
                            minY: 0,
                            maxY: fcMaxima + 20,
                            lineBarsData: [
                              LineChartBarData(
                                spots: dadosBpm,
                                isCurved: true,
                                color: Colors.deepPurple,
                                barWidth: 3,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.deepPurple.withOpacity(0.1),
                                ),
                              ),
                            ],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, meta) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        v.toInt().toString(),
                                        style: const TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                            extraLinesData: ExtraLinesData(
                              horizontalLines:
                                  _zonasPdf()
                                      .map(
                                        (z) => HorizontalLine(
                                          y: z,
                                          color: Colors.orangeAccent
                                              .withOpacity(0.5),
                                          strokeWidth: 2,
                                          dashArray: [5, 5],
                                          label: HorizontalLineLabel(
                                            show: true,
                                            alignment: Alignment.topRight,
                                            labelResolver:
                                                (_) => '${z.toInt()} bpm',
                                            style: const TextStyle(
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('Exportar Relatório Completo'),
              onPressed: _gerarECompartilharPDF,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _gerarECompartilharPDF() async {
    try {
      final pdfBytes = await _generatePDF();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'relatorio_${esporte.toLowerCase()}_${DateTime.now().toIso8601String()}.pdf',
      );
    } catch (e) {
      debugPrint('Erro ao gerar PDF: $e');
    }
  }

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();
    final Uint8List? chartImage = await _screenshotController.capture();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: 'Relatório de Atividade'),
              pw.SizedBox(height: 20),
              pw.Text('Esporte: $esporte'),
              pw.Text('Método: $metodo'),
              pw.Text('Duração: ${duracao.inMinutes} minutos'),
              pw.Text('Sexo: $sexo'),
              pw.Text('FC Repouso: ${fcRepouso.toStringAsFixed(0)} bpm'),
              pw.Text('FC Média: ${fcMedia.toStringAsFixed(1)} bpm'),
              pw.Text('FC Máxima: ${fcMaxima.toStringAsFixed(1)} bpm'),
              if (metodo == 'TRIMP')
                pw.Text('TRIMP: ${trimpAcumulado.toStringAsFixed(2)}'),
              pw.SizedBox(height: 20),
              if (chartImage != null)
                pw.Center(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Image(
                      pw.MemoryImage(chartImage),
                      width: 500,
                      height: 250,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                )
              else
                pw.Text('Gráfico não disponível'),
              pw.SizedBox(height: 10),
              pw.Text(
                'Eixo Y: Batimentos por minuto (bpm)\nEixo X: Tempo (segundos)',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              if (_zonasPdf().isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Zonas Cardíacas:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    ..._zonasPdf().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final valor = entry.value.toStringAsFixed(0);
                      String descricao = '';
                      if (metodo == 'Karvonen') {
                        switch (idx) {
                          case 0:
                            descricao = 'Muito leve (50%)';
                            break;
                          case 1:
                            descricao = 'Leve (60%)';
                            break;
                          case 2:
                            descricao = 'Moderada (70%)';
                            break;
                          case 3:
                            descricao = 'Intensa (80%)';
                            break;
                          case 4:
                            descricao = 'Máxima (90%)';
                            break;
                          default:
                            descricao = '';
                        }
                      } else if (metodo == 'A-Zonas') {
                        switch (idx) {
                          case 0:
                            descricao = 'A1 (Regeneração)';
                            break;
                          case 1:
                            descricao = 'A2 (Aeróbico)';
                            break;
                          case 2:
                            descricao = 'A3 (Limiar)';
                            break;
                          case 3:
                            descricao = 'AT (Anaeróbio limiar)';
                            break;
                          default:
                            descricao = '';
                        }
                      }
                      return pw.Text('${descricao}: ${valor} bpm');
                    }).toList(),
                  ],
                ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Resumo Estatístico:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Bullet(text: 'FC Média: ${fcMedia.toStringAsFixed(1)} bpm'),
              pw.Bullet(text: 'FC Máxima: ${fcMaxima.toStringAsFixed(1)} bpm'),
              pw.Bullet(
                text: 'FC Repouso: ${fcRepouso.toStringAsFixed(0)} bpm',
              ),
              if (metodo == 'TRIMP')
                pw.Bullet(text: 'TRIMP: ${trimpAcumulado.toStringAsFixed(2)}'),
              pw.SizedBox(height: 10),
              pw.Text(
                'Tabela de Batimentos Cardíacos',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              ..._buildTabelaAgrupada(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}

class _StandardButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  const _StandardButton({
    required this.text,
    required this.onPressed,
    this.color = Colors.deepPurple,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 48,
      child: ElevatedButton.icon(
        icon:
            icon != null
                ? Icon(icon, color: Colors.white)
                : const SizedBox.shrink(),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
