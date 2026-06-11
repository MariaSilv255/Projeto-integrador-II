import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/dashBoard.dart';
import 'package:projeto_integrador/tela_plantacao.dart';
import 'package:projeto_integrador/tela_configuracoes.dart';

class TelaPrincipal extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const TelaPrincipal({super.key, required this.usuario});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAtual = 0;
  String _mqttStatus = 'Offline';
  Timer? _statusTimer;

  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();
    _telas = [
      DashBoard(usuario: widget.usuario),
      TelaPlantacao(usuario: widget.usuario),
      TelaConfiguracoes(usuario: widget.usuario),
    ];
    _buscarStatusMQTT();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _buscarStatusMQTT();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _buscarStatusMQTT() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      final response = await http.get(Uri.parse('http://$host:8000/brokers/status/$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _mqttStatus = data['status'] ?? 'Offline';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _mqttStatus = 'Erro API');
    }
  }

  Color _getStatusColor() {
    switch (_mqttStatus) {
      case 'Conectado': return Colors.greenAccent;
      case 'Conectando...':
      case 'Reconectando...': return Colors.orangeAccent;
      default: return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Projeto Integrador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: _getStatusColor(), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'MQTT: $_mqttStatus',
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2F6B4F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: _telas[_indiceAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        selectedItemColor: const Color(0xFF2F6B4F),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.eco), label: 'Plantação'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
        onTap: (int indiceClicado) {
          setState((){
            _indiceAtual = indiceClicado;
          });
        },
      ),
    );
  }
}
