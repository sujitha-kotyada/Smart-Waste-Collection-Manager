import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../core/constants/app_constants.dart';

/// Status of the role verification and resolution pipeline.
enum RoleResolutionStatus {
  verified,
  roleMismatch,
  missingExpectedRole,
  missingProfile,
  malformedProfile,
  roleConflict,
  malformedTokenClaims,
  contradictoryTokenClaims,
  claimsFetchError,
  permissionDenied,
  offlineOrNetwork,
  transientError,
  registrationProfileCreationFailed,
  unknownError,
}

/// Internal validation state of security token claims.
enum ClaimsValidationStatus {
  absent,
  valid,
  contradictory,
  malformed,
}

class ClaimsValidationResult {
  final ClaimsValidationStatus status;
  final String? role;
  final String? errorMessage;

  const ClaimsValidationResult.absent()
      : status = ClaimsValidationStatus.absent,
        role = null,
        errorMessage = null;

  const ClaimsValidationResult.valid(this.role)
      : status = ClaimsValidationStatus.valid,
        errorMessage = null;

  const ClaimsValidationResult.contradictory(this.errorMessage)
      : status = ClaimsValidationStatus.contradictory,
        role = null;

  const ClaimsValidationResult.malformed(this.errorMessage)
      : status = ClaimsValidationStatus.malformed,
        role = null;
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _explicitAuth;
  final FirebaseFirestore? _explicitFirestore;

  // Test injection hooks for deterministic unit testing
  final Future<Map<String, dynamic>?> Function(String uid)? _testProfileFetcher;
  final Future<void> Function(String uid, Map<String, dynamic> data)?
  _testProfileWriter;
  final Future<Map<String, dynamic>?> Function(String uid)? _testClaimsFetcher;
  final Future<String> Function(String email, String password)?
  _testAuthenticator;
  final Future<String> Function(
    String email,
    String password,
    String displayName,
  )?
  _testRegistrationCreator;
  final Future<void> Function()? _testSignOutHandler;

  AppUser? _currentUser;
  bool _isDemoMode = false;
  bool _isLoading = false;
  bool _isAuthenticating = false;
  bool _isVerifyingRestoredSession = false;
  String? _lastErrorMessage;
  RoleResolutionStatus? _lastResolutionStatus;

  // Epoch counter and session identifier for strict concurrency and delayed-event protection
  int _authEpoch = 0;
  String? _activeSessionUid;

