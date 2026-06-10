import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final _formKey = GlobalKey<FormState>();
  
  final _nomeUsuarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmSenhaController = TextEditingController();

  bool _isLoading = false;

  static const Color _primaryGreen = Color(0xFF2F6B4F);
  static const Color _backgroundGrey = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _nomeUsuarioController.addListener(_onTextChanged);
    _emailController.addListener(_onTextChanged);
    _senhaController.addListener(_onTextChanged);
    _confirmSenhaController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final response = await http.post(
        Uri.parse('http://$host:8000/registrar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome_usuario': _nomeUsuarioController.text.trim(),
          'email': _emailController.text.trim(),
          'senha': _senhaController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada com sucesso!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao cadastrar. Tente outro usuário.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nomeUsuarioController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmSenhaController.dispose();
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Color(0xFF1E293B)),
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
                    const Text(
                      'Criar Conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Junte-se a nós para monitorar sua produção',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 32),
                    _buildField('Usuário', _nomeUsuarioController, Icons.person_outline, inputBorder),
                    const SizedBox(height: 16),
                    _buildField('E-mail', _emailController, Icons.email_outlined, inputBorder, isEmail: true),
                    const SizedBox(height: 16),
                    _buildField('Senha', _senhaController, Icons.lock_outline, inputBorder, isPassword: true),
                    const SizedBox(height: 16),
                    _buildField('Confirmar Senha', _confirmSenhaController, Icons.lock_reset, inputBorder, isPassword: true, matchController: _senhaController),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _cadastrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Cadastrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildField(String label, TextEditingController controller, IconData icon, OutlineInputBorder border, {bool isPassword = false, bool isEmail = false, TextEditingController? matchController}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: _primaryGreen, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo obrigatório';
        if (isEmail && !value.contains('@')) return 'E-mail inválido';
        if (isPassword && value.length < 6) return 'Mínimo 6 caracteres';
        if (matchController != null && value != matchController.text) return 'As senhas não coincidem';
        return null;
      },
    );
  }
}
