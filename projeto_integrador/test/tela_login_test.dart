import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_integrador/tela_login.dart';

void main() {
  testWidgets('Deve mostrar erro se os campos de email e senha estiverem vazios', (WidgetTester tester) async {
    // Carrega o widget TelaLogin
    await tester.pumpWidget(const MaterialApp(home: TelaLogin()));

    // Tenta clicar no botão "Acessar" sem preencher nada
    await tester.tap(find.text('Acessar'));
    await tester.pump(); // Reconstrói o widget após o clique

    // Verifica se as mensagens de erro de validação aparecem
    expect(find.text('Informe seu email'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
  });

  testWidgets('Deve permitir digitar no campo de email e senha', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaLogin()));

    // Digita o email
    await tester.enterText(find.byType(TextFormField).first, 'teste@exemplo.com');
    // Digita a senha
    await tester.enterText(find.byType(TextFormField).last, 'senha123');

    await tester.pump();

    // Verifica se o texto foi inserido corretamente
    expect(find.text('teste@exemplo.com'), findsOneWidget);
    expect(find.text('senha123'), findsOneWidget);
  });

  testWidgets('Deve mostrar botão de limpar quando houver texto no campo', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaLogin()));

    // Inicialmente não deve ter botão de limpar (ícone close)
    expect(find.byIcon(Icons.close), findsNothing);

    // Digita no email
    await tester.enterText(find.byType(TextFormField).first, 'teste');
    await tester.pump();

    // Agora deve aparecer o ícone de limpar
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Clica no botão de limpar
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // O campo deve estar vazio novamente
    expect(find.text('teste'), findsNothing);
  });
}