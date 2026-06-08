import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/tela_principal.dart';
import 'package:projeto_integrador/tela_recuperar_senha.dart';
import 'package:projeto_integrador/tela_implantacao.dart';

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
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    );

    return Scaffold(
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
                    const Text(
                      'Bem-vindo(a)!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Faça login para gerenciar a\n sua irrigação',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nomeUsuarioController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Nome de usuário',
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
                        suffixIcon: _nomeUsuarioController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar',
                                onPressed: () => _nomeUsuarioController.clear(),
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                              ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe seu nome de usuário';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Senha',
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
                        suffixIcon: _senhaController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar',
                                onPressed: () => _senhaController.clear(),
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                              ),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe sua senha';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TelaRecuperarSenha(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Esqueceu a senha?'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  _login();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Preencha nome de usuário e senha.')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          disabledBackgroundColor: _primaryGreen.withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Acessar',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
    setState(() {
      _isLoading = true;
    });
    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome_usuario': _nomeUsuarioController.text.trim(),
          'senha': _senhaController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tudo certo! Entrando...')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TelaPrincipal()),
        );
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login falhou! Verifique suas credenciais.')),
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
}
