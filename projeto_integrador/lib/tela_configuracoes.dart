import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TelaConfiguracoes extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const TelaConfiguracoes({super.key, required this.usuario});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  static const Color _primaryGreen = Color(0xFF2F6B4F);
  bool _isLoading = true;
  List<dynamic> _brokers = [];

  @override
  void initState() {
    super.initState();
    _carregarBrokers();
  }

  Future<void> _carregarBrokers() async {
    setState(() => _isLoading = true);
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final userId = widget.usuario['id'];
      final response = await http.get(Uri.parse('http://$host:8000/brokers/usuario/$userId'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _brokers = jsonDecode(response.body);
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

  Future<void> _adicionarBroker() async {
    final TextEditingController hostController = TextEditingController();
    final TextEditingController userController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Broker MQTT'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: hostController, decoration: const InputDecoration(labelText: 'Host (ex: broker.hivemq.com)')),
              TextField(controller: userController, decoration: const InputDecoration(labelText: 'Username')),
              TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _salvarBroker(hostController.text, userController.text, passwordController.text);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarBroker(String host, String user, String password) async {
    if (host.isEmpty) return;
    try {
      final String apiHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$apiHost:8000/brokers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'host': host,
          'username': user,
          'chave_usuario': password,
          'login': user, 
          'certificado_cliente': 'default',
          'fk_id_usuario': widget.usuario['id'],
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarBrokers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broker adicionado e conectado!')));
        }
      }
    } catch (e) {
      debugPrint('Erro ao salvar: $e');
    }
  }

  Future<void> _conectarBroker(int brokerId) async {
    try {
      final String apiHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(Uri.parse('http://$apiHost:8000/brokers/conectar/$brokerId'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.statusCode == 200 ? 'Conectado com sucesso!' : 'Falha na conexão.'))
        );
      }
    } catch (e) {
      debugPrint('Erro ao conectar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : _brokers.isEmpty
              ? const Center(child: Text('Nenhum broker configurado.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _brokers.length,
                  itemBuilder: (context, index) {
                    final item = _brokers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      elevation: 0,
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.settings_input_component, color: _primaryGreen)),
                        title: Text(item['host'] ?? 'Sem host', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Usuário: ${item['username']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.sync, color: Colors.blueAccent),
                              onPressed: () => _conectarBroker(item['id']),
                              tooltip: 'Conectar agora',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final String apiHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
                                await http.delete(Uri.parse('http://$apiHost:8000/brokers/${item['id']}'));
                                _carregarBrokers();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarBroker,
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo Broker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
