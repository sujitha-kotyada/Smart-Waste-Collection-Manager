import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/models/app_user.dart';
import 'package:smart_waste_collection_manager/models/waste_report.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';
import 'package:smart_waste_collection_manager/features/admin/admin_dashboard.dart';

class TestMockRepository implements WasteReportRepository {
  List<WasteReport> reports;
  List<AppUser> Function()? workersProvider;
  Future<List<AppUser>> Function()? asyncWorkersProvider;
  WasteReport? lastUpdatedReport;

  TestMockRepository({
    required this.reports,
    this.workersProvider,
    this.asyncWorkersProvider,
  });

  @override
  bool get isUsingCloudFirestore => false;

  @override
  Stream<List<WasteReport>> streamAllReports() => Stream.value(reports);

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) =>
      Stream.value(reports.where((r) => r.reporterId == userId).toList());

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) =>
      Stream.value(reports.where((r) => r.assignedWorkerId == workerId).toList());

  @override
  Future<void> createReport(WasteReport report) async {
    reports.add(report);
  }

  @override
  Future<void> updateReport(WasteReport report) async {
    lastUpdatedReport = report;
    final idx = reports.indexWhere((r) => r.id == report.id);
    if (idx != -1) {
      reports[idx] = report;
    }
  }

  @override
  Future<void> deleteReport(String reportId) async {
    reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<List<AppUser>> getAvailableWorkers() async {
    if (asyncWorkersProvider != null) {
      return asyncWorkersProvider!();
    }
    if (workersProvider != null) {
      return workersProvider!();
    }
    return [];
  }
}

void main() {
  group('Admin Dashboard Dynamic Worker Assignment Tests', () {
    late AppUser adminUser;
    late WasteReport pendingReport;

    setUp(() {
      adminUser = AppUser(
        uid: 'admin-001',
        email: 'admin@ecocollect.org',
        displayName: 'Municipal Admin',
        role: AppConstants.roleAdmin,
        createdAt: DateTime.now(),
      );

      pendingReport = WasteReport(
        id: 'REP-TEST-1',
        reporterId: 'res-001',
        reporterName: 'Resident Tester',
        wasteCategory: 'Plastic Waste',
        location: 'Zone 4, Market Cross',
        description: 'Piles of uncollected plastic bags',
        priority: 'High',
        status: AppConstants.statusPending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    testWidgets('Assign dialog loads workers and assigns actual worker UID', (
      WidgetTester tester,
    ) async {
      final worker1 = AppUser(
        uid: 'worker-real-uid-101',
        email: 'vikram.field@ecocollect.org',
        displayName: 'Vikram Singh (Truck #12)',
        role: AppConstants.roleWorker,
        createdAt: DateTime.now(),
      );
      final worker2 = AppUser(
        uid: 'worker-real-uid-102',
        email: 'ananya.field@ecocollect.org',
        displayName: 'Ananya Roy (Van #05)',
        role: AppConstants.roleWorker,
        createdAt: DateTime.now(),
      );

      final repo = TestMockRepository(
        reports: [pendingReport],
        workersProvider: () => [worker1, worker2],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(user: adminUser, repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and click "Assign Crew" button
      final assignBtn = find.widgetWithText(ElevatedButton, 'Assign Crew');
      expect(assignBtn, findsOneWidget);
      await tester.tap(assignBtn);
      await tester.pumpAndSettle();

      // Verify dialog is open with worker names loaded
      expect(find.text('Dispatch Field Crew'), findsOneWidget);
      expect(find.byKey(const Key('admin_assign_worker_dropdown')), findsOneWidget);
      expect(find.text('Vikram Singh (Truck #12)'), findsOneWidget);

      // Confirm dispatch
      final confirmBtn = find.byKey(const Key('admin_assign_confirm_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.text('Dispatch Field Crew'), findsNothing);

      // Verify report was updated with worker1's real UID and name
      expect(repo.lastUpdatedReport, isNotNull);
      expect(repo.lastUpdatedReport!.assignedWorkerId, 'worker-real-uid-101');
      expect(repo.lastUpdatedReport!.assignedWorkerName, 'Vikram Singh (Truck #12)');
      expect(repo.lastUpdatedReport!.status, AppConstants.statusAssigned);
    });

    testWidgets('Empty worker state shows warning and disables confirm button', (
      WidgetTester tester,
    ) async {
      final repo = TestMockRepository(
        reports: [pendingReport],
        workersProvider: () => [], // No workers
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(user: adminUser, repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign Crew'));
      await tester.pumpAndSettle();

      // Empty state warning should appear
      expect(find.byKey(const Key('admin_assign_empty_warning')), findsOneWidget);
      expect(find.text('No Registered Field Workers'), findsOneWidget);

      // Confirm button must be disabled
      final confirmBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('admin_assign_confirm_button')),
      );
      expect(confirmBtn.onPressed, isNull);
    });

    testWidgets('Error state shows error message and retry button', (
      WidgetTester tester,
    ) async {
      bool shouldFail = true;
      final worker = AppUser(
        uid: 'worker-real-uid-201',
        email: 'rahul.field@ecocollect.org',
        displayName: 'Rahul Sharma',
        role: AppConstants.roleWorker,
        createdAt: DateTime.now(),
      );

      final repo = TestMockRepository(
        reports: [pendingReport],
        asyncWorkersProvider: () async {
          if (shouldFail) {
            throw Exception('Firestore network timeout');
          }
          return [worker];
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboard(user: adminUser, repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign Crew'));
      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Failed to load workers'), findsOneWidget);
      expect(find.textContaining('Firestore network timeout'), findsOneWidget);
      expect(find.byKey(const Key('admin_assign_retry_button')), findsOneWidget);

      // Confirm button must be disabled
      final confirmBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('admin_assign_confirm_button')),
      );
      expect(confirmBtn.onPressed, isNull);

      // Tap retry with success
      shouldFail = false;
      await tester.tap(find.byKey(const Key('admin_assign_retry_button')));
      await tester.pumpAndSettle();

      // Now worker is loaded
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.byKey(const Key('admin_assign_worker_dropdown')), findsOneWidget);

      final activeConfirmBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('admin_assign_confirm_button')),
      );
      expect(activeConfirmBtn.onPressed, isNotNull);
    });
  });
}
