import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/tela_cadastro_funcionario.dart';

class TelaCadastroEmpresa extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const TelaCadastroEmpresa({super.key, required this.usuario});

  @override
  State<TelaCadastroEmpresa> createState() => _TelaCadastroEmpresaState();
}

class _TelaCadastroEmpresaState extends State<TelaCadastroEmpresa> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _qtdPlantacoesController = TextEditingController();
  final _qtdLicencasController = TextEditingController();

  bool _isLoading = false;

  static const Color _primaryGreen = Color(0xFF2F6B4F);

  @override
  void dispose() {
    _nomeController.dispose();
    _qtdPlantacoesController.dispose();
    _qtdLicencasController.dispose();
    super.dispose();
  }

  Future<void> _salvarEmpresa() async {
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
        Uri.parse('http://10.0.2.2:8000/empresas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': _nomeController.text.trim(),
          'quantidadePlantacoes': int.tryParse(_qtdPlantacoesController.text) ?? 0,
          'quantidadeLicencas': int.tryParse(_qtdLicencasController.text) ?? 0,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final empresa = data['empresa'] as Map<String, dynamic>;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa cadastrada com sucesso!')),
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaCadastroFuncionario(
              empresa: empresa,
              criadorHash: widget.usuario['Matricula']?.toString() ?? '',
            ),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao cadastrar empresa.')),
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
        title: const Text('Cadastro de Empresa'),
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
                      decoration: decorationFor('Nome da empresa'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o nome da empresa';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _qtdPlantacoesController,
                      keyboardType: TextInputType.number,
                      decoration: decorationFor('Quantidade de plantações'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe a quantidade de plantações';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Informe um número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _qtdLicencasController,
                      keyboardType: TextInputType.number,
                      decoration: decorationFor('Quantidade de licenças'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe a quantidade de licenças';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Informe um número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _salvarEmpresa,
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
                            : const Text(
                                'Salvar',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
}
