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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dadosMqtt.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryGreen));
    }

    // Filtra os tópicos para remover os de sistema
    final topicosValidos = _dadosMqtt.keys.where((t) {
      return !t.endsWith('/sensores') && 
             !t.endsWith('/atuadores') && 
             !t.endsWith('/dispositivos') && 
             !t.endsWith('/comando');
    }).toList();

    return Scaffold(
      backgroundColor: _backgroundGrey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visão Geral',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitoramento de ${topicosValidos.length} plantações ativas',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),

            if (topicosValidos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.sensors_off, size: 48, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 16),
                    Text('Nenhum dado de plantação recebido ainda.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topicosValidos.length,
                itemBuilder: (context, index) {
                  final topico = topicosValidos[index];
                  final dados = _dadosMqtt[topico];
                  
                  final dispositivo = dados['dispositivo'] ?? 'Dispositivo Desconhecido';
                  final temp = dados['temperatura'] ?? '--';
                  final umiSolo = dados['umiSolo'] ?? '--';

                  return _buildPlantacaoCard(topico, dispositivo.toString(), temp.toString(), umiSolo.toString());
                },
              ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryGreen.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _primaryGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Para controlar os atuadores, selecione uma plantação específica na aba "Plantação".',
                      style: TextStyle(fontSize: 13, color: _primaryGreen, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantacaoCard(String topico, String dispositivo, String temp, String umidade) {
    // Formata o nome do tópico para exibição (ex: Equipe3/trigo -> trigo)
    final nomeExibicao = topico.split('/').last.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.eco, color: _primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomeExibicao, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Text('Dispositivo: $dispositivo', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.thermostat, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Temp.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('$temp°C', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blue, size: 18),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Umid. Solo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('$umidade%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
