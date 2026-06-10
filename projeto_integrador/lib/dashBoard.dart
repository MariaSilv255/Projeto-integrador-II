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

  static const Color _primaryGreen = Color(0xFF2F6B4F);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _buscarDados();
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
        if (mounted) {
          setState(() {
            _dadosMqtt = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enviarComando(String atuador, int valor) async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      const String topicoComando = 'Equipe3/atuadores';
      
      final response = await http.post(
        Uri.parse('http://$host:8000/irrigacao/comando'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topico': topicoComando,
          'comando': {atuador: valor},
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comando enviado para $atuador'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryGreen,
          ),
        );
        // Busca os dados imediatamente após o comando para refletir a mudança
        await _buscarDados();
      }
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dadosMqtt.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryGreen));
    }

    final sensores = _dadosMqtt['Equipe3/sensores'] ?? {};
    final atuadores = _dadosMqtt['Equipe3/atuadores'] ?? {};

    return Scaffold(
      backgroundColor: _backgroundGrey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Geral',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Acompanhe os sensores em tempo real',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            
            // Grid de Sensores
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildSensorCard('Temperatura', '${sensores['temperatura'] ?? '--'}°C', Icons.thermostat, Colors.orange),
                _buildSensorCard('Umidade Solo', '${sensores['umiSolo'] ?? '--'}%', Icons.water_drop, Colors.blue),
                _buildSensorCard('Umid. Ambiente', '${sensores['umiAmbiente'] ?? '--'}%', Icons.cloud, Colors.cyan),
                _buildSensorCard('Dispositivos', '${_dadosMqtt.length}', Icons.sensors, Colors.purple),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text(
              'Controle de Atuadores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            
            _buildAtuadorCard('Solenoide de Irrigação', atuadores['solenoide'] == 1, Icons.waves, (v) => _enviarComando('solenoide', v ? 1 : 0)),
            const SizedBox(height: 12),
            _buildAtuadorCard('Bomba Hidráulica', atuadores['moduloRele'] == 1, Icons.settings_input_component, (v) => _enviarComando('moduloRele', v ? 1 : 0)),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String label, String valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icone, color: cor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAtuadorCard(String label, bool ativo, IconData icone, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (ativo ? Colors.green : Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icone, color: ativo ? Colors.green : Colors.grey, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(ativo ? 'Operando' : 'Inativo', style: TextStyle(color: ativo ? Colors.green : Colors.grey, fontSize: 12)),
        value: ativo,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }
}
