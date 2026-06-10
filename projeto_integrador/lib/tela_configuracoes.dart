import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key});

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
      final response = await http.get(Uri.parse('http://$host:8000/brokers'));

      if (response.statusCode == 200) {
        setState(() {
          _brokers = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Erro ao carregar brokers: $e');
      setState(() => _isLoading = false);
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
              TextField(controller: hostController, decoration: const InputDecoration(hintText: 'Host (ex: broker.hivemq.com)')),
              TextField(controller: userController, decoration: const InputDecoration(hintText: 'Username')),
              TextField(controller: passwordController, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
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
          'login': user, // Using user as login for now
          'certificado_cliente': 'default',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarBrokers();
      }
    } catch (e) {
      debugPrint('Erro ao salvar broker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _brokers.isEmpty
              ? const Center(child: Text('Nenhum broker configurado.'))
              : ListView.builder(
                  itemCount: _brokers.length,
                  itemBuilder: (context, index) {
                    final item = _brokers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.settings_input_component, color: _primaryGreen),
                        title: Text(item['host'] ?? 'Sem host'),
                        subtitle: Text('Usuário: ${item['username']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final String apiHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
                            await http.delete(Uri.parse('http://$apiHost:8000/brokers/${item['id']}'));
                            _carregarBrokers();
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarBroker,
        backgroundColor: _primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
