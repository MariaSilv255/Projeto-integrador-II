import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_integrador/tela_cadastro.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'tela_cadastro_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('TelaCadastro', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    testWidgets('Deve exibir todos os campos de texto e o botão de cadastro', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      expect(find.text('Nome completo'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Senha'), findsNWidgets(2)); // Senha e Confirmar senha
      expect(find.text('Confirmar senha'), findsOneWidget);
      expect(find.text('Cadastrar'), findsOneWidget);
      expect(find.text('Já tem conta?'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('Deve mostrar erros de validação quando os campos estão vazios', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      expect(find.text('Informe seu nome completo'), findsOneWidget);
      expect(find.text('Informe seu email'), findsOneWidget);
      expect(find.text('Informe sua senha'), findsNWidgets(2));
      expect(find.text('Confirme sua senha'), findsOneWidget);
      expect(find.text('Por favor, corrija os erros no formulário.'), findsOneWidget);
    });

    testWidgets('Deve mostrar erro de email inválido', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Email'), 'emailinvalido');
      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      expect(find.text('Email inválido'), findsOneWidget);
    });

    testWidgets('Deve mostrar erro de senha muito curta', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Senha').first, '123');
      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      expect(find.text('A senha deve ter no mínimo 6 caracteres'), findsOneWidget);
    });

    testWidgets('Deve mostrar erro se as senhas não coincidirem', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Senha').first, 'senha123');
      await tester.enterText(find.text('Confirmar senha'), 'senha456');
      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      expect(find.text('As senhas não coincidem'), findsOneWidget);
    });

    testWidgets('Deve navegar de volta ao clicar em Entrar', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (BuildContext context) {
        return ElevatedButton(onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastro()));
        }, child: const Text('Go to Cadastro'));
      })));

      await tester.tap(find.text('Go to Cadastro'));
      await tester.pumpAndSettle();

      expect(find.byType(TelaCadastro), findsOneWidget);

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.byType(TelaCadastro), findsNothing);
      expect(find.text('Go to Cadastro'), findsOneWidget);
    });

    testWidgets('Deve exibir CircularProgressIndicator durante o cadastro', (WidgetTester tester) async {
      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => http.Response('{"message": "User registered successfully"}', 201));

      await tester.pumpWidget(MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Nome completo'), 'Teste Usuário');
      await tester.enterText(find.text('Email'), 'teste@example.com');
      await tester.enterText(find.text('Senha').first, 'senha123');
      await tester.enterText(find.text('Confirmar senha'), 'senha123');

      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Espera a requisição HTTP mockada ser concluída
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cadastro realizado com sucesso!'), findsOneWidget);
    });

    testWidgets('Deve mostrar snackbar de sucesso e voltar para a tela anterior em caso de sucesso', (WidgetTester tester) async {
      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => http.Response('{"message": "User registered successfully"}', 201));

      await tester.pumpWidget(MaterialApp(home: Builder(builder: (BuildContext context) {
        return ElevatedButton(onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastro()));
        }, child: const Text('Go to Cadastro'));
      })));

      await tester.tap(find.text('Go to Cadastro'));
      await tester.pumpAndSettle();

      await tester.enterText(find.text('Nome completo'), 'Teste Usuário');
      await tester.enterText(find.text('Email'), 'teste@example.com');
      await tester.enterText(find.text('Senha').first, 'senha123');
      await tester.enterText(find.text('Confirmar senha'), 'senha123');

      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      await tester.pumpAndSettle();

      expect(find.text('Cadastro realizado com sucesso!'), findsOneWidget);
      expect(find.byType(TelaCadastro), findsNothing);
      expect(find.text('Go to Cadastro'), findsOneWidget);
    });

    testWidgets('Deve mostrar snackbar de email já cadastrado (status 409)', (WidgetTester tester) async {
      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => http.Response('{"message": "Email already registered"}', 409));

      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Nome completo'), 'Teste Usuário');
      await tester.enterText(find.text('Email'), 'existente@example.com');
      await tester.enterText(find.text('Senha').first, 'senha123');
      await tester.enterText(find.text('Confirmar senha'), 'senha123');

      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      await tester.pumpAndSettle();

      expect(find.text('Email já cadastrado.'), findsOneWidget);
    });

    testWidgets('Deve mostrar snackbar de falha ao realizar cadastro (outros status de erro)', (WidgetTester tester) async {
      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenAnswer((_) async => http.Response('{"message": "Internal server error"}', 500));

      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Nome completo'), 'Teste Usuário');
      await tester.enterText(find.text('Email'), 'erro@example.com');
      await tester.enterText(find.text('Senha').first, 'senha123');
      await tester.enterText(find.text('Confirmar senha'), 'senha123');

      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      await tester.pumpAndSettle();

      expect(find.text('Falha ao realizar cadastro.'), findsOneWidget);
    });

    testWidgets('Deve mostrar snackbar de erro ao conectar ao servidor (exceção)', (WidgetTester tester) async {
      when(mockClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
          .thenThrow(Exception('Failed to connect'));

      await tester.pumpWidget(const MaterialApp(home: TelaCadastro()));

      await tester.enterText(find.text('Nome completo'), 'Teste Usuário');
      await tester.enterText(find.text('Email'), 'conexao@example.com');
      await tester.enterText(find.text('Senha').first, 'senha123');
      await tester.enterText(find.text('Confirmar senha'), 'senha123');

      await tester.tap(find.text('Cadastrar'));
      await tester.pump();

      await tester.pumpAndSettle();

      expect(find.text('Erro ao conectar ao servidor.'), findsOneWidget);
    });
  });
}
