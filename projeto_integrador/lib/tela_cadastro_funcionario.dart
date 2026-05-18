import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TelaCadastroFuncionario extends StatefulWidget {
  final Map<String, dynamic> empresa;
  final String criadorHash;

  const TelaCadastroFuncionario({
    super.key,
    required this.empresa,
    required this.criadorHash,
  });

  @override
  State<TelaCadastroFuncionario> createState() => _TelaCadastroFuncionarioState();
}

class _TelaCadastroFuncionarioState extends State<TelaCadastroFuncionario> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _isLoading = false;

  // Controle de lista de usuários / licenças
  bool _carregandoLista = false;
  List<Map<String, dynamic>> _usuarios = [];
  late final int _maxLicencas;

  bool get _atingiuLimite =>
      _maxLicencas > 0 && _usuarios.length >= _maxLicencas;

  static const Color _primaryGreen = Color(0xFF2F6B4F);

  @override
  void initState() {
    super.initState();
    _maxLicencas = int.tryParse(
          widget.empresa['QuantidadeLicencas']?.toString() ??
              widget.empresa['quantidadeLicencas']?.toString() ??
              '0',
        ) ??
        0;
    _carregarUsuarios();
  }
 
  Future<void> _carregarUsuarios() async {
    setState(() {
      _carregandoLista = true;
    });
 
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/usuarios-empresa?empresa=${Uri.encodeQueryComponent(widget.empresa['EmpresaId']?.toString() ?? '')}'),
        headers: {'Content-Type': 'application/json'},
      );
 
      if (!mounted) return;
 
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> lista = data['usuarios'] as List<dynamic>? ?? [];
        setState(() {
          _usuarios = lista.map((e) => e as Map<String, dynamic>).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao carregar usuários da empresa.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao conectar ao servidor.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _carregandoLista = false;
        });
      }
    }
  }
 
  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _salvarFuncionario() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, corrija os erros no formulário.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/usuarios-empresa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': _nomeController.text.trim(),
          'email': _emailController.text.trim(),
          'senha': _senhaController.text,
          'cargo': 'admin',
          'hashCriador': widget.criadorHash,
          'empresa': widget.empresa['EmpresaId']?.toString() ?? '',
          'tipo': 2,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionário cadastrado com sucesso!')),
        );
        _nomeController.clear();
        _emailController.clear();
        _senhaController.clear();
        await _carregarUsuarios();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao cadastrar funcionário.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao conectar ao servidor.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    );

    InputDecoration decorationFor(String hint) {
      return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Funcionário'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nomeController,
                      decoration: decorationFor('Nome do funcionário'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o nome do funcionário';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: decorationFor('Email'),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) {
                          return 'Informe o email';
                        }
                        if (!email.contains('@')) {
                          return 'Email inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: decorationFor('Senha'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe a senha';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter no mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: 'admin',
                      enabled: false,
                      decoration: decorationFor('Cargo'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _maxLicencas > 0
                          ? 'Licenças usadas: ${_usuarios.length} de $_maxLicencas'
                          : 'Licenças ilimitadas para esta empresa',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _atingiuLimite) ? null : _salvarFuncionario,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _atingiuLimite ? 'Limite de licenças atingido' : 'Salvar funcionário',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_carregandoLista)
                      const Center(child: CircularProgressIndicator())
                    else if (_usuarios.isEmpty)
                      const Text('Nenhum funcionário cadastrado ainda.')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Funcionários cadastrados:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ..._usuarios.map((u) => Card(
                                child: ListTile(
                                  title: Text(u['Nome']?.toString() ?? ''),
                                  subtitle: Text(u['Email']?.toString() ?? ''),
                                ),
                              )),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
