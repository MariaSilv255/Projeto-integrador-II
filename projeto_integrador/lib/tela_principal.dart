import 'package:flutter/material.dart';
import 'package:projeto_integrador/dashBoard.dart';
import 'package:projeto_integrador/tela_implantacao.dart';

class TelaPrincipal extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const TelaPrincipal({super.key, required this.usuario});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAtual = 0;

  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();
    _telas = [
      const DashBoard(),
      const Center(child: Text('Gerenciamento de Plantação')),
      const Center(child: Text('Configurações do Sistema')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projeto Integrador - Tela Principal')),
      body: _telas[_indiceAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.eco), label: 'Plantação'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
        onTap: (int indiceClicado) {
          setState((){
            _indiceAtual = indiceClicado;
          });
        },
      ),
    );
  }
}