import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        expect(authService.lastResolutionStatus, isNull);
      },
    );

    test('enterDemoMode properly initializes persona in simulated sandbox', () {
      authService.enterDemoMode(AppConstants.roleWorker);

      expect(authService.isAuthenticated, isTrue);
      expect(authService.isDemoMode, isTrue);
      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser!.role, AppConstants.roleWorker);
      expect(authService.currentUser!.isWorker, isTrue);
      expect(
        authService.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
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
        expect(authService.lastResolutionStatus, isNull);
      },
    );

    test('updateDisplayName updates currentUser in demo mode', () async {
      authService.enterDemoMode(AppConstants.roleResident);
      expect(authService.currentUser!.displayName, contains('Sujitha'));

      final success = await authService.updateDisplayName('Sujitha Updated');
      expect(success, isTrue);
      expect(authService.currentUser!.displayName, 'Sujitha Updated');
    });

    test('updateDisplayName rejects empty string or whitespace', () async {
      authService.enterDemoMode(AppConstants.roleResident);
      final success = await authService.updateDisplayName('   ');
      expect(success, isFalse);
      expect(authService.lastErrorMessage, contains('cannot be empty'));
    });
  });

  group('AuthService Checkpoint 1 Role Resolution & Security Hardening Tests', () {
    test('Successful sign-in with matching Resident role', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'resident-uid-1',
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
          'email': 'resident@ecocollect.org',
          'displayName': 'Alice Resident',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser!.role, AppConstants.roleResident);
      expect(service.currentUser!.isResident, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
      expect(service.lastErrorMessage, isNull);
    });

    test('Successful sign-in with matching Worker role', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'worker-uid-1',
        claimsFetcher: (uid) async => {'worker': true},
        profileFetcher: (uid) async => {
          'role': AppConstants.roleWorker,
          'email': 'worker@ecocollect.org',
          'displayName': 'Bob Field Worker',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'worker@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser!.role, AppConstants.roleWorker);
      expect(service.currentUser!.isWorker, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });

    test('Successful sign-in with matching Admin role', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'admin-uid-1',
        claimsFetcher: (uid) async => {'admin': true},
        profileFetcher: (uid) async => {
          'role': AppConstants.roleAdmin,
          'email': 'admin@ecocollect.org',
          'displayName': 'Carol Admin',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'admin@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleAdmin,
      );

      expect(ok, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser!.role, AppConstants.roleAdmin);
      expect(service.currentUser!.isAdmin, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });

    test('Absent role claims with valid profile resolves trusted role without defaulting to resident', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'worker-noclaim-uid',
        claimsFetcher: (uid) async => null, // Explicitly no token claims
        profileFetcher: (uid) async => {
          'role': AppConstants.roleWorker,
          'email': 'worker@ecocollect.org',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'worker@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isTrue);
      expect(service.currentUser!.role, AppConstants.roleWorker);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });

    test('Rejects authentication when expected portal role is missing or empty', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'resident-uid-1',
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: null, // missing expected role
      );

      expect(ok, isFalse);
      expect(service.isAuthenticated, isFalse);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.missingExpectedRole,
      );
      expect(service.lastErrorMessage, contains('Expected portal role is required'));
    });

    test('Expected-role mismatch triggers rejection, error, and clean sign-out', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'resident-uid-1',
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
        },
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      // Resident tries to sign into Worker portal
      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.roleMismatch,
      );
      expect(service.lastErrorMessage, contains('registered as a Resident'));
      expect(service.lastErrorMessage, contains('Resident portal'));
    });

    test('Missing profile is rejected without auto-creating replacement profile', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'missing-profile-uid',
        profileFetcher: (uid) async => null, // Document does not exist
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'orphaned@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.missingProfile,
      );
      expect(service.lastErrorMessage, contains('Account profile not found in EcoCollect database'));
    });

    test('Malformed or unrecognized profile role is rejected', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'malformed-uid',
        profileFetcher: (uid) async => {
          'role': 'super_admin_unrecognized',
        },
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'user@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleAdmin,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.malformedProfile,
      );
      expect(service.lastErrorMessage, contains('unrecognized role'));
    });

    test('Explicit conflict between token claims and profile is rejected', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'conflicting-uid',
        claimsFetcher: (uid) async => {'worker': true}, // Token says worker
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident, // Firestore says resident
        },
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'conflicted@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.roleConflict,
      );
      expect(service.lastErrorMessage, contains('conflict detected'));
    });

    test('Permission-denied is distinguished from missing profile', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'perm-denied-uid',
        profileFetcher: (uid) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'restricted@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.permissionDenied,
      );
      expect(service.lastErrorMessage, contains('security policy'));
    });

    test('Offline / network errors block dashboard access and preserve retry state', () async {
      bool isOnline = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'offline-uid',
        profileFetcher: (uid) async {
          if (!isOnline) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'The service is currently unavailable.',
            );
          }
          return {
            'role': AppConstants.roleResident,
            'email': 'resident@ecocollect.org',
          };
        },
      );

      // Attempt while offline
      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.offlineOrNetwork,
      );
      expect(service.lastErrorMessage, contains('Network connection unavailable'));

      // Now restore network connection and retry deliberate verification
      isOnline = true;
      final retryOk = await service.retryProfileVerification(
        expectedRole: AppConstants.roleResident,
      );

      expect(retryOk, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser!.role, AppConstants.roleResident);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
      expect(service.lastErrorMessage, isNull);
    });

    test('Transient deadline-exceeded error blocks dashboard access without authorization', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'transient-uid',
        profileFetcher: (uid) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
          message: 'Request timed out.',
        ),
      );

      final ok = await service.signInWithEmailPassword(
        email: 'user@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.transientError,
      );
      expect(service.lastErrorMessage, contains('timed out'));
    });
  });

  group('AuthService Checkpoint 1.1 & 1.2 Security Review & Regression Tests', () {
    test('Unknown explicit role in token claims is rejected as malformedTokenClaims', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'malformed-claims-uid',
        claimsFetcher: (uid) async => {'role': 'super_admin_hacker'},
        profileFetcher: (uid) async => {'role': AppConstants.roleAdmin},
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'admin@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleAdmin,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.malformedTokenClaims,
      );
      expect(service.lastErrorMessage, contains('unknown role value'));
    });

    test('Contradictory token claims: both admin and worker are true', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'contradictory-claims-uid',
        claimsFetcher: (uid) async => {'admin': true, 'worker': true},
        profileFetcher: (uid) async => {'role': AppConstants.roleAdmin},
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'admin@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleAdmin,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.contradictoryTokenClaims,
      );
      expect(service.lastErrorMessage, contains('both "admin" and "worker"'));
    });

    test('Contradictory token claims: role is resident but worker is true', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'contradictory-res-worker-uid',
        claimsFetcher: (uid) async => {'role': AppConstants.roleResident, 'worker': true},
        profileFetcher: (uid) async => {'role': AppConstants.roleResident},
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.contradictoryTokenClaims,
      );
    });

    test('Contradictory token claims: role is admin but admin boolean is false', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'contradictory-admin-false-uid',
        claimsFetcher: (uid) async => {'role': AppConstants.roleAdmin, 'admin': false},
        profileFetcher: (uid) async => {'role': AppConstants.roleAdmin},
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'admin@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleAdmin,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.contradictoryTokenClaims,
      );
      expect(service.lastErrorMessage, contains('"admin" boolean claim is false'));
    });

    test('Contradictory token claims: role is worker but worker boolean is false', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'contradictory-worker-false-uid',
        claimsFetcher: (uid) async => {'role': AppConstants.roleWorker, 'worker': false},
        profileFetcher: (uid) async => {'role': AppConstants.roleWorker},
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'worker@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.contradictoryTokenClaims,
      );
      expect(service.lastErrorMessage, contains('"worker" boolean claim is false'));
    });

    test('Compatible claims combinations: role resident with explicit false booleans succeeds', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'res-compat-uid',
        claimsFetcher: (uid) async => {
          'role': AppConstants.roleResident,
          'admin': false,
          'worker': false,
        },
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
          'email': 'resident@ecocollect.org',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isTrue);
      expect(service.currentUser!.role, AppConstants.roleResident);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });

    test('Compatible claims combinations: role worker with worker true and admin false succeeds', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'worker-compat-uid',
        claimsFetcher: (uid) async => {
          'role': AppConstants.roleWorker,
          'worker': true,
          'admin': false,
        },
        profileFetcher: (uid) async => {
          'role': AppConstants.roleWorker,
          'email': 'worker@ecocollect.org',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'worker@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isTrue);
      expect(service.currentUser!.role, AppConstants.roleWorker);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });

    test('Compatible claims combinations: explicit false booleans without role field falls back to Firestore profile', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'false-booleans-uid',
        claimsFetcher: (uid) async => {
          'admin': false,
          'worker': false,
        },
        profileFetcher: (uid) async => {
          'role': AppConstants.roleWorker,
          'email': 'worker@ecocollect.org',
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'worker@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok, isTrue);
      expect(service.currentUser!.role, AppConstants.roleWorker);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });

    test('Claim-fetch network failure is treated as offlineOrNetwork, never as absent claims', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'claim-fail-uid',
        claimsFetcher: (uid) async => throw FirebaseException(
          plugin: 'firebase_auth',
          code: 'unavailable',
          message: 'Unable to fetch token claims.',
        ),
        profileFetcher: (uid) async => {'role': AppConstants.roleResident},
      );

      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.offlineOrNetwork,
      );
      expect(service.lastErrorMessage, contains('Unable to verify security claims'));
    });

    test('Claim-fetch permission failure triggers permissionDenied, not absent claims', () async {
      bool signOutCalled = false;
      final service = AuthService(
        authenticator: (email, pass) async => 'claim-perm-uid',
        claimsFetcher: (uid) async => throw FirebaseException(
          plugin: 'firebase_auth',
          code: 'permission-denied',
          message: 'Permission denied for token claims.',
        ),
        profileFetcher: (uid) async => {'role': AppConstants.roleResident},
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.permissionDenied,
      );
    });

    test('Registration profile-write failure signs out session and sets failure status', () async {
      bool signOutCalled = false;
      final service = AuthService(
        registrationCreator: (email, pass, name) async => 'new-reg-uid',
        profileWriter: (uid, data) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Simulated profile write failure.',
        ),
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      final ok = await service.registerResident(
        email: 'newcitizen@ecocollect.org',
        password: 'password123',
        displayName: 'New Citizen',
      );

      expect(ok, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(signOutCalled, isTrue);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.registrationProfileCreationFailed,
      );
      expect(service.lastErrorMessage, contains('profile creation failed'));
    });

    test('Concurrent verification attempts: stale attempt cannot overwrite newer authenticated state', () async {
      final completer1 = Completer<Map<String, dynamic>?>();
      final completer2 = Completer<Map<String, dynamic>?>();

      final service = AuthService(
        authenticator: (email, pass) async => 'uid-$email',
        profileFetcher: (uid) async {
          if (uid.contains('first')) {
            return await completer1.future;
          } else {
            return await completer2.future;
          }
        },
      );

      // Launch attempt 1 (slow)
      final future1 = service.signInWithEmailPassword(
        email: 'first@ecocollect.org',
        password: 'pass',
        expectedRole: AppConstants.roleResident,
      );

      // Launch attempt 2 (fast, arrives later but finishes first)
      final future2 = service.signInWithEmailPassword(
        email: 'second@ecocollect.org',
        password: 'pass',
        expectedRole: AppConstants.roleWorker,
      );

      // Attempt 2 completes first with worker profile
      completer2.complete({
        'role': AppConstants.roleWorker,
        'email': 'second@ecocollect.org',
      });
      final ok2 = await future2;
      expect(ok2, isTrue);
      expect(service.currentUser!.email, 'second@ecocollect.org');
      expect(service.currentUser!.role, AppConstants.roleWorker);

      // Now attempt 1 completes late with resident profile
      completer1.complete({
        'role': AppConstants.roleResident,
        'email': 'first@ecocollect.org',
      });
      final ok1 = await future1;

      // Attempt 1 must be discarded due to epoch check!
      expect(ok1, isFalse);
      // Current user must remain attempt 2!
      expect(service.currentUser!.email, 'second@ecocollect.org');
      expect(service.currentUser!.role, AppConstants.roleWorker);
    });

    test('Sign-out followed by delayed verification completion does not resurrect session', () async {
      final completer = Completer<Map<String, dynamic>?>();
      bool signOutCalled = false;

      final service = AuthService(
        authenticator: (email, pass) async => 'delayed-uid',
        profileFetcher: (uid) async => await completer.future,
        signOutHandler: () async {
          signOutCalled = true;
        },
      );

      // Start sign in
      final signInFuture = service.signInWithEmailPassword(
        email: 'user@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      // User immediately signs out while verification is in-flight
      await service.signOut();
      expect(signOutCalled, isTrue);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);

      // Verification finally completes late
      completer.complete({
        'role': AppConstants.roleResident,
        'email': 'user@ecocollect.org',
      });
      final result = await signInFuture;

      expect(result, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
    });

    test('Legitimate later sign-in to the same UID is possible after a prior rejection', () async {
      final service = AuthService(
        authenticator: (email, pass) async => 'same-resident-uid',
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
          'email': 'resident@ecocollect.org',
        },
      );

      // 1. Initial attempt with wrong portal (Worker) is rejected
      final ok1 = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleWorker,
      );

      expect(ok1, isFalse);
      expect(service.currentUser, isNull);
      expect(service.isAuthenticated, isFalse);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.roleMismatch,
      );

      // 2. Legitimate later sign-in with correct portal (Resident) succeeds
      final ok2 = await service.signInWithEmailPassword(
        email: 'resident@ecocollect.org',
        password: 'password123',
        expectedRole: AppConstants.roleResident,
      );

      expect(ok2, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser!.uid, 'same-resident-uid');
      expect(service.currentUser!.role, AppConstants.roleResident);
      expect(
        service.lastResolutionStatus,
        RoleResolutionStatus.verified,
      );
    });
  });
}
