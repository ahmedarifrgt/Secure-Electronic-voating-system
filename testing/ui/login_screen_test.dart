import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voting_app/screens/screens/login/login_screen.dart';

void main() {
  testWidgets('Login screen has NID field', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('National ID'), findsOneWidget);
  });
}
