import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class WasteReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String wasteCategory;
  final String location;
  final String description;
  final String priority;
  final String status;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Documented fallback for missing/corrupted timestamps (Epoch: 1970-01-01)
  static final DateTime epochFallback = DateTime.fromMillisecondsSinceEpoch(0);

  const WasteReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.wasteCategory,
    required this.location,
    required this.description,
    this.priority = 'Medium',
    this.status = AppConstants.statusPending,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == AppConstants.statusPending;
  bool get isAssigned => status == AppConstants.statusAssigned;
  bool get isInProgress => status == AppConstants.statusInProgress;
  bool get isCompleted => status == AppConstants.statusCompleted;
  bool get isRejected => status == AppConstants.statusRejected;

  /// Validates required fields before persistence
  static String? validateInput({
    required String wasteCategory,
    required String location,
  }) {
    if (wasteCategory.trim().isEmpty) {
      return 'Please select a waste category.';
    }
    if (location.trim().isEmpty) {
      return 'Please enter a collection location.';
    }
    if (location.trim().length < 3) {
      return 'Location must be at least 3 characters long.';
    }
    return null;
  }

  /// Verifies if a given transition from current status to target is permitted
  bool canTransitionTo(
    String nextStatus, {
    required bool isAdmin,
    required bool isAssignedWorker,
  }) {
    if (isAdmin) {
      final allowed = AppConstants.adminAllowedTransitions[status] ?? [];
      return allowed.contains(nextStatus);
    }
    if (isAssignedWorker) {
      final allowed = AppConstants.workerAllowedTransitions[status] ?? [];
      return allowed.contains(nextStatus);
    }
    return false;
  }

  WasteReport copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? wasteCategory,
    String? location,
    String? description,
    String? priority,
    String? status,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? resolutionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WasteReport(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      location: location ?? this.location,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'wasteCategory': wasteCategory,
      'location': location,
      'description': description,
      'priority': priority,
      'status': status,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'resolutionNotes': resolutionNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Safe, documented timestamp parser:
  /// Supports:
  /// - Cloud Firestore [Timestamp]
  /// - ISO 8601 [String]
  /// - Milliseconds [int]
  /// - Existing [DateTime]
  ///
  /// Returns null for invalid or missing representations (callers fallback to [epochFallback]
  /// instead of silently masquerading as fresh current time).
  static DateTime? parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory WasteReport.fromMap(Map<String, dynamic> map, {String? docId}) {
    return WasteReport(
      id: docId ?? (map['id'] as String? ?? ''),
      reporterId: map['reporterId'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? 'Resident',
      wasteCategory: map['wasteCategory'] as String? ?? 'Household Waste',
      location: map['location'] as String? ?? '',
      description: map['description'] as String? ?? '',
      priority: map['priority'] as String? ?? 'Medium',
      status: map['status'] as String? ?? AppConstants.statusPending,
      assignedWorkerId: map['assignedWorkerId'] as String?,
      assignedWorkerName: map['assignedWorkerName'] as String?,
      resolutionNotes: map['resolutionNotes'] as String?,
      createdAt: parseTimestamp(map['createdAt']) ?? epochFallback,
      updatedAt: parseTimestamp(map['updatedAt']) ?? epochFallback,
    );
  }
}
