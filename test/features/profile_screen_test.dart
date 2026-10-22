import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/features/profile/profile_screen.dart';
import 'package:smart_waste_collection_manager/models/app_user.dart';
import 'package:smart_waste_collection_manager/models/waste_report.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';
import 'package:smart_waste_collection_manager/services/auth_service.dart';

/// Test repository that returns an empty reports list
class EmptyWasteReportRepository implements WasteReportRepository {
  @override
  bool get isUsingCloudFirestore => false;

  @override
  Stream<List<WasteReport>> streamAllReports() => Stream.value([]);

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) => Stream.value([]);

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) => Stream.value([]);

  @override
  Future<void> createReport(WasteReport report) async {}

  @override
  Future<void> updateReport(WasteReport report) async {}

  @override
  Future<void> deleteReport(String reportId) async {}

  @override
  Future<List<AppUser>> getAvailableWorkers() async => [];
}

/// Test repository that emits an error on report streams
class ErrorWasteReportRepository implements WasteReportRepository {
  @override
  bool get isUsingCloudFirestore => false;

  @override
  Stream<List<WasteReport>> streamAllReports() =>
      Stream.error(Exception('Simulated network connection failure'));

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) =>
      Stream.error(Exception('Simulated network connection failure'));

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) =>
      Stream.error(Exception('Simulated network connection failure'));

  @override
  Future<void> createReport(WasteReport report) async {}

  @override
  Future<void> updateReport(WasteReport report) async {}

  @override
  Future<void> deleteReport(String reportId) async {}

  @override
  Future<List<AppUser>> getAvailableWorkers() async => [];
}

/// Test repository that delays stream emission to test the loading state
class DelayedWasteReportRepository implements WasteReportRepository {
  final Completer<List<WasteReport>> completer = Completer<List<WasteReport>>();

  @override
  bool get isUsingCloudFirestore => false;

  @override
  Stream<List<WasteReport>> streamAllReports() => completer.future.asStream();

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) =>
      completer.future.asStream();

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) =>
      completer.future.asStream();

  @override
  Future<void> createReport(WasteReport report) async {}

  @override
  Future<void> updateReport(WasteReport report) async {}

  @override
  Future<void> deleteReport(String reportId) async {}

  @override
  Future<List<AppUser>> getAvailableWorkers() async => [];
}

