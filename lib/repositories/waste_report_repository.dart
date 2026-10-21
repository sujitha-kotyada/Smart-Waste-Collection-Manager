import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/waste_report.dart';
import '../core/constants/app_constants.dart';

abstract class WasteReportRepository {
  Stream<List<WasteReport>> streamAllReports();
  Stream<List<WasteReport>> streamUserReports(String userId);
  Stream<List<WasteReport>> streamWorkerReports(String workerId);
  Future<void> createReport(WasteReport report);
  Future<void> updateReport(WasteReport report);
  Future<void> deleteReport(String reportId);
  bool get isUsingCloudFirestore;
}

/// Explicit in-memory repository for Simulated Demo Preview / Offline Testing.
class LocalWasteReportRepository implements WasteReportRepository {
  final List<WasteReport> _items = [];
  final StreamController<List<WasteReport>> _controller =
      StreamController<List<WasteReport>>.broadcast();

  LocalWasteReportRepository() {
    _seedInitialData();
  }

  void _seedInitialData() {
    final now = DateTime.now();
    _items.addAll([
      WasteReport(
        id: 'DEMO-101',
        reporterId: 'demo-resident-1',
        reporterName: 'Sujitha (Demo Resident)',
        wasteCategory: 'Overflowing Bin',
        location: 'Main Street, Sector 2, Community Park',
        description:
            'Public waste bin overflowing onto sidewalk. Needs urgent municipal clearing.',
        priority: 'High',
        status: AppConstants.statusInProgress,
        assignedWorkerId: 'demo-worker-1',
        assignedWorkerName: 'Rajesh Kumar (Demo Electric Truck #04)',
        resolutionNotes:
            'Dispatched electric collection truck #04 to sector 2.',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      WasteReport(
        id: 'DEMO-102',
        reporterId: 'demo-resident-1',
        reporterName: 'Sujitha (Demo Resident)',
        wasteCategory: 'Plastic Waste',
        location: 'Green Park, Block A, Near Lake Road',
        description:
            'Single-use plastic bottles and packaging discarded along pedestrian path.',
        priority: 'Medium',
        status: AppConstants.statusCompleted,
        assignedWorkerId: 'demo-worker-1',
        assignedWorkerName: 'Rajesh Kumar (Demo Electric Truck #04)',
        resolutionNotes:
            'Segregated into blue recycling bin and delivered to MRF center.',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      WasteReport(
        id: 'DEMO-103',
        reporterId: 'demo-resident-2',
        reporterName: 'Arun Patel',
        wasteCategory: 'Organic Waste',
        location: 'Sector 5 Vegetable Market Gate 2',
        description:
            'Spoiled organic produce accumulated outside stalls. Attracting strays.',
        priority: 'Urgent',
        status: AppConstants.statusPending,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      WasteReport(
        id: 'DEMO-104',
        reporterId: 'demo-resident-1',
        reporterName: 'Sujitha (Demo Resident)',
        wasteCategory: 'E-Waste',
        location: 'Community Center, Building C Lobby',
        description:
            'Discarded computer monitors and battery peripherals for safe disposal.',
        priority: 'Low',
        status: AppConstants.statusAssigned,
        assignedWorkerId: 'demo-worker-1',
        assignedWorkerName: 'Rajesh Kumar (Demo Electric Truck #04)',
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
    _notify();
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_items));
    }
  }

  @override
  bool get isUsingCloudFirestore => false;

  @override
  Stream<List<WasteReport>> streamAllReports() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) async* {
    yield _items.where((r) => r.reporterId == userId).toList();
    yield* _controller.stream.map(
      (list) => list.where((r) => r.reporterId == userId).toList(),
    );
  }

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) async* {
    yield _items.where((r) => r.assignedWorkerId == workerId).toList();
    yield* _controller.stream.map(
      (list) => list.where((r) => r.assignedWorkerId == workerId).toList(),
    );
  }

  @override
  Future<void> createReport(WasteReport report) async {
    _items.insert(0, report);
    _notify();
  }

  @override
  Future<void> updateReport(WasteReport report) async {
    final idx = _items.indexWhere((r) => r.id == report.id);
    if (idx != -1) {
      _items[idx] = report;
      _notify();
    }
  }

  @override
  Future<void> deleteReport(String reportId) async {
    _items.removeWhere((r) => r.id == reportId);
    _notify();
  }
}

/// Live Cloud Firestore repository.
/// Performs genuine remote Firestore operations. NEVER silently masks errors with in-memory fallbacks.
class FirestoreWasteReportRepository implements WasteReportRepository {
  final FirebaseFirestore? _explicitFirestore;

  FirestoreWasteReportRepository({FirebaseFirestore? firestore})
    : _explicitFirestore = firestore;

  FirebaseFirestore get _firestore {
    if (_explicitFirestore != null) return _explicitFirestore;
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection('reports');

  @override
  bool get isUsingCloudFirestore => true;

  @override
  Stream<List<WasteReport>> streamAllReports() {
    return _reportsRef.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => WasteReport.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  @override
  Stream<List<WasteReport>> streamUserReports(String userId) {
    return _reportsRef.where('reporterId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => WasteReport.fromMap(doc.data(), docId: doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<WasteReport>> streamWorkerReports(String workerId) {
    return _reportsRef
        .where('assignedWorkerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => WasteReport.fromMap(doc.data(), docId: doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  @override
  Future<void> createReport(WasteReport report) async {
    // Real cloud write. Fails with real exception if unauthenticated, permission-denied, or offline.
    await _reportsRef.doc(report.id).set(report.toMap());
  }

  @override
  Future<void> updateReport(WasteReport report) async {
    // Real cloud write. Fails with real exception if unauthorized or invalid.
    await _reportsRef.doc(report.id).update(report.toMap());
  }

  @override
  Future<void> deleteReport(String reportId) async {
    // Real cloud write. Fails with real exception if unauthorized.
    await _reportsRef.doc(reportId).delete();
  }
}
