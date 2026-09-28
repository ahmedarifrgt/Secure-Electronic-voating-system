import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:voting_app/core/api_client.dart';
import 'package:voting_app/providers/auth_provider.dart';
import 'package:voting_app/screens/login/login_screen.dart';

void main() {
  testWidgets('Login screen has NID field', (WidgetTester tester) async {
    final api = ApiClient();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('National ID'), findsOneWidget);
  });

  testWidgets('Login screen has admin toggle', (WidgetTester tester) async {
    final api = ApiClient();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Voter'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('Login screen has about authors action', (WidgetTester tester) async {
    final api = ApiClient();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About Authors'), findsOneWidget);
  });
}