void main() {
  group('ProfileScreen Role-Based UI & Personal Info Tests', () {
    late AuthService authService;
    late LocalWasteReportRepository repository;

    setUp(() {
      authService = AuthService()..enterDemoMode(AppConstants.roleResident);
      repository = LocalWasteReportRepository();
    });

    testWidgets('Resident profile displays unconfigured zone and personal metrics', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final residentUser = AppUser(
        uid: 'demo-resident-1',
        email: 'sujitha.resident@ecocollect.org',
        displayName: 'Sujitha Kotyada',
        role: AppConstants.roleResident,
        createdAt: DateTime(2026, 1, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: residentUser,
              authService: authService,
              repository: repository,
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify personal details
      expect(find.text('Sujitha Kotyada'), findsNWidgets(2));
      expect(find.text('sujitha.resident@ecocollect.org'), findsNWidgets(2));
      expect(find.text('Community Resident'), findsNWidgets(2));
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Activity Overview'), findsOneWidget);
      expect(find.text('Recent Incident Reports'), findsOneWidget);

      // Verify unconfigured service zone (NOT hardcoded ward)
      expect(find.text('Service Zone'), findsOneWidget);
      expect(find.text('Not configured'), findsOneWidget);
      expect(find.text('Ward 4 • Central Community Zone'), findsNothing);

      // Verify infrastructure card is removed
      expect(find.text('System Infrastructure'), findsNothing);
      expect(find.text('Firebase Project'), findsNothing);
      expect(find.text('Persistence Engine'), findsNothing);
      expect(find.text('Security Enforcement'), findsNothing);
    });

    testWidgets('Worker profile displays generated crew ID and unspecified fleet', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final workerUser = AppUser(
        uid: 'demo-worker-1',
        email: 'rajesh.worker@ecocollect.org',
        displayName: 'Rajesh Kumar',
        role: AppConstants.roleWorker,
        createdAt: DateTime(2026, 2, 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: workerUser,
              authService: authService,
              repository: repository,
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify worker details
      expect(find.text('Rajesh Kumar'), findsNWidgets(2));
      expect(find.text('Municipal Field Crew'), findsNWidgets(2));
      expect(find.text('Field Crew Identifier (Generated)'), findsOneWidget);
      expect(find.text('CREW-DEMO-WOR'), findsOneWidget);
      expect(find.text('Assigned Fleet / Unit'), findsOneWidget);
      expect(find.text('Not specified'), findsOneWidget);
      expect(find.text('Municipal Waste Fleet #04'), findsNothing);
      expect(find.text('Assigned Tasks'), findsOneWidget);
      expect(find.text('Completed Work'), findsOneWidget);
      expect(find.text('Recent Field Tasks'), findsOneWidget);
    });

    testWidgets('Admin profile displays administrator role and municipal activity', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final adminUser = AppUser(
        uid: 'demo-admin-1',
        email: 'admin.manager@ecocollect.org',
        displayName: 'Sujitha Supervisor',
        role: AppConstants.roleAdmin,
        createdAt: DateTime(2025, 11, 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: adminUser,
              authService: authService,
              repository: repository,
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify admin details
      expect(find.text('Municipal Administrator'), findsNWidgets(2));
      expect(find.text('City Reports'), findsOneWidget);
      expect(find.text('Awaiting Dispatch'), findsOneWidget);
      expect(find.text('Field Operations'), findsOneWidget);
      expect(find.text('Recent Municipal Incidents'), findsOneWidget);
    });

    testWidgets('Displays genuine empty state when user has zero reports', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final residentUser = AppUser(
        uid: 'brand-new-user-99',
        email: 'newuser@ecocollect.org',
        displayName: 'New Citizen',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: residentUser,
              authService: authService,
              repository: EmptyWasteReportRepository(),
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state display
      expect(find.text('You have not submitted any waste reports yet.'), findsOneWidget);
      expect(find.text('0 Total Records'), findsOneWidget);
    });

    testWidgets('Displays loading state while stream snapshot is pending', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final delayedRepo = DelayedWasteReportRepository();
      final residentUser = AppUser(
        uid: 'user-1',
        email: 'user@test.com',
        displayName: 'Loading Test User',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: residentUser,
              authService: authService,
              repository: delayedRepo,
              onRoleSwitched: () {},
            ),
          ),
        ),
      );

      // Pump 1 frame without completing the future
      await tester.pump();

      // Verify loading state UI
      expect(find.text('Loading activity records...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up delayed completer
      delayedRepo.completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('Displays user-friendly error card and retry button on stream error', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final residentUser = AppUser(
        uid: 'user-error',
        email: 'user@test.com',
        displayName: 'Error Test User',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: residentUser,
              authService: authService,
              repository: ErrorWasteReportRepository(),
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify error card
      expect(find.text('Unable to load activity records'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
    });

    testWidgets('Can open Edit Full Name dialog and update displayName', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final residentUser = AppUser(
        uid: 'demo-resident-1',
        email: 'resident@ecocollect.org',
        displayName: 'Original Name',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: residentUser,
              authService: authService,
              repository: repository,
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Edit Name"
      final editButton = find.text('Edit Name');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.text('Edit Full Name'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Enter new name and save
      final textField = find.byType(TextFormField);
      await tester.enterText(textField, 'Updated Full Name');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify dialog closed and snackbar shown
      expect(find.text('Edit Full Name'), findsNothing);
      expect(find.text('Profile name updated successfully.'), findsOneWidget);
    });

    testWidgets('Name-update failure displays error feedback and never false success', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingAuth = FailingAuthService();
      final residentUser = AppUser(
        uid: 'user-fail-test',
        email: 'resident@ecocollect.org',
        displayName: 'Original Name',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              user: residentUser,
              authService: failingAuth,
              repository: repository,
              onRoleSwitched: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Edit dialog
      await tester.tap(find.text('Edit Name'));
      await tester.pumpAndSettle();

      // Enter new name and tap Save Changes
      await tester.enterText(find.byType(TextFormField), 'Name Attempt');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Must NOT display success message
      expect(find.text('Profile name updated successfully.'), findsNothing);

      // Must display honest error feedback
      expect(find.textContaining('Cloud Firestore write rejected'), findsOneWidget);
    });
  });
}

class FailingAuthService extends AuthService {
  @override
  Future<bool> updateDisplayName(String newDisplayName) async {
    return false;
  }

  @override
  String? get lastErrorMessage => 'Cloud Firestore write rejected: network offline';
}
