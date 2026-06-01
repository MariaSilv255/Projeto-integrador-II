import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_integrador/tela_recuperar_senha.dart';

void main() {
  group('TelaRecuperarSenha', () {
    testWidgets('Deve exibir o campo de email e o botão de enviar link', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaRecuperarSenha()));

      expect(find.text('Esqueceu a senha?'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Enviar link'), findsOneWidget);
      expect(find.text('Voltar para o Login'), findsOneWidget);
    });

    testWidgets('Deve mostrar erro se o campo de email estiver vazio ao tentar enviar', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaRecuperarSenha()));

      await tester.tap(find.text('Enviar link'));
      await tester.pump();

      expect(find.text('Informe seu email'), findsOneWidget);
      expect(find.text('Informe um email válido.'), findsOneWidget);
    });

    testWidgets('Deve mostrar erro se o email for inválido ao tentar enviar', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaRecuperarSenha()));

      await tester.enterText(find.byType(TextFormField), 'emailinvalido');
      await tester.tap(find.text('Enviar link'));
      await tester.pump();

      expect(find.text('Email inválido'), findsOneWidget);
      expect(find.text('Informe um email válido.'), findsOneWidget);
    });

    testWidgets('Deve exibir o indicador de carregamento ao enviar e mostrar snackbar de sucesso', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaRecuperarSenha()));

      await tester.enterText(find.byType(TextFormField), 'teste@exemplo.com');
      await tester.tap(find.text('Enviar link'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 800)); // Espera a simulação de atraso

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Se o email existir, enviaremos um link de recuperação.'), findsOneWidget);
    });

    testWidgets('Deve permitir limpar o campo de email', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaRecuperarSenha()));

      await tester.enterText(find.byType(TextFormField), 'teste@exemplo.com');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('teste@exemplo.com'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('Deve voltar para a tela anterior ao clicar em Voltar para o Login', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (BuildContext context) {
        return ElevatedButton(onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaRecuperarSenha()));
        }, child: const Text('Go to Recovery'));
      })));

      await tester.tap(find.text('Go to Recovery'));
      await tester.pumpAndSettle();

      expect(find.byType(TelaRecuperarSenha), findsOneWidget);

      await tester.tap(find.text('Voltar para o Login'));
      await tester.pumpAndSettle();

      expect(find.byType(TelaRecuperarSenha), findsNothing);
      expect(find.text('Go to Recovery'), findsOneWidget);
    });
  });
}
