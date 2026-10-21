import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/main.dart';
import 'package:smart_waste_collection_manager/models/app_user.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';
import 'package:smart_waste_collection_manager/services/auth_service.dart';

void main() {
  group('Role-Based UI Workflows & Navigation Tests', () {
    late AuthService authService;
    late LocalWasteReportRepository repository;

    setUp(() {
      authService = AuthService()..enterDemoMode(AppConstants.roleResident);
      repository = LocalWasteReportRepository();
    });

    testWidgets('Resident can open report waste dialog and submit', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      // Verify dashboard presence
      expect(find.text('EcoCollect'), findsOneWidget);
      expect(find.text('Hello, Eco Champion!'), findsOneWidget);

      // Tap FloatingActionButton "Report Waste"
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Verify Dialog opens
      expect(find.text('Report Waste Incident'), findsOneWidget);
      expect(find.text('Waste Category *'), findsOneWidget);
      expect(find.text('Collection Location *'), findsOneWidget);

      // Enter location and submit
      final locationField = find.byType(TextFormField).first;
      await tester.enterText(locationField, 'Market Street Sector 9');
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Report');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Dialog should close and return to dashboard
      expect(find.text('Report Waste Incident'), findsNothing);
    });

    testWidgets('Worker dashboard displays assigned tasks', (
      WidgetTester tester,
    ) async {
      final workerUser = AppUser(
        uid: 'demo-worker-1',
        email: 'worker@ecocollect.org',
        displayName: 'Rajesh Worker',
        role: AppConstants.roleWorker,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainNavigationShell(
              user: workerUser,
              authService: authService,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify worker role header and tasks tab
      expect(find.text('WORKER'), findsOneWidget);
      expect(
        find.text('Municipal Field Sanitation Worker • Active Duty'),
        findsOneWidget,
      );
      expect(find.textContaining('Assigned Route'), findsOneWidget);
      expect(find.textContaining('Completed Work'), findsOneWidget);
    });

    testWidgets('Admin dashboard displays municipal control center and KPIs', (
      WidgetTester tester,
    ) async {
      final adminUser = AppUser(
        uid: 'demo-admin-1',
        email: 'admin@ecocollect.org',
        displayName: 'Operations Supervisor',
        role: AppConstants.roleAdmin,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainNavigationShell(
              user: adminUser,
              authService: authService,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify admin console header and metrics
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Municipal Control Center'), findsOneWidget);
      expect(find.text('Municipal Queue'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });
}
