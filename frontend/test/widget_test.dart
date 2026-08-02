import 'package:flutter_test/flutter_test.dart';

import 'package:voting_app/main.dart';
import 'package:voting_app/core/api_client.dart';

void main() {
  testWidgets('App builds and shows splash screen', (WidgetTester tester) async {
    final api = ApiClient();
    await tester.pumpWidget(VotingApp(api: api));
    await tester.pump();

    // Splash screen branding should be visible immediately.
    expect(find.text('SECURE ELECTRONIC VOTING'), findsOneWidget);
  });
}