  // Cached identifiers for deliberate retry of transient network/server failures
  String? _pendingUid;
  String? _pendingEmail;
  String? _pendingDisplayName;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    @visibleForTesting
    Future<Map<String, dynamic>?> Function(String uid)? profileFetcher,
    @visibleForTesting
    Future<void> Function(String uid, Map<String, dynamic> data)? profileWriter,
    @visibleForTesting
    Future<Map<String, dynamic>?> Function(String uid)? claimsFetcher,
    @visibleForTesting
    Future<String> Function(String email, String password)? authenticator,
    @visibleForTesting
    Future<String> Function(
      String email,
      String password,
      String displayName,
    )?
    registrationCreator,
    @visibleForTesting Future<void> Function()? signOutHandler,
  }) : _explicitAuth = auth,
       _explicitFirestore = firestore,
       _testProfileFetcher = profileFetcher,
       _testProfileWriter = profileWriter,
       _testClaimsFetcher = claimsFetcher,
       _testAuthenticator = authenticator,
       _testRegistrationCreator = registrationCreator,
       _testSignOutHandler = signOutHandler {
    _init();
  }

  FirebaseAuth? get _auth {
    if (_explicitAuth != null) return _explicitAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    if (_explicitFirestore != null) return _explicitFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  AppUser? get currentUser => _currentUser;
  bool get isDemoMode => _isDemoMode;
  bool get isLoading => _isLoading;
  bool get isVerifyingRestoredSession => _isVerifyingRestoredSession;
  String? get activeSessionUid => _activeSessionUid;
  String? get lastErrorMessage => _lastErrorMessage;
  RoleResolutionStatus? get lastResolutionStatus => _lastResolutionStatus;
  bool get isAuthenticated => _currentUser != null;

  void _init() {
    _isDemoMode = false;
    _currentUser = null;

    final existing = _auth?.currentUser;
    if (existing != null) {
      _isVerifyingRestoredSession = true;
      final epoch = ++_authEpoch;
      _activeSessionUid = existing.uid;
      _resolveUserRole(
        uid: existing.uid,
        email: existing.email ?? '',
        displayName: existing.displayName,
        firebaseUser: existing,
        targetEpoch: epoch,
      ).whenComplete(() {
        if (epoch == _authEpoch) {
          _isVerifyingRestoredSession = false;
          notifyListeners();
        }
      });
    }

    try {
      _auth?.authStateChanges().listen((User? user) async {
        if (_isDemoMode) return;
        if (user == null) {
          _authEpoch++;
          _activeSessionUid = null;
          _currentUser = null;
          _isVerifyingRestoredSession = false;
          notifyListeners();
          return;
        }

        // If interactive sign-in or registration is actively running, let that flow control verification
        if (_isAuthenticating) {
          return;
        }

        // Stale event check: Discard if the active session ended or belongs to a different UID
        if (_auth != null && _auth?.currentUser?.uid != user.uid) {
          return;
        }

        if (_activeSessionUid != null && _activeSessionUid != user.uid) {
          return;
        }

        final epoch = ++_authEpoch;
        _activeSessionUid = user.uid;
        _isVerifyingRestoredSession = true;
        notifyListeners();

        await _resolveUserRole(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          firebaseUser: user,
          targetEpoch: epoch,
        );

        if (epoch == _authEpoch) {
          _isVerifyingRestoredSession = false;
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  AppUser _getDemoUser(String role) {
    final now = DateTime.now();
    switch (role) {
      case AppConstants.roleAdmin:
        return AppUser(
          uid: 'demo-admin-1',
          email: 'admin.manager@ecocollect.org',
          displayName: 'Admin Supervisor (Demo Sandbox)',
          role: AppConstants.roleAdmin,
          createdAt: now.subtract(const Duration(days: 90)),
        );
      case AppConstants.roleWorker:
        return AppUser(
          uid: 'demo-worker-1',
          email: 'rajesh.field@ecocollect.org',
          displayName: 'Rajesh Kumar (Demo Field Crew)',
          role: AppConstants.roleWorker,
          createdAt: now.subtract(const Duration(days: 45)),
        );
      case AppConstants.roleResident:
      default:
        return AppUser(
          uid: 'demo-resident-1',
          email: 'sujitha.resident@ecocollect.org',
          displayName: 'Sujitha (Demo Resident)',
          role: AppConstants.roleResident,
          createdAt: now.subtract(const Duration(days: 15)),
        );
    }
  }

  /// Strictly validates token claims.
  /// - Distinguishes genuinely absent claims from malformed or contradictory claims.
  /// - Validates compatible combinations of 'role' and boolean capability flags ('admin', 'worker').
  /// - Rejects contradictory role fields and conflicting booleans (e.g., role: admin with admin: false).
  /// - Rejects unknown explicit role strings and invalid claim types.
  ClaimsValidationResult _validateClaims(Map<String, dynamic>? claims) {
    if (claims == null || claims.isEmpty) {
      return const ClaimsValidationResult.absent();
    }

    final hasRoleKey = claims.containsKey('role');
    final hasAdminKey = claims.containsKey('admin');
    final hasWorkerKey = claims.containsKey('worker');

    if (!hasRoleKey && !hasAdminKey && !hasWorkerKey) {
      return const ClaimsValidationResult.absent();
    }

    // 1. Inspect 'role' string field
    String? roleFromField;
    if (hasRoleKey) {
      final rawRole = claims['role'];
      if (rawRole is! String) {
        return const ClaimsValidationResult.malformed(
          'Token claim "role" must be a string.',
        );
      }
      if (rawRole != AppConstants.roleResident &&
          rawRole != AppConstants.roleWorker &&
          rawRole != AppConstants.roleAdmin) {
        return ClaimsValidationResult.malformed(
          'Token claim "role" contains unknown role value: "$rawRole".',
        );
      }
      roleFromField = rawRole;
    }

    // 2. Inspect 'admin' boolean flag
    bool? adminBool;
    if (hasAdminKey) {
      final rawAdmin = claims['admin'];
      if (rawAdmin is! bool) {
        return const ClaimsValidationResult.malformed(
          'Token claim "admin" must be a boolean.',
        );
      }
      adminBool = rawAdmin;
    }

    // 3. Inspect 'worker' boolean flag
    bool? workerBool;
    if (hasWorkerKey) {
      final rawWorker = claims['worker'];
      if (rawWorker is! bool) {
        return const ClaimsValidationResult.malformed(
          'Token claim "worker" must be a boolean.',
        );
      }
      workerBool = rawWorker;
    }

    // 4. Reject contradictory boolean claims
    if (adminBool == true && workerBool == true) {
      return const ClaimsValidationResult.contradictory(
        'Contradictory token claims: both "admin" and "worker" claims are true.',
      );
    }

    // 5. Cross-check role field with explicit boolean denial
    if (roleFromField == AppConstants.roleAdmin && adminBool == false) {
      return const ClaimsValidationResult.contradictory(
        'Contradictory token claims: "role" is admin but "admin" boolean claim is false.',
      );
    }

    if (roleFromField == AppConstants.roleWorker && workerBool == false) {
      return const ClaimsValidationResult.contradictory(
        'Contradictory token claims: "role" is worker but "worker" boolean claim is false.',
      );
    }

    String? roleFromBool;
    if (adminBool == true) {
      roleFromBool = AppConstants.roleAdmin;
    } else if (workerBool == true) {
      roleFromBool = AppConstants.roleWorker;
    }

    // 6. Cross-check role field with positive boolean assertion
    if (roleFromField != null && roleFromBool != null) {
      if (roleFromField != roleFromBool) {
        return ClaimsValidationResult.contradictory(
          'Contradictory token claims: "role" is "$roleFromField" but boolean flags indicate "$roleFromBool".',
        );
      }
    }

    if (roleFromField == AppConstants.roleResident &&
        (adminBool == true || workerBool == true)) {
      return const ClaimsValidationResult.contradictory(
        'Contradictory token claims: "role" is resident but privileged claim flag is true.',
      );
    }

    final resolvedClaimRole = roleFromField ?? roleFromBool;
    if (resolvedClaimRole != null) {
      return ClaimsValidationResult.valid(resolvedClaimRole);
    }

    // All present keys were false or non-asserting (e.g. admin: false, worker: false without role)
    return const ClaimsValidationResult.absent();
  }

  Future<Map<String, dynamic>?> _fetchProfileData(String uid) async {
    if (_testProfileFetcher != null) {
      return await _testProfileFetcher(uid);
    }
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Firestore instance is unavailable.',
      );
    }
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<Map<String, dynamic>?> _fetchClaimsData(User? user, String uid) async {
    if (_testClaimsFetcher != null) {
      return await _testClaimsFetcher(uid);
    }
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims;
  }

  Future<void> _cleanSignOut({int? targetEpoch}) async {
    _currentUser = null;
    _pendingUid = null;
    _pendingEmail = null;
    _pendingDisplayName = null;
    _activeSessionUid = null;
    if (_testSignOutHandler != null) {
      await _testSignOutHandler();
    } else {
      try {
        await _auth?.signOut();
      } catch (_) {}
    }
    if (targetEpoch != null && targetEpoch != _authEpoch) {
      return;
    }
    notifyListeners();
  }

  /// Resolves the authenticated user's role according to strict security policy.
  /// Never defaults to Resident when profile is missing, malformed, or unverifiable.
  /// Rejects explicit conflicts between token claims and Firestore profile.
  Future<bool> _resolveUserRole({
    required String uid,
    required String email,
    String? displayName,
    User? firebaseUser,
    String? expectedRole,
    int? targetEpoch,
  }) async {
    // Check if operation is already stale before beginning
    if (targetEpoch != null && targetEpoch != _authEpoch) {
      return false;
    }

    // 1. Fetch and validate token claims (Fail-closed on claim-fetch errors)
    Map<String, dynamic>? claims;
    try {
      claims = await _fetchClaimsData(firebaseUser, uid);
    } on FirebaseException catch (e) {
      if (targetEpoch != null && targetEpoch != _authEpoch) return false;
      if (e.code == 'permission-denied') {
        final currentEpoch = ++_authEpoch;
        _activeSessionUid = null;
        _lastResolutionStatus = RoleResolutionStatus.permissionDenied;
        _lastErrorMessage =
            'Access denied by security policy while verifying security claims.';
        await _cleanSignOut(targetEpoch: currentEpoch);
        return false;
      } else if (e.code == 'unavailable' ||
          e.code == 'network-request-failed' ||
          e.message?.toLowerCase().contains('network') == true) {
        _lastResolutionStatus = RoleResolutionStatus.offlineOrNetwork;
        _lastErrorMessage =
            'Network connection unavailable. Unable to verify security claims. Please check your connection and retry.';
        _currentUser = null;
        _pendingUid = uid;
        _pendingEmail = email;
        _pendingDisplayName = displayName;
        notifyListeners();
        return false;
      } else {
        final currentEpoch = ++_authEpoch;
        _activeSessionUid = null;
        _lastResolutionStatus = RoleResolutionStatus.claimsFetchError;
        _lastErrorMessage =
            'Failed to verify security token claims: ${e.message ?? e.code}';
        await _cleanSignOut(targetEpoch: currentEpoch);
        return false;
      }
    } catch (e) {
      if (targetEpoch != null && targetEpoch != _authEpoch) return false;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection')) {
        _lastResolutionStatus = RoleResolutionStatus.offlineOrNetwork;
        _lastErrorMessage =
            'Network connection unavailable. Unable to verify security claims. Please check your connection and retry.';
        _currentUser = null;
        _pendingUid = uid;
        _pendingEmail = email;
        _pendingDisplayName = displayName;
        notifyListeners();
        return false;
      }
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.claimsFetchError;
      _lastErrorMessage = 'Security token claim verification failed: $e';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }

    if (targetEpoch != null && targetEpoch != _authEpoch) return false;

    // Validate claims content
    final claimsResult = _validateClaims(claims);
    if (claimsResult.status == ClaimsValidationStatus.malformed) {
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.malformedTokenClaims;
      _lastErrorMessage =
          claimsResult.errorMessage ?? 'Security token claims are malformed.';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }
    if (claimsResult.status == ClaimsValidationStatus.contradictory) {
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.contradictoryTokenClaims;
      _lastErrorMessage =
          claimsResult.errorMessage ??
          'Contradictory security claims detected in authentication token.';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }

    final claimRole = claimsResult.role;

    // 2. Fetch Firestore profile
    Map<String, dynamic>? profileData;
    try {
      profileData = await _fetchProfileData(uid);
    } on FirebaseException catch (e) {
      if (targetEpoch != null && targetEpoch != _authEpoch) return false;
      if (e.code == 'permission-denied') {
        final currentEpoch = ++_authEpoch;
        _activeSessionUid = null;
        _lastResolutionStatus = RoleResolutionStatus.permissionDenied;
        _lastErrorMessage =
            'Access denied by security policy. Your account profile cannot be verified.';
        await _cleanSignOut(targetEpoch: currentEpoch);
        return false;
      } else if (e.code == 'unavailable' ||
          e.code == 'network-request-failed' ||
          e.message?.toLowerCase().contains('network') == true) {
        _lastResolutionStatus = RoleResolutionStatus.offlineOrNetwork;
        _lastErrorMessage =
            'Network connection unavailable. Unable to reach verification servers. Please check your connection and retry.';
        _currentUser = null;
        _pendingUid = uid;
        _pendingEmail = email;
        _pendingDisplayName = displayName;
        notifyListeners();
        return false;
      } else if (e.code == 'deadline-exceeded') {
        _lastResolutionStatus = RoleResolutionStatus.transientError;
        _lastErrorMessage =
            'Verification timed out. Server is temporarily unavailable. Please retry.';
        _currentUser = null;
        _pendingUid = uid;
        _pendingEmail = email;
        _pendingDisplayName = displayName;
        notifyListeners();
        return false;
      } else {
        final currentEpoch = ++_authEpoch;
        _activeSessionUid = null;
        _lastResolutionStatus = RoleResolutionStatus.unknownError;
        _lastErrorMessage =
            'Profile verification failed: ${e.message ?? e.code}';
        await _cleanSignOut(targetEpoch: currentEpoch);
        return false;
      }
    } catch (e) {
      if (targetEpoch != null && targetEpoch != _authEpoch) return false;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('connection')) {
        _lastResolutionStatus = RoleResolutionStatus.offlineOrNetwork;
        _lastErrorMessage =
            'Network connection unavailable. Unable to reach verification servers. Please check your connection and retry.';
        _currentUser = null;
        _pendingUid = uid;
        _pendingEmail = email;
        _pendingDisplayName = displayName;
        notifyListeners();
        return false;
      }
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.unknownError;
      _lastErrorMessage = 'Profile verification failed: $e';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }

    if (targetEpoch != null && targetEpoch != _authEpoch) return false;

    // 3. Reject missing profile (Never create replacement profiles automatically!)
    if (profileData == null) {
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.missingProfile;
      _lastErrorMessage =
          'Account profile not found in EcoCollect database. Please contact municipal support for account provisioning.';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }

    // 4. Validate profile role field
    final rawRole = profileData['role'];
    if (rawRole is! String ||
        (rawRole != AppConstants.roleResident &&
            rawRole != AppConstants.roleWorker &&
            rawRole != AppConstants.roleAdmin)) {
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.malformedProfile;
      _lastErrorMessage =
          'Account profile contains invalid configuration data (unrecognized role). Access denied. Please contact municipal support.';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }
    final docRole = rawRole;

    // 5. Reject explicit conflicts between token claims and Firestore profile
    if (claimRole != null && claimRole != docRole) {
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.roleConflict;
      _lastErrorMessage =
          'Security authorization conflict detected between token claims ($claimRole) and database profile ($docRole). Access blocked.';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }

    // When claims are absent, docRole is the trusted role
    final trustedRole = claimRole ?? docRole;

    // 6. Enforce expected portal role (Strict Role Isolation)
    if (expectedRole != null && expectedRole != trustedRole) {
      final currentEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _lastResolutionStatus = RoleResolutionStatus.roleMismatch;
      _lastErrorMessage =
          'Access denied. Your account is registered as a ${_formatRole(trustedRole)}. '
          'Please sign in through the ${_formatPortal(trustedRole)} portal.';
      await _cleanSignOut(targetEpoch: currentEpoch);
      return false;
    }

    if (targetEpoch != null && targetEpoch != _authEpoch) return false;

    // 7. Successful verification: grant authenticated dashboard access
    _activeSessionUid = uid;
    _lastResolutionStatus = RoleResolutionStatus.verified;
    _lastErrorMessage = null;
    _pendingUid = null;
    _pendingEmail = null;
    _pendingDisplayName = null;
    _isDemoMode = false;
    _currentUser = AppUser(
      uid: uid,
      email: email,
      displayName:
          displayName ??
          (email.contains('@') ? email.split('@').first : 'Eco Citizen'),
      role: trustedRole,
      createdAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
    String? expectedRole,
  }) async {
    _isLoading = true;
    _isAuthenticating = true;
    _lastErrorMessage = null;
    _lastResolutionStatus = null;
    notifyListeners();

    final epoch = ++_authEpoch;

    if (expectedRole == null || expectedRole.trim().isEmpty) {
      _lastErrorMessage =
          'Expected portal role is required for authentication.';
      _lastResolutionStatus = RoleResolutionStatus.missingExpectedRole;
      _isLoading = false;
      _isAuthenticating = false;
      notifyListeners();
      return false;
    }

    String uid;
    String userEmail;
    String? userDisplayName;
    User? firebaseUser;

    if (_testAuthenticator != null) {
      try {
        uid = await _testAuthenticator(email.trim(), password);
        userEmail = email.trim();
      } catch (e) {
        _lastErrorMessage = e.toString();
        _lastResolutionStatus = RoleResolutionStatus.unknownError;
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }
    } else {
      final auth = _auth;
      if (auth == null) {
        _lastErrorMessage =
            'Firebase Auth is not available on this platform/configuration.';
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }

      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        firebaseUser = credential.user;
        if (firebaseUser == null) {
          _lastErrorMessage =
              'Authentication failed: User credential not returned.';
          _isLoading = false;
          _isAuthenticating = false;
          notifyListeners();
          return false;
        }
        uid = firebaseUser.uid;
        userEmail = firebaseUser.email ?? email.trim();
        userDisplayName = firebaseUser.displayName;
      } on FirebaseAuthException catch (e) {
        _lastErrorMessage = _friendlyAuthError(e);
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      } catch (e) {
        _lastErrorMessage = e.toString();
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }
    }

    if (epoch != _authEpoch) {
      _isLoading = false;
      _isAuthenticating = false;
      return false;
    }

    _activeSessionUid = uid;

    final success = await _resolveUserRole(
      uid: uid,
      email: userEmail,
      displayName: userDisplayName,
      firebaseUser: firebaseUser,
      expectedRole: expectedRole,
      targetEpoch: epoch,
    );

    _isLoading = false;
    _isAuthenticating = false;
    notifyListeners();
    return success;
  }

  /// Retries role verification for an active session interrupted by transient network issues.
  Future<bool> retryProfileVerification({required String expectedRole}) async {
    final uid = _pendingUid ?? _auth?.currentUser?.uid;
    final email = _pendingEmail ?? _auth?.currentUser?.email ?? '';
    final displayName = _pendingDisplayName ?? _auth?.currentUser?.displayName;

    if (uid == null) {
      _lastErrorMessage = 'No pending verification session found to retry.';
      return false;
    }

    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    final epoch = ++_authEpoch;

    final success = await _resolveUserRole(
      uid: uid,
      email: email,
      displayName: displayName,
      firebaseUser: _auth?.currentUser,
      expectedRole: expectedRole,
      targetEpoch: epoch,
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> registerResident({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _isAuthenticating = true;
    _lastErrorMessage = null;
    _lastResolutionStatus = null;
    notifyListeners();

    final epoch = ++_authEpoch;

    String uid;
    String userEmail;
    String userDisplayName = displayName.trim();

    if (_testRegistrationCreator != null) {
      try {
        uid = await _testRegistrationCreator(email.trim(), password, userDisplayName);
        userEmail = email.trim();
      } catch (e) {
        _lastErrorMessage = e.toString();
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }
    } else {
      final auth = _auth;
      if (auth == null) {
        _lastErrorMessage = 'Firebase Auth is not available.';
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }

      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final user = credential.user;
        if (user == null) {
          _lastErrorMessage = 'Failed to create user account.';
          _isLoading = false;
          _isAuthenticating = false;
          notifyListeners();
          return false;
        }

        try {
          await user.updateDisplayName(userDisplayName);
        } catch (_) {}

        uid = user.uid;
        userEmail = user.email ?? email.trim();
      } on FirebaseAuthException catch (e) {
        _lastErrorMessage = _friendlyAuthError(e);
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      } catch (e) {
        _lastErrorMessage = e.toString();
        _isLoading = false;
        _isAuthenticating = false;
        notifyListeners();
        return false;
      }
    }

    final newUser = AppUser(
      uid: uid,
      email: userEmail,
      displayName: userDisplayName,
      role: AppConstants.roleResident,
      createdAt: DateTime.now(),
    );

    // Write to Firestore /users/{uid}
    try {
      if (_testProfileWriter != null) {
        await _testProfileWriter(uid, newUser.toMap());
      } else {
        final firestore = _firestore;
        if (firestore == null) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Firestore instance is unavailable.',
          );
        }
        await firestore.collection('users').doc(uid).set(newUser.toMap());
      }
    } catch (e) {
      // Profile creation failed: immediately sign out from Firebase Auth,
      // invalidate session, and ensure dashboard is not reached!
      final failureEpoch = ++_authEpoch;
      _activeSessionUid = null;
      _currentUser = null;
      _lastResolutionStatus =
          RoleResolutionStatus.registrationProfileCreationFailed;
      _lastErrorMessage =
          'Registration could not be completed: profile creation failed ($e). '
          'Your account has been signed out. Please try again.';
      await _cleanSignOut(targetEpoch: failureEpoch);
      _isLoading = false;
      _isAuthenticating = false;
      notifyListeners();
      return false;
    }

    if (epoch != _authEpoch) {
      await _cleanSignOut(targetEpoch: epoch);
      _isLoading = false;
      _isAuthenticating = false;
      return false;
    }

    _activeSessionUid = uid;
    _isDemoMode = false;
    _lastResolutionStatus = RoleResolutionStatus.verified;
    _currentUser = newUser;
    _isLoading = false;
    _isAuthenticating = false;
    notifyListeners();
    return true;
  }

  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    final auth = _auth;
    if (auth == null) {
      _lastErrorMessage = 'Firebase Auth is not available.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = _friendlyAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _lastErrorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDisplayName(String newDisplayName) async {
    final trimmed = newDisplayName.trim();
    if (trimmed.isEmpty) {
      _lastErrorMessage = 'Display name cannot be empty.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      if (_isDemoMode) {
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(displayName: trimmed);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final user = _auth?.currentUser;
      if (user != null) {
        await user.updateDisplayName(trimmed);
      }
      final firestore = _firestore;
      if (firestore != null && _currentUser != null) {
        await firestore.collection('users').doc(_currentUser!.uid).update({
          'displayName': trimmed,
        });
      }
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(displayName: trimmed);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastErrorMessage = 'Failed to update profile name: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Evaluator shortcut: Enter simulated demo sandbox (only available when unauthenticated)
  void enterDemoMode(String role) {
    _isDemoMode = true;
    _lastResolutionStatus = RoleResolutionStatus.verified;
    _currentUser = _getDemoUser(role);
    notifyListeners();
  }

  /// Switch persona within demo sandbox only.
  /// Throws/refuses if called on a real Firebase-authenticated account.
  bool switchDemoRole(String role) {
    if (!_isDemoMode) {
      _lastErrorMessage =
          'Authenticated accounts cannot switch roles locally. Privileged roles require Firestore or Custom Claims.';
      notifyListeners();
      return false;
    }
    _currentUser = _getDemoUser(role);
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    final epoch = ++_authEpoch;
    _activeSessionUid = null;
    await _cleanSignOut(targetEpoch: epoch);
    _isDemoMode = false;
    _lastResolutionStatus = null;
    _lastErrorMessage = null;
    _isVerifyingRestoredSession = false;
    notifyListeners();
  }

  String _formatRole(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return 'Administrator';
      case AppConstants.roleWorker:
        return 'Worker';
      case AppConstants.roleResident:
      default:
        return 'Resident';
    }
  }

  String _formatPortal(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return 'Admin';
      case AppConstants.roleWorker:
        return 'Worker';
      case AppConstants.roleResident:
      default:
        return 'Resident';
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No registered account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password entered. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console yet. Please enable it in Console.';
      default:
        return e.message ?? 'Authentication error occurred (${e.code}).';
    }
  }

  @visibleForTesting
  void setVerifyingRestoredSessionForTest(bool verifying) {
    _isVerifyingRestoredSession = verifying;
    notifyListeners();
  }
}
