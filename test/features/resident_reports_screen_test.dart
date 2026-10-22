import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/features/resident/resident_reports_screen.dart';
import 'package:smart_waste_collection_manager/models/app_user.dart';
import 'package:smart_waste_collection_manager/models/waste_report.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';

class MockReportStreamRepo implements WasteReportRepository {
  Stream<List<WasteReport>>? allReportsStream;
  Stream<List<WasteReport>>? userReportsStream;
  bool streamAllReportsCalled = false;
  String? lastStreamedUserId;

  MockReportStreamRepo({
    this.allReportsStream,
    this.userReportsStream,
  });

  @override
  bool get isUsingCloudFirestore => false;

  @override
  Stream<List<WasteReport>> streamAllReports() {
    streamAllReportsCalled = true;
    return allReportsStream ?? Stream.value([]);
  }

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) {
    lastStreamedUserId = userId;
    return userReportsStream ?? Stream.value([]);
  }

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) =>
      Stream.value([]);

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
  group('ResidentReportsScreen Stream & State Tests', () {
    late AppUser testUser;

    setUp(() {
      testUser = AppUser(
        uid: 'user-test-uid',
        email: 'user@ecocollect.org',
        displayName: 'Test User',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );
    });

    testWidgets(
      'showAllReports true subscribes to streamAllReports, false subscribes to streamUserReports',
      (WidgetTester tester) async {
        final repoAdmin = MockReportStreamRepo();
        await tester.pumpWidget(
          MaterialApp(
            home: ResidentReportsScreen(
              user: testUser,
              repository: repoAdmin,
              showAllReports: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repoAdmin.streamAllReportsCalled, isTrue);
        expect(repoAdmin.lastStreamedUserId, isNull);

        final repoResident = MockReportStreamRepo();
        await tester.pumpWidget(
          MaterialApp(
            home: ResidentReportsScreen(
              user: testUser,
              repository: repoResident,
              showAllReports: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repoResident.streamAllReportsCalled, isFalse);
        expect(repoResident.lastStreamedUserId, 'user-test-uid');
      },
    );

    testWidgets(
      'Displays loading indicator while stream is waiting, never "0 reports found"',
      (WidgetTester tester) async {
        final completer = Completer<List<WasteReport>>();
        final repo = MockReportStreamRepo(
          allReportsStream: completer.future.asStream(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ResidentReportsScreen(
              user: testUser,
              repository: repo,
              showAllReports: true,
            ),
          ),
        );
        await tester.pump(); // Start building, do not settle completer yet

        // Should show loading spinner
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Should NOT show premature "0 reports found" or "No matching reports"
        expect(find.text('0 reports found'), findsNothing);
        expect(find.text('No matching reports'), findsNothing);

        // Now resolve stream
        completer.complete([]);
        await tester.pumpAndSettle();

        // Now empty state is appropriate
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('0 reports found'), findsOneWidget);
        expect(find.text('No matching reports'), findsOneWidget);
      },
    );

    testWidgets(
      'Displays error state on stream failure, never "0 reports found"',
      (WidgetTester tester) async {
        final repo = MockReportStreamRepo(
          allReportsStream: Stream.error(Exception('Firestore permission denied')),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ResidentReportsScreen(
              user: testUser,
              repository: repo,
              showAllReports: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should display error state
        expect(find.text('Failed to load reports'), findsOneWidget);
        expect(find.textContaining('Firestore permission denied'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Should NOT display misleading "0 reports found" or "No matching reports"
        expect(find.text('0 reports found'), findsNothing);
        expect(find.text('No matching reports'), findsNothing);
      },
    );
  });
}
