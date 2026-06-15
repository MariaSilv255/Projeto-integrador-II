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
  List<dynamic> _plantacoes = [];
  Map<String, dynamic> _dadosTempoReal = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _carregarDados(silent: true);
    });
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
      final userId = widget.usuario['id'];
      
      final responsePlant = await http.get(
        Uri.parse('http://$host:8000/plantacoes/usuario/$userId'),
      );

      final responseMqtt = await http.get(
        Uri.parse('http://$host:8000/plantacoes/dados-tempo-real/$userId'),
      );

      if (responsePlant.statusCode == 200) {
        final decoded = jsonDecode(responsePlant.body);
        if (decoded is List) _plantacoes = decoded;
      }
      
      if (responseMqtt.statusCode == 200) {
        final decoded = jsonDecode(responseMqtt.body);
        if (decoded is Map<String, dynamic>) _dadosTempoReal = decoded;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletarPlantacao(int id, String nome) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a plantação "$nome"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
        final response = await http.delete(Uri.parse('http://$host:8000/plantacoes/$id'));
        if (response.statusCode == 200) {
          _carregarDados();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantação removida com sucesso')));
          }
        }
      } catch (e) {
        debugPrint('Erro deletar: $e');
      }
    }
  }

  Future<void> _abrirDialogoEdicao(Map<String, dynamic> item) async {
    final TextEditingController descricaoController = TextEditingController(text: item['descricao']);
    String? topicoSelecionado = item['topico'];
    List<String> topicosDescobertos = [];

    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      final resp = await http.get(Uri.parse('http://$host:8000/plantacoes/topicos-descobertos/$userId'));
      if (resp.statusCode == 200) {
        final List<String> todos = List<String>.from(jsonDecode(resp.body));
        final Set<String> baseTopics = {};
        for (final t in todos) {
          final topic = t.toLowerCase();
          if (topic.startsWith('equipe3/plantacoes/')) {
            final parts = topic.split('/');
            if (parts.length >= 3) {
              baseTopics.add('${parts[0]}/${parts[1]}/${parts[2]}');
            }
          }
        }
        if (topicoSelecionado != null) baseTopics.add(topicoSelecionado);
        topicosDescobertos = baseTopics.toList();
      }
    } catch (e) {
      debugPrint('Erro buscar topicos: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Plantação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: 'Nome da Plantação'),
              ),
              const SizedBox(height: 20),
              const Text('Dispositivo/Tópico:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: topicoSelecionado,
                items: topicosDescobertos.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (val) => setDialogState(() => topicoSelecionado = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (descricaoController.text.isNotEmpty && topicoSelecionado != null) {
                  String deviceId = item['device_id'] ?? 'Desconhecido';
                  final String base = topicoSelecionado!.toLowerCase();
                  _dadosTempoReal.forEach((key, payload) {
                    final k = key.toLowerCase();
                    if ((k == base || k.startsWith('$base/')) && payload is Map) {
                      if (payload.containsKey('dispositivo')) {
                        deviceId = payload['dispositivo'].toString();
                      }
                    }
                  });
                  Navigator.pop(context);
                  await _atualizarPlantacao(item['id'], descricaoController.text, topicoSelecionado!, deviceId);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _atualizarPlantacao(int id, String descricao, String topico, String deviceId) async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.put(
        Uri.parse('http://$host:8000/plantacoes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fk_id_usuario': widget.usuario['id'],
          'descricao': descricao,
          'topico': topico,
          'device_id': deviceId,
          'fk_id_broker': 1,
        }),
      );
      if (response.statusCode == 200) {
        _carregarDados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantação atualizada com sucesso')));
        }
      }
    } catch (e) {
      debugPrint('Erro atualizar: $e');
    }
  }

  Future<void> _criarPlantacao() async {
    final TextEditingController descricaoController = TextEditingController();
    String? topicoSelecionado;
    List<String> topicosDescobertos = [];

    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      final resp = await http.get(Uri.parse('http://$host:8000/plantacoes/topicos-descobertos/$userId'));
      if (resp.statusCode == 200) {
        final List<String> todos = List<String>.from(jsonDecode(resp.body));
        final Set<String> baseTopics = {};
        for (final t in todos) {
          final topic = t.toLowerCase();
          if (topic.startsWith('equipe3/plantacoes/')) {
            final parts = topic.split('/');
            if (parts.length >= 3) {
              baseTopics.add('${parts[0]}/${parts[1]}/${parts[2]}');
            }
          }
        }
        topicosDescobertos = baseTopics.toList();
      }
    } catch (e) {
      debugPrint('Erro buscar topicos: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Plantação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(labelText: 'Nome da Plantação', hintText: 'Ex: Horta dos Fundos'),
              ),
              const SizedBox(height: 20),
              const Text('Selecione o dispositivo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (topicosDescobertos.isEmpty)
                const Text('Nenhum dispositivo detectado.', style: TextStyle(fontSize: 11, color: Colors.grey))
              else
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Escolha um tópico'),
                  value: topicoSelecionado,
                  items: topicosDescobertos.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => topicoSelecionado = val),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (descricaoController.text.isNotEmpty && topicoSelecionado != null) {
                  String deviceId = 'Desconhecido';
                  final String base = topicoSelecionado!.toLowerCase();
                  _dadosTempoReal.forEach((key, payload) {
                    final k = key.toLowerCase();
                    if ((k == base || k.startsWith('$base/')) && payload is Map) {
                      if (payload.containsKey('dispositivo')) {
                        deviceId = payload['dispositivo'].toString();
                      }
                    }
                  });
                  Navigator.pop(context);
                  await _salvarPlantacao(descricaoController.text, topicoSelecionado!, deviceId);
                }
              },
              child: const Text('Vincular'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarPlantacao(String descricao, String topico, String deviceId) async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/plantacoes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fk_id_usuario': widget.usuario['id'],
          'descricao': descricao,
          'topico': topico,
          'device_id': deviceId,
          'fk_id_broker': 1,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarDados();
      }
    } catch (e) {
      debugPrint('Erro salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : _plantacoes.isEmpty
              ? const Center(child: Text('Nenhuma plantação vinculada.'))
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 80),
                    itemCount: _plantacoes.length,
                    itemBuilder: (context, index) {
                      final item = _plantacoes[index];
                      final String topico = (item['topico'] ?? '').toString().toLowerCase();
                      String? deviceId = item['device_id'];
                      
                      Map<String, dynamic> sensorAgrupado = {};
                      _dadosTempoReal.forEach((key, payload) {
                        final normalizedKey = key.toLowerCase();
                        if ((normalizedKey == topico || normalizedKey.startsWith('$topico/')) && payload is Map) {
                          sensorAgrupado.addAll(Map<String, dynamic>.from(payload));
                        }
                      });
                      
                      if (deviceId == null || deviceId == 'Desconhecido') {
                        deviceId = sensorAgrupado['dispositivo']?.toString();
                      }
                      
                      final String dispExibicao = deviceId ?? 'Desconhecido';

                      String sensorInfo = 'Aguardando dados...';
                      if (sensorAgrupado.isNotEmpty) {
                        final temp = sensorAgrupado['temperatura'];
                        final umi = sensorAgrupado['umidade'] ?? sensorAgrupado['umiSolo'];
                        sensorInfo = 'Temp: ${temp ?? '--'}°C | Umidade: ${umi ?? '--'}%';
                      }

                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaDetalhesPlantacao(plantacao: item, usuario: widget.usuario))),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: _primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.eco, color: _primaryGreen, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['descricao'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 2),
                                      Text('ID: $dispExibicao', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.sensors, size: 14, color: _primaryGreen),
                                          const SizedBox(width: 6),
                                          Text(sensorInfo, style: const TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.settings, color: Color(0xFF94A3B8), size: 22),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      _abrirDialogoEdicao(item);
                                    } else if (val == 'delete') {
                                      _deletarPlantacao(item['id'], item['descricao']);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text('Excluir', style: TextStyle(color: Colors.redAccent))])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarPlantacao,
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Plantação', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
