import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/tela_principal.dart';
import 'package:projeto_integrador/tela_recuperar_senha.dart';
import 'package:projeto_integrador/tela_cadastro.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  
  final _nomeUsuarioController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;

  static const Color _primaryGreen = Color(0xFF2F6B4F);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _nomeUsuarioController.addListener(_onTextChanged);
    _senhaController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _nomeUsuarioController.removeListener(_onTextChanged);
    _senhaController.removeListener(_onTextChanged);
    _nomeUsuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    );

    return Scaffold(
      backgroundColor: _backgroundGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.eco, size: 60, color: _primaryGreen),
                    const SizedBox(height: 16),
                    const Text(
                      'Bem-vindo(a)!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Faça login para gerenciar a sua irrigação inteligente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nomeUsuarioController,
                      decoration: InputDecoration(
                        labelText: 'Nome de usuário',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(color: _primaryGreen, width: 2),
                        ),
                        errorBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Informe seu usuário' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(color: _primaryGreen, width: 2),
                        ),
                        errorBorder: inputBorder.copyWith(
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Informe sua senha' : null,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaRecuperarSenha())),
                        child: const Text('Esqueceu a senha?', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () { if (_formKey.currentState!.validate()) _login(); },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: _primaryGreen.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Acessar Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Novo por aqui?', style: TextStyle(color: Color(0xFF64748B))),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastro())),
                          child: const Text('Crie sua conta', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryGreen)),
                        ),
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

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nome_usuario': _nomeUsuarioController.text.trim(), 'senha': _senhaController.text}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaPrincipal(usuario: userData)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciais incorretas.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
