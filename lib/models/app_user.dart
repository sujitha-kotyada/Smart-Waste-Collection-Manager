import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final DateTime createdAt;

  static final DateTime epochFallback = DateTime.fromMillisecondsSinceEpoch(0);

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = AppConstants.roleResident,
    required this.createdAt,
  });

  bool get isResident => role == AppConstants.roleResident;
  bool get isWorker => role == AppConstants.roleWorker;
  bool get isAdmin => role == AppConstants.roleAdmin;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime? parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AppUser(
      uid: docId ?? (map['uid'] as String? ?? ''),
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Eco Citizen',
      role: map['role'] as String? ?? AppConstants.roleResident,
      createdAt: parseTimestamp(map['createdAt']) ?? epochFallback,
    );
  }
}
