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
  final Map<String, dynamic> _sensoresIndividuais = {};
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
            
            _sensoresIndividuais.clear();
            _statusAtuadores.clear();
            bool foundOnlineSignal = false;

            todosDados.forEach((key, payload) {
              final normalizedKey = key.toLowerCase();
              if (payload is Map) {
                if (normalizedKey == baseTopic || normalizedKey.startsWith('$baseTopic/')) {
                  if (normalizedKey.contains('/sensores/')) {
                    _sensoresIndividuais[key] = payload;
                  } else if (normalizedKey.contains('/atuadores/')) {
                    _statusAtuadores.addAll(Map<String, dynamic>.from(payload));
                  } else {
                    _sensoresIndividuais[key] = payload;
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
        _sensoresIndividuais.forEach((key, val) {
          if (val is Map && val.containsKey('dispositivo')) {
            dispositivo = val['dispositivo'].toString();
          }
        });
      }
      
      if (dispositivo == null || dispositivo == 'Desconhecido') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID do hardware não identificado.'), backgroundColor: Colors.orangeAccent),
        );
        return;
      }
                                 
      // O atuador já corresponde ao sub-tópico correto (ex: 'bomba' ou 'solenoide')
      final String subTopico = atuador;
      
      final String topicoComando = 'Equipe3/dispositivos/$dispositivo/comandos/$subTopico';

      // Envia apenas o estado (valor numérico) para aquele tópico específico
      final response = await http.post(
        Uri.parse('http://$host:8000/plantacoes/comando/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topico': topicoComando,
          'comando': {atuador: valor},
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
                child: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20), SizedBox(width: 12), Expanded(child: Text('Hardware desconectado.', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)))]),
              ),
              const SizedBox(height: 24),
            ],
            const Text('Sensores por Tópico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            
            if (_sensoresIndividuais.isEmpty)
              const Center(child: Text('Aguardando sensores...', style: TextStyle(color: Colors.grey)))
            else
              ..._sensoresIndividuais.entries.map((entry) => _buildSensorCard(entry.key, entry.value)).toList(),

            const SizedBox(height: 40),
            const Text('Controle de Atuadores', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('Acione os componentes manualmente', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            
            _buildControleSection('Solenoide', 'solenoide'),
            const SizedBox(height: 20),
            _buildControleSection('Bomba de Água', 'bomba'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String topico, dynamic dados) {
    final String nomeSensor = topico.split('/').last.toUpperCase();
    final temp = dados['temperatura'];
    final umid = dados['umidade'] ?? dados['umiSolo'];
    final String valRaw = dados['value']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20)],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: _primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text(nomeSensor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryGreen)),
            ],
          ),
          const SizedBox(height: 16),
          if (valRaw.isNotEmpty && temp == null && umid == null)
            Text(valRaw.contains(':') ? valRaw.split(':').last.trim() : valRaw, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))
          else
            Row(
              children: [
                if (temp != null)
                  Expanded(child: _buildSensorItem(Icons.thermostat, Colors.orange, 'Temp.', '$temp°C')),
                if (umid != null)
                  Expanded(child: _buildSensorItem(Icons.water_drop, Colors.blue, 'Umidade', umid.toString().contains(':') ? umid.split(':').last.trim() : '$umid%')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSensorItem(IconData icon, Color color, String label, String val) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          ],
        ),
      ],
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
