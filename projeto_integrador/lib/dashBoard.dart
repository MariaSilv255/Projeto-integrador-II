import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<DashBoard> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  Map<String, dynamic> _dadosMqtt = {};
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _buscarDados();
    // Inicia polling a cada 5 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) => _buscarDados());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _buscarDados() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.get(Uri.parse('http://$host:8000/irrigacao/dados-tempo-real'));
      if (response.statusCode == 200) {
        setState(() {
          _dadosMqtt = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        // Trata erro (ex: 404 quando não há dados)
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar dados MQTT: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dadosMqtt.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dadosMqtt.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Aguardando dados do broker...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _buscarDados,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final sensores = _dadosMqtt['Equipe3/sensores'] ?? {};
    final atuadores = _dadosMqtt['Equipe3/atuadores'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccaoTitulo('Sensores em Tempo Real'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCardDados('Temperatura', '${sensores['temperatura'] ?? '--'}°C', Icons.thermostat, Colors.orange)),
              const SizedBox(width: 10),
              Expanded(child: _buildCardDados('Umid. Solo', '${sensores['umiSolo'] ?? '--'}%', Icons.water_drop, Colors.blue)),
            ],
          ),
          const SizedBox(height: 10),
          _buildCardDados('Umidade Ambiente', '${sensores['umiAmbiente'] ?? '--'}%', Icons.cloud, Colors.lightBlue),
          
          const SizedBox(height: 24),
          _buildSeccaoTitulo('Status dos Atuadores'),
          const SizedBox(height: 10),
          _buildCardStatus('Solenoide', atuadores['solenoide'] == 1, Icons.water_drop),
          const SizedBox(height: 10),
          _buildCardStatus('Módulo Relé (Bomba)', atuadores['moduloRele'] == 1, Icons.power),
        ],
      ),
    );
  }

  Widget _buildSeccaoTitulo(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F6B4F)),
    );
  }

  Widget _buildCardDados(String label, String valor, IconData icone, Color cor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStatus(String label, bool ativo, IconData icone) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icone, color: ativo ? Colors.green : Colors.red),
        title: Text(label),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ativo ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            ativo ? 'ATIVO' : 'DESATIVADO',
            style: TextStyle(color: ativo ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
