import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/waste_report.dart';
import '../../models/app_user.dart';
import '../../repositories/waste_report_repository.dart';
import '../resident/report_detail_sheet.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser user;
  final WasteReportRepository repository;

  const AdminDashboard({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedFilter = 'All';

  // Registered municipal field personnel available for assignment
  final List<Map<String, String>> _availableWorkers = [
    {'id': 'demo-worker-1', 'name': 'Rajesh Kumar (Electric Truck #04)'},
    {'id': 'worker-priya-2', 'name': 'Priya Sharma (Segregation Van #02)'},
    {
      'id': 'worker-vikram-3',
      'name': 'Vikram Singh (Hazardous Waste Unit #01)',
    },
    {'id': 'worker-amit-4', 'name': 'Amit Verma (Rapid Response Trike #08)'},
  ];

  Future<void> _openAssignDialog(WasteReport report) async {
    String selectedWorkerId = _availableWorkers.first['id']!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Dispatch Field Crew'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report #${report.id} • ${report.wasteCategory}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Location: ${report.location}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Assigned Worker / Vehicle Crew *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedWorkerId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_pin_outlined),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _availableWorkers.map((w) {
                      return DropdownMenuItem(
                        value: w['id'],
                        child: Text(
                          w['name']!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedWorkerId = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm Dispatch'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final workerObj = _availableWorkers.firstWhere(
        (w) => w['id'] == selectedWorkerId,
      );
      final updated = report.copyWith(
        status: AppConstants.statusAssigned,
        assignedWorkerId: workerObj['id'],
        assignedWorkerName: workerObj['name'],
        updatedAt: DateTime.now(),
      );

      try {
        await widget.repository.updateReport(updated);

        if (mounted) {
          final isCloud = widget.repository.isUsingCloudFirestore;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1976D2),
              content: Text(
                isCloud
                    ? 'Report #${report.id} assigned to ${workerObj['name']} in Cloud Firestore'
                    : '[Demo Sandbox] Report #${report.id} assigned to ${workerObj['name']}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
              content: Text('Dispatch Failed: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _openStatusDialog(WasteReport report) async {
    final allowed = AppConstants.adminAllowedTransitions[report.status] ?? [];
    if (allowed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No further transitions available for this report.'),
        ),
      );
      return;
    }

    String chosen = allowed.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Admin Status Override'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Status: ${report.status}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select New Status *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: chosen,
                items: allowed
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => chosen = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final updated = report.copyWith(
        status: chosen,
        updatedAt: DateTime.now(),
      );
      try {
        await widget.repository.updateReport(updated);
        if (mounted) {
          final isCloud = widget.repository.isUsingCloudFirestore;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCloud
                    ? 'Report status updated to $chosen in Cloud Firestore'
                    : '[Demo Sandbox] Report status updated to $chosen',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
              content: Text('Status Override Failed: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WasteReport>>(
      stream: widget.repository.streamAllReports(),
      builder: (context, snapshot) {
        final allReports = snapshot.data ?? [];
        final total = allReports.length;
        final pending = allReports.where((r) => r.isPending).length;
        final inProgress = allReports
            .where((r) => r.isInProgress || r.isAssigned)
            .length;
        final completed = allReports.where((r) => r.isCompleted).length;
        final rate = total == 0 ? 0 : ((completed / total) * 100).round();

        var filtered = allReports;
        if (_selectedFilter != 'All') {
          filtered = allReports
              .where((r) => r.status == _selectedFilter)
              .toList();
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Admin Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1976D2),
                    Color(0xFF0288D1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 28,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Operations Console',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Municipal Control Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supervising $total municipal reports across city sectors. Current resolution rate is $rate%.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Operational KPI Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Reports',
                    '$total',
                    Icons.analytics_outlined,
                    const Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Pending',
                    '$pending',
                    Icons.warning_amber_rounded,
                    const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Active',
                    '$inProgress',
                    Icons.local_shipping_outlined,
                    const Color(0xFF7B1FA2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Rate',
                    '$rate%',
                    Icons.task_alt,
                    const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Tabs Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Municipal Queue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C2826),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    underline: const SizedBox(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                    ),
                    items: ['All', ...AppConstants.allStatuses].map((st) {
                      return DropdownMenuItem(value: st, child: Text(st));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFilter = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6E2)),
                ),
                child: const Center(
                  child: Text(
                    'No reports in this queue category.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ...filtered.map((r) => _buildAdminReportCard(r)),
            const SizedBox(height: 90),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(
    String title,
    String val,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            val,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminReportCard(WasteReport report) {
    final statusColor = AppConstants.getStatusColor(report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Icon(
                    AppConstants.getCategoryIcon(report.wasteCategory),
                    color: const Color(0xFF1B5E20),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.wasteCategory,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Report #${report.id} • By ${report.reporterName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    report.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.location,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (report.assignedWorkerName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Assigned: ${report.assignedWorkerName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Administrative action bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormatter.timeAgo(report.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => ReportDetailSheet.show(context, report),
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    if (report.isPending || report.isAssigned)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        onPressed: () => _openAssignDialog(report),
                        icon: const Icon(Icons.send, size: 14),
                        label: Text(
                          report.isAssigned ? 'Reassign' : 'Assign Crew',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () => _openStatusDialog(report),
                      child: const Text(
                        'Status',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
