import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/models/waste_report.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';

void main() {
  group('WasteReportRepository Tests', () {
    late LocalWasteReportRepository repository;

    setUp(() {
      repository = LocalWasteReportRepository();
    });

    test('Initial seeded reports are available', () async {
      final reports = await repository.streamAllReports().first;
      expect(reports.isNotEmpty, isTrue);
      expect(reports.any((r) => r.id == 'DEMO-101'), isTrue);
    });

    test('Can create a new waste report', () async {
      final newReport = WasteReport(
        id: 'TEST-999',
        reporterId: 'test-user',
        reporterName: 'Tester',
        wasteCategory: 'E-Waste',
        location: '7th Avenue',
        description: 'Broken monitor',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createReport(newReport);
      final allReports = await repository.streamAllReports().first;
      expect(allReports.any((r) => r.id == 'TEST-999'), isTrue);

      final userReports = await repository.streamUserReports('test-user').first;
      expect(userReports.length, 1);
      expect(userReports.first.wasteCategory, 'E-Waste');
    });

    test('Can update status and assign worker', () async {
      final initial = (await repository.streamAllReports().first).first;

      final updated = initial.copyWith(
        status: AppConstants.statusCompleted,
        resolutionNotes: 'Collected and cleared',
        updatedAt: DateTime.now(),
      );

      await repository.updateReport(updated);
      final refreshed = (await repository.streamAllReports().first).firstWhere(
        (r) => r.id == initial.id,
      );
      expect(refreshed.status, AppConstants.statusCompleted);
      expect(refreshed.resolutionNotes, 'Collected and cleared');
    });

    test(
      'LocalWasteReportRepository correctly identifies as non-cloud engine',
      () {
        expect(repository.isUsingCloudFirestore, isFalse);
      },
    );

    test('FirestoreWasteReportRepository reports cloud persistence mode', () {
      final cloudRepo = FirestoreWasteReportRepository();
      expect(cloudRepo.isUsingCloudFirestore, isTrue);
    });

    test(
      'LocalWasteReportRepository returns available worker profiles with valid fields',
      () async {
        final workers = await repository.getAvailableWorkers();
        expect(workers.isNotEmpty, isTrue);
        for (final worker in workers) {
          expect(worker.uid.isNotEmpty, isTrue);
          expect(worker.email.isNotEmpty, isTrue);
          expect(worker.displayName.isNotEmpty, isTrue);
          expect(worker.role, AppConstants.roleWorker);
          expect(worker.isWorker, isTrue);
        }
      },
    );
  });
}
