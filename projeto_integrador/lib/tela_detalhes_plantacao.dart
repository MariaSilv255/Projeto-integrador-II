import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';

class TelaDetalhesPlantacao extends StatefulWidget {
  final Map<String, dynamic> plantacao;
  const TelaDetalhesPlantacao({super.key, required this.plantacao});

  @override
  State<TelaDetalhesPlantacao> createState() => _TelaDetalhesPlantacaoState();
}

class _TelaDetalhesPlantacaoState extends State<TelaDetalhesPlantacao> {
  static const Color _primaryGreen = Color(0xFF2F6B4F);
  List<dynamic> _agendamentos = [];
  Map<String, dynamic> _dadosAtuais = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _buscarDadosMQTT());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    await _buscarDadosMQTT();
    await _carregarAgendamentos();
  }

  Future<void> _buscarDadosMQTT() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.get(Uri.parse('http://$host:8000/irrigacao/dados-tempo-real'));
      if (response.statusCode == 200) {
        final todosDados = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _dadosAtuais = todosDados[widget.plantacao['topico']] ?? {};
          });
        }
      }
    } catch (e) {
      debugPrint('Erro MQTT: $e');
    }
  }

  Future<void> _carregarAgendamentos() async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.get(Uri.parse('http://$host:8000/agendamentos/irrigacao/${widget.plantacao['id']}'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _agendamentos = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint('Erro Agendamentos: $e');
    }
  }

  Future<void> _criarAgendamento() async {
    TimeOfDay? selectedTime = const TimeOfDay(hour: 8, minute: 0);
    String atuador = 'solenoide';
    int valor = 1;
    List<int> diasSelecionados = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Rotina Automática'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Horário: ${selectedTime?.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: selectedTime!);
                    if (picked != null) setDialogState(() => selectedTime = picked);
                  },
                ),
                DropdownButtonFormField<String>(
                  value: atuador,
                  decoration: const InputDecoration(labelText: 'Dispositivo'),
                  items: const [
                    DropdownMenuItem(value: 'solenoide', child: Text('Solenoide')),
                    DropdownMenuItem(value: 'moduloRele', child: Text('Bomba de Água')),
                  ],
                  onChanged: (v) => setDialogState(() => atuador = v!),
                ),
                DropdownButtonFormField<int>(
                  value: valor,
                  decoration: const InputDecoration(labelText: 'Ação'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Ligar')),
                    DropdownMenuItem(value: 0, child: Text('Desligar')),
                  ],
                  onChanged: (v) => setDialogState(() => valor = v!),
                ),
                const SizedBox(height: 16),
                const Text('Dias da Semana:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) {
                    final dias = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                    final isSel = diasSelecionados.contains(i);
                    return FilterChip(
                      label: Text(dias[i], style: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 10)),
                      selected: isSel,
                      selectedColor: _primaryGreen,
                      onSelected: (v) {
                        setDialogState(() {
                          v ? diasSelecionados.add(i) : diasSelecionados.remove(i);
                        });
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (diasSelecionados.isEmpty) return;
                Navigator.pop(context);
                await _salvarAgendamento(selectedTime!, atuador, valor, diasSelecionados);
              },
              child: const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarAgendamento(TimeOfDay time, String atuador, int valor, List<int> dias) async {
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final String horaStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('http://$host:8000/agendamentos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fk_id_irrigacao': widget.plantacao['id'],
          'atuador': atuador,
          'valor': valor,
          'horario': horaStr,
          'dias_semana': dias.join(','),
        }),
      );

      if (response.statusCode == 200) {
        _carregarAgendamentos();
      }
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.plantacao['descricao']),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSensorRow(),
            const SizedBox(height: 32),
            const Text('Rotinas de Automação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _agendamentos.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _agendamentos.length,
                    itemBuilder: (context, i) => _buildAgendamentoCard(_agendamentos[i]),
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarAgendamento,
        backgroundColor: _primaryGreen,
        label: const Text('Nova Rotina', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.alarm_add, color: Colors.white),
      ),
    );
  }

  Widget _buildSensorRow() {
    return Row(
      children: [
        Expanded(child: _buildMiniCard('Temperatura', '${_dadosAtuais['temperatura'] ?? '--'}°C', Icons.thermostat, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildMiniCard('Umid. Solo', '${_dadosAtuais['umiSolo'] ?? '--'}%', Icons.water_drop, Colors.blue)),
      ],
    );
  }

  Widget _buildMiniCard(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_note, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text('Nenhuma rotina agendada.', style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildAgendamentoCard(dynamic agenda) {
    final dias = agenda['dias_semana'].toString().split(',');
    final diasNomes = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final formatados = dias.map((d) => diasNomes[int.parse(d)]).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          agenda['atuador'] == 'solenoide' ? Icons.waves : Icons.power,
          color: agenda['valor'] == 1 ? Colors.green : Colors.red,
        ),
        title: Text('${agenda['horario']} - ${agenda['valor'] == 1 ? 'LIGAR' : 'DESLIGAR'}'),
        subtitle: Text(formatados),
        trailing: IconButton(
          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
          onPressed: () async {
            final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
            await http.delete(Uri.parse('http://$host:8000/agendamentos/${agenda['id']}'));
            _carregarAgendamentos();
          },
        ),
      ),
    );
  }
}
