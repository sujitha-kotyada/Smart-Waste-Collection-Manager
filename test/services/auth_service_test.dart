import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/services/auth_service.dart';

void main() {
  group('AuthService RBAC and Isolation Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test(
      'Initial unauthenticated state has null currentUser and false isDemoMode',
      () {
        expect(authService.currentUser, isNull);
        expect(authService.isAuthenticated, isFalse);
        expect(authService.isDemoMode, isFalse);
      },
    );

    test('enterDemoMode properly initializes persona in simulated sandbox', () {
      authService.enterDemoMode(AppConstants.roleWorker);

      expect(authService.isAuthenticated, isTrue);
      expect(authService.isDemoMode, isTrue);
      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser!.role, AppConstants.roleWorker);
      expect(authService.currentUser!.isWorker, isTrue);
    });

    test('switchDemoRole works when in demo mode', () {
      authService.enterDemoMode(AppConstants.roleResident);
      expect(authService.currentUser!.role, AppConstants.roleResident);

      authService.switchDemoRole(AppConstants.roleAdmin);
      expect(authService.currentUser!.role, AppConstants.roleAdmin);
      expect(authService.currentUser!.isAdmin, isTrue);

      authService.switchDemoRole(AppConstants.roleWorker);
      expect(authService.currentUser!.role, AppConstants.roleWorker);
      expect(authService.currentUser!.isWorker, isTrue);
    });

    test('switchDemoRole is strictly rejected when not in demo mode', () {
      // If someone has not entered demo mode, switchDemoRole refuses and preserves null state
      final success = authService.switchDemoRole(AppConstants.roleAdmin);
      expect(success, isFalse);
      expect(authService.currentUser, isNull);
      expect(
        authService.lastErrorMessage,
        contains('Authenticated accounts cannot switch roles locally'),
      );
    });

    test(
      'Sign out resets state to unauthenticated and exits demo mode',
      () async {
        authService.enterDemoMode(AppConstants.roleResident);
        expect(authService.isAuthenticated, isTrue);

        await authService.signOut();
        expect(authService.currentUser, isNull);
        expect(authService.isAuthenticated, isFalse);
        expect(authService.isDemoMode, isFalse);
      },
    );
  });
}
