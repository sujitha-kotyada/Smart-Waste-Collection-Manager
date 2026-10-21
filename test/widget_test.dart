import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/main.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';
import 'package:smart_waste_collection_manager/services/auth_service.dart';

void main() {
  testWidgets(
    'Unauthenticated user sees Login screen and not resident dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      await tester.pumpWidget(SmartWasteApp(authService: authService));
      await tester.pumpAndSettle();

      // Verify unauthenticated user lands on Login Screen
      expect(find.text('Sign In'), findsWidgets);
      expect(
        find.text('Evaluator Fast-Access (Simulated Sandbox)'),
        findsOneWidget,
      );
      // Should NOT show resident dashboard without authentication
      expect(find.text('Your Waste Overview'), findsNothing);
    },
  );

  testWidgets('Smart Waste dashboard loads in simulated demo mode', (
    WidgetTester tester,
  ) async {
    final authService = AuthService()..enterDemoMode(AppConstants.roleResident);
    final repository = LocalWasteReportRepository();

    await tester.pumpWidget(
      SmartWasteApp(authService: authService, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('EcoCollect'), findsOneWidget);
    expect(find.text('Your Waste Overview'), findsOneWidget);
    expect(find.text('Hello, Eco Champion!'), findsOneWidget);
    expect(find.text('Report Waste'), findsOneWidget);
    expect(find.textContaining('SIMULATED DEMO SANDBOX'), findsOneWidget);
  });
}
