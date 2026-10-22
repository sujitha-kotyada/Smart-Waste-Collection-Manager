import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/main.dart';
import 'package:smart_waste_collection_manager/models/app_user.dart';
import 'package:smart_waste_collection_manager/models/waste_report.dart';
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

    testWidgets(
      'Admin navigating to All Reports tab sees reports submitted by other users',
      (WidgetTester tester) async {
        final adminUser = AppUser(
          uid: 'admin-unique-uid-999',
          email: 'admin.super@ecocollect.org',
          displayName: 'Municipal Admin Super',
          role: AppConstants.roleAdmin,
          createdAt: DateTime.now(),
        );

        final citizenReport = WasteReport(
          id: 'CITIZEN-777',
          reporterId: 'citizen-resident-42',
          reporterName: 'Sunita Citizen',
          wasteCategory: 'Plastic Waste',
          location: 'Gandhi Road Corner Sector 12',
          description: 'Large pile of plastic bottles and packaging',
          priority: 'High',
          status: AppConstants.statusPending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repository.createReport(citizenReport);

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

        // Tap on "All Reports" navigation destination in the Admin bar
        final allReportsTab = find.text('All Reports');
        expect(allReportsTab, findsOneWidget);
        await tester.tap(allReportsTab);
        await tester.pumpAndSettle();

        // Confirm that the report submitted by citizen-resident-42 is displayed
        expect(find.text('Gandhi Road Corner Sector 12'), findsOneWidget);
        expect(find.text('ID: #CITIZEN-777'), findsOneWidget);
        expect(find.text('No matching reports'), findsNothing);
        expect(find.text('0 reports found'), findsNothing);
      },
    );

    testWidgets(
      'Resident navigating to My Reports tab sees only their own reports',
      (WidgetTester tester) async {
        final residentUser = AppUser(
          uid: 'resident-self-uid',
          email: 'resident.self@ecocollect.org',
          displayName: 'Self Resident',
          role: AppConstants.roleResident,
          createdAt: DateTime.now(),
        );

        final selfReport = WasteReport(
          id: 'SELF-101',
          reporterId: 'resident-self-uid',
          reporterName: 'Self Resident',
          wasteCategory: 'Plastic Waste',
          location: '101 Rose Lane Front Gate',
          description: 'Recyclable milk pouches',
          priority: 'Medium',
          status: AppConstants.statusPending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final otherReport = WasteReport(
          id: 'OTHER-202',
          reporterId: 'other-resident-99',
          reporterName: 'Other Resident',
          wasteCategory: 'E-Waste',
          location: '99 Boulevard Plaza Secret',
          description: 'Broken printer and cables',
          priority: 'Low',
          status: AppConstants.statusPending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createReport(selfReport);
        await repository.createReport(otherReport);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MainNavigationShell(
                user: residentUser,
                authService: authService,
                repository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on "Reports" navigation destination in the Resident bar
        final reportsTab = find.text('Reports');
        expect(reportsTab, findsOneWidget);
        await tester.tap(reportsTab);
        await tester.pumpAndSettle();

        // Resident sees their own report, but NOT the other resident's report
        expect(find.text('101 Rose Lane Front Gate'), findsOneWidget);
        expect(find.text('99 Boulevard Plaza Secret'), findsNothing);
      },
    );
  });
}
