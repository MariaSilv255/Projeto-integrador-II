import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/tela_detalhes_plantacao.dart';

class TelaPlantacao extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const TelaPlantacao({super.key, required this.usuario});

  @override
  State<TelaPlantacao> createState() => _TelaPlantacaoState();
}

class _TelaPlantacaoState extends State<TelaPlantacao> {
  static const Color _primaryGreen = Color(0xFF2F6B4F);
  bool _isLoading = true;
  List<dynamic> _irrigacoes = [];
  Map<String, dynamic> _dadosTempoReal = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) => _carregarDados(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      
      final responseIrrig = await http.get(
        Uri.parse('http://$host:8000/irrigacao/usuario/${widget.usuario['id']}'),
      );

      final responseMqtt = await http.get(
        Uri.parse('http://$host:8000/irrigacao/dados-tempo-real'),
      );

      if (responseIrrig.statusCode == 200) {
        _irrigacoes = jsonDecode(responseIrrig.body);
      }
      
      if (responseMqtt.statusCode == 200) {
        _dadosTempoReal = jsonDecode(responseMqtt.body);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _criarIrrigacao() async {
    final TextEditingController descricaoController = TextEditingController();
    String? topicoSelecionado;
    List<String> topicosDescobertos = [];

    // Busca tópicos que o backend já "viu"
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final resp = await http.get(Uri.parse('http://$host:8000/irrigacao/topicos-descobertos'));
      if (resp.statusCode == 200) {
        topicosDescobertos = List<String>.from(jsonDecode(resp.body));
      }
    } catch (e) {
      debugPrint('Erro ao buscar tópicos: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vincular Nova Plantação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Plantação',
                  hintText: 'Ex: Horta dos Fundos',
                ),
              ),
              const SizedBox(height: 20),
              const Text('Selecione o dispositivo (Tópico MQTT):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (topicosDescobertos.isEmpty)
                const Text('Nenhum dispositivo detectado no momento.', style: TextStyle(fontSize: 11, color: Colors.grey))
              else
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Escolha um tópico descoberto'),
                  value: topicoSelecionado,
                  items: topicosDescobertos.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => topicoSelecionado = val);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (descricaoController.text.isNotEmpty && topicoSelecionado != null) {
                  Navigator.pop(context);
                  await _salvarIrrigacao(descricaoController.text, topicoSelecionado!);
                }
              },
              child: const Text('Vincular'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarIrrigacao(String descricao, String topico) async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/irrigacao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fk_id_usuario': widget.usuario['id'],
          'descricao': descricao,
          'topico': topico,
          'fk_id_broker': 1,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarDados();
      }
    } catch (e) {
      debugPrint('Erro ao salvar irrigacao: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _irrigacoes.isEmpty
              ? const Center(child: Text('Nenhuma plantação vinculada.'))
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: ListView.builder(
                    itemCount: _irrigacoes.length,
                    itemBuilder: (context, index) {
                      final item = _irrigacoes[index];
                      final String topico = item['topico'] ?? '';
                      final dadosSensor = _dadosTempoReal[topico];
                      
                      String sensorInfo = 'Aguardando dados...';
                      if (dadosSensor != null && dadosSensor is Map) {
                        final temp = dadosSensor['temperatura'];
                        final umi = dadosSensor['umiSolo'];
                        sensorInfo = 'Temp: ${temp ?? '--'}°C | Umid. Solo: ${umi ?? '--'}%';
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaDetalhesPlantacao(plantacao: item),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _primaryGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.eco, color: _primaryGreen),
                            ),
                            title: Text(
                              item['descricao'] ?? 'Sem nome',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Disp: $topico', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.bolt, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      sensorInfo,
                                      style: const TextStyle(
                                        color: _primaryGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
                                await http.delete(Uri.parse('http://$host:8000/irrigacao/${item['id']}'));
                                _carregarDados();
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarIrrigacao,
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add_link, color: Colors.white),
        label: const Text('Vincular Sensor', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
