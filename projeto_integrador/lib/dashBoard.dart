import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/tela_detalhes_plantacao.dart';

class DashBoard extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const DashBoard({super.key, required this.usuario});

  @override
  State<DashBoard> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  Map<String, dynamic> _dadosMqtt = {};
  List<dynamic> _plantacoesSalvas = [];
  bool _isLoading = true;
  Timer? _timer;

  static const Color _primaryGreen = Color(0xFF2F6B4F);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _buscarTudo();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _buscarDadosTempoReal();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _buscarTudo() async {
    await _buscarPlantacoesSalvas();
    await _buscarDadosTempoReal();
  }

  Future<void> _buscarPlantacoesSalvas() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      if (userId == null) return;
      final response = await http.get(Uri.parse('http://$host:8000/plantacoes/usuario/$userId'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && mounted) {
          setState(() {
            _plantacoesSalvas = decoded;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro busca salvas: $e');
    }
  }

  Future<void> _buscarDadosTempoReal() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      if (userId == null) return;
      final response = await http.get(Uri.parse('http://$host:8000/plantacoes/dados-tempo-real/$userId'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && mounted) {
          setState(() {
            _dadosMqtt = decoded;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dadosMqtt.isEmpty && _plantacoesSalvas.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryGreen));
    }
    return Scaffold(
      backgroundColor: _backgroundGrey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visão Geral', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text('Monitoramento de ${_plantacoesSalvas.length} plantações registradas', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            if (_plantacoesSalvas.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _plantacoesSalvas.length,
                itemBuilder: (context, index) {
                  final plantacao = _plantacoesSalvas[index];
                  final String baseTopic = (plantacao['topico'] ?? '').toString().toLowerCase();
                  Map<String, dynamic> dadosAgrupados = {};
                  _dadosMqtt.forEach((key, payload) {
                    final normalizedKey = key.toLowerCase();
                    if (payload is Map) {
                      if (normalizedKey == baseTopic || normalizedKey.startsWith('$baseTopic/')) {
                        dadosAgrupados.addAll(Map<String, dynamic>.from(payload));
                      }
                    }
                  });
                  String? deviceId = plantacao['device_id'];
                  if (deviceId == null || deviceId == 'Desconhecido') {
                    deviceId = dadosAgrupados['dispositivo']?.toString();
                  }
                  final String dispExibicao = deviceId ?? 'Desconhecido';
                  final temp = dadosAgrupados['temperatura'] ?? '--';
                  final umiSolo = dadosAgrupados['umiSolo'] ?? '--';
                  final umiAmb = dadosAgrupados['umiAmbiente'] ?? '--';
                  final solenoideLigado = dadosAgrupados['solenoide'] == 1;
                  final bombaLigada = dadosAgrupados['moduloRele'] == 1;
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaDetalhesPlantacao(plantacao: plantacao, usuario: widget.usuario))),
                    child: _buildPlantacaoCard(plantacao['descricao'].toString(), dispExibicao, temp.toString(), umiSolo.toString(), umiAmb.toString(), solenoideLigado, bombaLigada),
                  );
                },
              ),
            const SizedBox(height: 32),
            _buildInfoMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Column(
        children: [
          Icon(Icons.eco_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text('Nenhuma plantação cadastrada.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          Text('Vá na aba "Plantação" para adicionar.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _primaryGreen.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: _primaryGreen.withValues(alpha: 0.1))),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: _primaryGreen),
          SizedBox(width: 12),
          Expanded(child: Text('Clique em um card acima para acessar detalhes e controle manual.', style: TextStyle(fontSize: 13, color: _primaryGreen, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPlantacaoCard(String nome, String disp, String temp, String umid, String umidAmb, bool sol, bool bom) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: _primaryGreen.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.eco, color: _primaryGreen, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))), Text('Dispositivo: $disp', style: const TextStyle(fontSize: 11, color: Colors.grey))])),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFCBD5E1)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSensorInfo(Icons.thermostat, Colors.orange, 'Temp.', '$temp°C'),
              _buildSensorInfo(Icons.water_drop, Colors.blue, 'Solo', '$umid%'),
              _buildSensorInfo(Icons.cloud_outlined, Colors.cyan, 'Ar', '$umidAmb%'),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [_buildBadge('Solenoide', sol), const SizedBox(width: 8), _buildBadge('Bomba', bom)]),
        ],
      ),
    );
  }

  Widget _buildSensorInfo(IconData icon, Color color, String label, String val) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, bool isOn) {
    final color = isOn ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}
