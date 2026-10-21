import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/models/waste_report.dart';

void main() {
  group('WasteReport Model & Validation Tests', () {
    final testDate = DateTime(2026, 10, 21, 10, 30);

    final sampleReport = WasteReport(
      id: 'REP-101',
      reporterId: 'user-123',
      reporterName: 'John Doe',
      wasteCategory: 'Plastic Waste',
      location: '123 Elm Street, Sector 4',
      description: 'Discarded bottles and bags near curb',
      priority: 'High',
      status: AppConstants.statusPending,
      createdAt: testDate,
      updatedAt: testDate,
    );

    test(
      'Serialization toMap and deserialization fromMap preserve all fields',
      () {
        final map = sampleReport.toMap();
        expect(map['id'], 'REP-101');
        expect(map['reporterId'], 'user-123');
        expect(map['wasteCategory'], 'Plastic Waste');
        expect(map['priority'], 'High');
        expect(map['status'], AppConstants.statusPending);

        final reconstructed = WasteReport.fromMap(map, docId: 'REP-101');
        expect(reconstructed.id, sampleReport.id);
        expect(reconstructed.reporterId, sampleReport.reporterId);
        expect(reconstructed.location, sampleReport.location);
        expect(reconstructed.priority, sampleReport.priority);
        expect(reconstructed.status, sampleReport.status);
      },
    );

    test('Validation detects empty category or short/empty location', () {
      expect(
        WasteReport.validateInput(wasteCategory: '', location: 'Main Street'),
        'Please select a waste category.',
      );

      expect(
        WasteReport.validateInput(wasteCategory: 'Plastic', location: ''),
        'Please enter a collection location.',
      );

      expect(
        WasteReport.validateInput(wasteCategory: 'Plastic', location: 'ab'),
        'Location must be at least 3 characters long.',
      );

      expect(
        WasteReport.validateInput(
          wasteCategory: 'Plastic',
          location: 'Sector 5 Main Road',
        ),
        isNull,
      );
    });

    test('Worker status transitions follow strict permit rules', () {
      final assignedReport = sampleReport.copyWith(
        status: AppConstants.statusAssigned,
        assignedWorkerId: 'worker-1',
      );

      // Assigned -> In Progress is permitted
      expect(
        assignedReport.canTransitionTo(
          AppConstants.statusInProgress,
          isAdmin: false,
          isAssignedWorker: true,
        ),
        isTrue,
      );

      // Assigned -> Completed is NOT permitted directly (must go to In Progress first)
      expect(
        assignedReport.canTransitionTo(
          AppConstants.statusCompleted,
          isAdmin: false,
          isAssignedWorker: true,
        ),
        isFalse,
      );

      // In Progress -> Completed is permitted
      final inProgressReport = assignedReport.copyWith(
        status: AppConstants.statusInProgress,
      );
      expect(
        inProgressReport.canTransitionTo(
          AppConstants.statusCompleted,
          isAdmin: false,
          isAssignedWorker: true,
        ),
        isTrue,
      );

      // Unassigned workers cannot transition reports
      expect(
        assignedReport.canTransitionTo(
          AppConstants.statusInProgress,
          isAdmin: false,
          isAssignedWorker: false,
        ),
        isFalse,
      );
    });

    test('Admin has override authority to assign or reject', () {
      expect(
        sampleReport.canTransitionTo(
          AppConstants.statusAssigned,
          isAdmin: true,
          isAssignedWorker: false,
        ),
        isTrue,
      );
      expect(
        sampleReport.canTransitionTo(
          AppConstants.statusRejected,
          isAdmin: true,
          isAssignedWorker: false,
        ),
        isTrue,
      );
    });

    group('Timestamp Parsing & Corrupted Input Handling', () {
      final targetDate = DateTime.utc(2026, 5, 15, 14, 30);

      test('Parses Firestore Timestamp correctly', () {
        final firestoreTimestamp = Timestamp.fromDate(targetDate);
        final parsed = WasteReport.parseTimestamp(firestoreTimestamp);
        expect(parsed, isNotNull);
        expect(parsed!.isAtSameMomentAs(targetDate), isTrue);
      });

      test('Parses ISO-8601 string correctly', () {
        final parsed = WasteReport.parseTimestamp(targetDate.toIso8601String());
        expect(parsed, isNotNull);
        expect(parsed!.isAtSameMomentAs(targetDate), isTrue);
      });

      test('Parses int milliseconds epoch correctly', () {
        final parsed = WasteReport.parseTimestamp(
          targetDate.millisecondsSinceEpoch,
        );
        expect(parsed, isNotNull);
        expect(
          parsed!.millisecondsSinceEpoch,
          targetDate.millisecondsSinceEpoch,
        );
      });

      test('Parses DateTime directly', () {
        final parsed = WasteReport.parseTimestamp(targetDate);
        expect(parsed, targetDate);
      });

      test('Returns null for corrupt or invalid date inputs', () {
        expect(WasteReport.parseTimestamp('not-a-valid-date'), isNull);
        expect(WasteReport.parseTimestamp(12345.67), isNull);
        expect(WasteReport.parseTimestamp(['2026-05-15']), isNull);
        expect(WasteReport.parseTimestamp({'date': '2026'}), isNull);
        expect(WasteReport.parseTimestamp(null), isNull);
      });

      test(
        'fromMap uses documented epochFallback instead of masking with DateTime.now()',
        () {
          final corruptMap = {
            'id': 'CORRUPT-001',
            'reporterId': 'user-1',
            'reporterName': 'Resident',
            'wasteCategory': 'Organic Waste',
            'location': 'Downtown Plaza',
            'description': 'Overflowing bin',
            'createdAt': 'corrupt-unparseable-date',
            'updatedAt': null,
          };

          final report = WasteReport.fromMap(corruptMap);
          expect(report.createdAt, WasteReport.epochFallback);
          expect(report.updatedAt, WasteReport.epochFallback);
          expect(report.createdAt.year, 1970);
        },
      );
    });
  });
}
