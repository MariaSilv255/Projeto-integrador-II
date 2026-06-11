import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:projeto_integrador/tela_cadastro_empresa.dart';
import 'package:projeto_integrador/tela_cadastro_funcionario.dart';

class TelaImplantacao extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const TelaImplantacao({super.key, required this.usuario});

  @override
  State<TelaImplantacao> createState() => _TelaImplantacaoState();
}

class _TelaImplantacaoState extends State<TelaImplantacao> {
  static const Color _primaryGreen = Color(0xFF2F6B4F);

  final TextEditingController _buscaController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _empresas = [];

  @override
  void initState() {
    super.initState();
    _buscaController.addListener(_onBuscaChanged);
    _carregarEmpresas();
  }

  @override
  void dispose() {
    _buscaController.removeListener(_onBuscaChanged);
    _buscaController.dispose();
    super.dispose();
  }

  void _onBuscaChanged() {
    setState(() {});
  }

  Future<void> _carregarEmpresas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/empresas'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> lista = data['empresas'] as List<dynamic>? ?? [];
        setState(() {
          _empresas = lista
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao carregar empresas.')),
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

  List<Map<String, dynamic>> get _empresasFiltradas {
    final termo = _buscaController.text.trim().toLowerCase();
    if (termo.isEmpty) return _empresas;
    return _empresas
        .where((e) => (e['Nome']?.toString().toLowerCase() ?? '').contains(termo))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Implantação'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Empresas cadastradas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _buscaController,
                        decoration: InputDecoration(
                          hintText: 'Buscar empresa',
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          suffixIcon: _buscaController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar',
                                  onPressed: () => _buscaController.clear(),
                                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            final criado = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TelaCadastroEmpresa(usuario: widget.usuario),
                              ),
                            );
                            if (criado == true) {
                              _carregarEmpresas();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _empresasFiltradas.isEmpty
                          ? const Center(child: Text('Nenhuma empresa cadastrada.'))
                          : ListView.separated(
                              itemCount: _empresasFiltradas.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final empresa = _empresasFiltradas[index];
                                final bool bloqueada = (empresa['Bloqueio'] ?? 0) == 1;
                                return Opacity(
                                  opacity: bloqueada ? 0.4 : 1.0,
                                  child: Card(
                                    child: ListTile(
                                      title: Text(empresa['Nome']?.toString() ?? ''),
                                      subtitle: Text(
                                        'Plantações: ${empresa['QuantidadePlantacoes']} • Licenças: ${empresa['QuantidadeLicencas']}',
                                      ),
                                      onTap: () {
                                        // Aqui você pode navegar para uma tela de edição detalhada da empresa
                                        // e reutilizar a tela de funcionários se desejar.
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TelaCadastroFuncionario(
                                              empresa: empresa,
                                              criadorHash: widget.usuario['Matricula']?.toString() ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                      trailing: IconButton(
                                        icon: Icon(
                                          bloqueada ? Icons.lock : Icons.lock_outline,
                                          color: bloqueada ? Colors.redAccent : null,
                                        ),
                                        tooltip: bloqueada ? 'Ativar empresa' : 'Inativar empresa',
                                        onPressed: () async {
                                          final bool? confirmar = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(bloqueada ? 'Ativar empresa' : 'Inativar empresa'),
                                              content: Text(
                                                bloqueada
                                                    ? 'Deseja ativar a empresa "${empresa['Nome']}"?'
                                                    : 'Deseja inativar a empresa "${empresa['Nome']}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text(bloqueada ? 'Ativar' : 'Inativar'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmar == true) {
                                            try {
                                              final uri = bloqueada
                                                  ? Uri.parse('http://10.0.2.2:8000/empresas/desbloquear')
                                                  : Uri.parse('http://10.0.2.2:8000/empresas/bloquear');

                                              final response = await http.post(
                                                uri,
                                                headers: {'Content-Type': 'application/json'},
                                                body: jsonEncode({
                                                  'empresaId': empresa['EmpresaId'],
                                                }),
                                              );

                                              if (response.statusCode == 200) {
                                                _carregarEmpresas();
                                              } else {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      bloqueada
                                                          ? 'Falha ao ativar empresa.'
                                                          : 'Falha ao inativar empresa.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (_) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Erro ao conectar ao servidor.')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
