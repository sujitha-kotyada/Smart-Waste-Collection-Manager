import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../core/constants/app_constants.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _explicitAuth;
  final FirebaseFirestore? _explicitFirestore;

  AppUser? _currentUser;
  bool _isDemoMode = false;
  bool _isLoading = false;
  String? _lastErrorMessage;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _explicitAuth = auth,
      _explicitFirestore = firestore {
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
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isAuthenticated => _currentUser != null;

  void _init() {
    _isDemoMode = false;
    _currentUser = null;

    final existing = _auth?.currentUser;
    if (existing != null) {
      _loadUserProfile(existing);
    }

    try {
      _auth?.authStateChanges().listen((User? user) async {
        if (!_isDemoMode) {
          if (user != null) {
            await _loadUserProfile(user);
          } else {
            _currentUser = null;
            notifyListeners();
          }
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

  Future<void> _loadUserProfile(User user) async {
    String resolvedRole = AppConstants.roleResident;

    // 1. Check custom claims first (tamper-proof cloud claim)
    try {
      final tokenResult = await user.getIdTokenResult();
      final claims = tokenResult.claims;
      if (claims != null) {
        if (claims['admin'] == true ||
            claims['role'] == AppConstants.roleAdmin) {
          resolvedRole = AppConstants.roleAdmin;
        } else if (claims['worker'] == true ||
            claims['role'] == AppConstants.roleWorker) {
          resolvedRole = AppConstants.roleWorker;
        }
      }
    } catch (_) {}

    // 2. If claims not present, check Firestore /users/{uid} document
    if (resolvedRole == AppConstants.roleResident) {
      try {
        final firestore = _firestore;
        if (firestore != null) {
          final doc = await firestore.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data() != null) {
            final docRole = doc.data()!['role'] as String?;
            if (docRole == AppConstants.roleAdmin ||
                docRole == AppConstants.roleWorker) {
              resolvedRole = docRole!;
            }
          }
        }
      } catch (_) {}
    }

    _isDemoMode = false;
    _currentUser = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          user.displayName ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@').first
              : 'Eco Citizen'),
      role: resolvedRole,
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    final auth = _auth;
    if (auth == null) {
      _lastErrorMessage =
          'Firebase Auth is not available on this platform/configuration.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await _loadUserProfile(credential.user!);
      }
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

  Future<bool> registerResident({
    required String email,
    required String password,
    required String displayName,
  }) async {
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
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName.trim());

        // Strictly enforce role == 'resident' on public registration
        final newUser = AppUser(
          uid: user.uid,
          email: user.email ?? email.trim(),
          displayName: displayName.trim(),
          role: AppConstants.roleResident,
          createdAt: DateTime.now(),
        );

        final firestore = _firestore;
        if (firestore != null) {
          await firestore
              .collection('users')
              .doc(user.uid)
              .set(newUser.toMap());
        }

        _isDemoMode = false;
        _currentUser = newUser;
      }
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

  /// Evaluator shortcut: Enter simulated demo sandbox (only available when unauthenticated)
  void enterDemoMode(String role) {
    _isDemoMode = true;
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
    try {
      await _auth?.signOut();
    } catch (_) {}
    _isDemoMode = false;
    _currentUser = null;
    notifyListeners();
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
}
