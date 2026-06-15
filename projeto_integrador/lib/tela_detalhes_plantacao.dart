import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';

class TelaDetalhesPlantacao extends StatefulWidget {
  final Map<String, dynamic> plantacao;
  final Map<String, dynamic> usuario;
  const TelaDetalhesPlantacao({super.key, required this.plantacao, required this.usuario});

  @override
  State<TelaDetalhesPlantacao> createState() => _TelaDetalhesPlantacaoState();
}

class _TelaDetalhesPlantacaoState extends State<TelaDetalhesPlantacao> {
  static const Color _primaryGreen = Color(0xFF2F6B4F);
  final Map<String, dynamic> _dadosAtuais = {};
  final Map<String, dynamic> _statusAtuadores = {};
  bool _isHardwareOffline = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _buscarDadosMQTT();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _buscarDadosMQTT();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _buscarDadosMQTT() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      final response = await http.get(Uri.parse('http://$host:8000/plantacoes/dados-tempo-real/$userId'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> todosDados = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            final String baseTopic = (widget.plantacao['topico'] ?? '').toString().toLowerCase();
            final String savedDeviceId = (widget.plantacao['device_id'] ?? 'Desconhecido').toString();
            
            _dadosAtuais.clear();
            _statusAtuadores.clear();
            String lastSensorName = 'Desconhecido';
            bool foundOnlineSignal = false;

            todosDados.forEach((key, payload) {
              final normalizedKey = key.toLowerCase();
              if (payload is Map) {
                if (normalizedKey == baseTopic || normalizedKey.startsWith('$baseTopic/')) {
                  if (normalizedKey.contains('/sensores/')) {
                    _dadosAtuais.addAll(Map<String, dynamic>.from(payload));
                    lastSensorName = key.split('/').last;
                  } else if (normalizedKey.contains('/atuadores/')) {
                    _statusAtuadores.addAll(Map<String, dynamic>.from(payload));
                  } else {
                    _dadosAtuais.addAll(Map<String, dynamic>.from(payload));
                  }
                  if (payload['_offline'] == false) foundOnlineSignal = true;
                }
                
                final deviceStatusTopic = 'equipe3/dispositivos/${savedDeviceId.toLowerCase()}/status';
                if (normalizedKey == deviceStatusTopic) {
                  if (payload['value'] == 'online') foundOnlineSignal = true;
                  if (payload['value'] == 'offline') foundOnlineSignal = false;
                }
              }
            });
            _isHardwareOffline = !foundOnlineSignal;
            _dadosAtuais['nome_sensor_UI'] = lastSensorName;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro MQTT: $e');
    }
  }

  Future<void> _enviarComando(String atuador, int valor) async {
    if (_isHardwareOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo OFFLINE. Verifique a conexão do hardware.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      
      String? dispositivo = widget.plantacao['device_id'];
      if (dispositivo == null || dispositivo == 'Desconhecido') {
        dispositivo = _dadosAtuais['dispositivo']?.toString();
      }
      
      if (dispositivo == null || dispositivo == 'Desconhecido') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do hardware ainda não identificado.'), backgroundColor: Colors.orangeAccent),
        );
        return;
      }
                                 
      final String topicoComando = 'Equipe3/dispositivos/$dispositivo/comando';

      final int solVal = (atuador == 'solenoide') ? valor : (_statusAtuadores['solenoide'] ?? 0);
      final int relVal = (atuador == 'moduloRele') ? valor : (_statusAtuadores['moduloRele'] ?? 0);

      final response = await http.post(
        Uri.parse('http://$host:8000/plantacoes/comando/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topico': topicoComando,
          'comando': {
            'solenoide': solVal,
            'moduloRele': relVal,
          },
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${atuador.toUpperCase()} -> ${valor == 1 ? "LIGADO" : "DESLIGADO"}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryGreen,
          ),
        );
        await _buscarDadosMQTT();
      }
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  void _confirmarAcao(String chaveAtuador, int valor, String nomeVisivel) {
    final acao = valor == 1 ? 'LIGAR' : 'DESLIGAR';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmação'),
        content: Text('Tem certeza que deseja $acao o atuador "$nomeVisivel"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _enviarComando(chaveAtuador, valor);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(widget.plantacao['descricao'], overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (_isHardwareOffline ? Colors.redAccent : Colors.green).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: (_isHardwareOffline ? Colors.redAccent : Colors.green).withValues(alpha: 0.3))),
              child: Text(_isHardwareOffline ? 'OFFLINE' : 'ONLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isHardwareOffline ? Colors.redAccent : Colors.green)),
            ),
          ],
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isHardwareOffline) ...[
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2))),
                child: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20), SizedBox(width: 12), Expanded(child: Text('Hardware desconectado. Os dados podem estar desatualizados e os comandos não funcionarão.', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)))]),
              ),
              const SizedBox(height: 24),
            ],
            const Text('Sensores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            _buildSensorRow(),
            const SizedBox(height: 40),
            const Text('Controle de Atuadores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('Acione os componentes manualmente', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            
            _buildControleSection('Solenoide', 'solenoide'),
            const SizedBox(height: 20),
            _buildControleSection('Bomba de Água', 'moduloRele'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow() {
    final String umidVal = _dadosAtuais['umidade']?.toString() ?? _dadosAtuais['umiSolo']?.toString() ?? '--';

    return Row(
      children: [
        Expanded(child: _buildMiniCard('Temperatura', '${_dadosAtuais['temperatura'] ?? '--'}°C', Icons.thermostat, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildMiniCard('Umidade', umidVal.contains(':') ? umidVal.split(':').last.trim() : '$umidVal%', Icons.water_drop, Colors.blue)),
      ],
    );
  }

  Widget _buildMiniCard(String label, String valor, IconData icon, Color color) {
    final String origemSensor = _dadosAtuais['nome_sensor_UI'] ?? 'Desconhecido';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20)]),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 12),
          Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(origemSensor, style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildControleSection(String label, String chaveAtuador) {
    final bool estaLigado = _statusAtuadores[chaveAtuador] == 1;
    return Opacity(
      opacity: _isHardwareOffline ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          children: [
            Row(
              children: [
                Icon(chaveAtuador == 'solenoide' ? Icons.waves : Icons.settings_input_component, color: estaLigado ? Colors.green : Colors.grey),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (estaLigado ? Colors.green : Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text(estaLigado ? 'LIGADO' : 'DESLIGADO', style: TextStyle(color: estaLigado ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _isHardwareOffline ? null : () => _confirmarAcao(chaveAtuador, 1, label), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('LIGAR', style: TextStyle(fontWeight: FontWeight.bold)))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _isHardwareOffline ? null : () => _confirmarAcao(chaveAtuador, 0, label), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), foregroundColor: const Color(0xFF475569), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('DESLIGAR', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
