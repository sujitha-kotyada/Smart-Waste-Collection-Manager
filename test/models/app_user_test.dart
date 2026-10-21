import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/models/app_user.dart';

void main() {
  group('AppUser Model & RBAC Tests', () {
    test('Resident role correctly reflects permissions', () {
      final user = AppUser(
        uid: 'res-1',
        email: 'resident@test.com',
        displayName: 'Test Resident',
        role: AppConstants.roleResident,
        createdAt: DateTime.now(),
      );

      expect(user.isResident, isTrue);
      expect(user.isWorker, isFalse);
      expect(user.isAdmin, isFalse);
    });

    test('Worker role correctly reflects permissions', () {
      final user = AppUser(
        uid: 'wrk-1',
        email: 'worker@test.com',
        displayName: 'Field Crew',
        role: AppConstants.roleWorker,
        createdAt: DateTime.now(),
      );

      expect(user.isResident, isFalse);
      expect(user.isWorker, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('Admin role correctly reflects permissions', () {
      final user = AppUser(
        uid: 'adm-1',
        email: 'admin@test.com',
        displayName: 'Supervisor',
        role: AppConstants.roleAdmin,
        createdAt: DateTime.now(),
      );

      expect(user.isResident, isFalse);
      expect(user.isWorker, isFalse);
      expect(user.isAdmin, isTrue);
    });

    test('Serialization and deserialization preserve attributes', () {
      final original = AppUser(
        uid: 'u-99',
        email: 'u99@ecocollect.org',
        displayName: 'Special User',
        role: AppConstants.roleAdmin,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = original.toMap();
      final revived = AppUser.fromMap(map, docId: 'u-99');

      expect(revived.uid, 'u-99');
      expect(revived.email, 'u99@ecocollect.org');
      expect(revived.role, AppConstants.roleAdmin);
      expect(revived.isAdmin, isTrue);
    });

    test(
      'Timestamp parser safely handles invalid dates using epoch fallback',
      () {
        final corruptMap = {
          'uid': 'u-corrupt',
          'email': 'corrupt@test.com',
          'displayName': 'Test Corrupt',
          'role': AppConstants.roleResident,
          'createdAt': 'invalid-date-format',
        };

        final user = AppUser.fromMap(corruptMap, docId: 'u-corrupt');
        expect(user.createdAt, AppUser.epochFallback);
        expect(user.createdAt.year, 1970);
      },
    );
  });
}
