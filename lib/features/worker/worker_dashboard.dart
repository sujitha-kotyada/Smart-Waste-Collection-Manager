import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/waste_report.dart';
import '../../models/app_user.dart';
import '../../repositories/waste_report_repository.dart';
import '../resident/report_detail_sheet.dart';

class WorkerDashboard extends StatefulWidget {
  final AppUser user;
  final WasteReportRepository repository;

  const WorkerDashboard({
    super.key,
    required this.user,
    required this.repository,
  });

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(WasteReport report, String newStatus) async {
    String? resolutionNote = report.resolutionNotes;

    if (newStatus == AppConstants.statusCompleted) {
      final noteController = TextEditingController(
        text:
            'Cleared waste batch, sanitized area, and transferred segregated recyclables to MRF unit.',
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Complete Collection Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location: ${report.location}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Field Resolution Notes *',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Enter segregation details or dispatch vehicle #...',
                ),
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
              child: const Text('Confirm Cleaned'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      resolutionNote = noteController.text.trim();
    }

    final updated = report.copyWith(
      status: newStatus,
      resolutionNotes: resolutionNote,
      updatedAt: DateTime.now(),
    );

    try {
      await widget.repository.updateReport(updated);

      if (mounted) {
        final isCloud = widget.repository.isUsingCloudFirestore;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text(
              isCloud
                  ? 'Task #${report.id} updated to "$newStatus" in Cloud Firestore'
                  : '[Demo Sandbox] Task #${report.id} updated to "$newStatus"',
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
            content: Text('Status Update Failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WasteReport>>(
      stream: widget.repository.streamWorkerReports(widget.user.uid),
      builder: (context, snapshot) {
        final workerReports = snapshot.data ?? [];
        final activeTasks = workerReports
            .where((r) => r.isAssigned || r.isInProgress)
            .toList();
        final completedTasks = workerReports
            .where((r) => r.isCompleted)
            .toList();

        return Column(
          children: [
            // Field Crew Info Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.engineering,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Municipal Field Sanitation Worker • Active Duty',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
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
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activeTasks.length} Active',
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF1B5E20),
                    labelColor: const Color(0xFF1B5E20),
                    unselectedLabelColor: Colors.black54,
                    tabs: [
                      Tab(text: 'Assigned Route (${activeTasks.length})'),
                      Tab(text: 'Completed Work (${completedTasks.length})'),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(activeTasks, isActive: true),
                  _buildTaskList(completedTasks, isActive: false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskList(List<WasteReport> tasks, {required bool isActive}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.done_all : Icons.history,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              isActive
                  ? 'All caught up! No pending routes.'
                  : 'No completed tasks yet.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              isActive
                  ? 'New assignments from the supervisor will appear here.'
                  : 'Resolved reports will be listed here.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final statusColor = AppConstants.getStatusColor(task.status);

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
                        AppConstants.getCategoryIcon(task.wasteCategory),
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
                            task.wasteCategory,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Task ID: #${task.id} • ${task.priority} • ${DateFormatter.timeAgo(task.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppConstants.getPriorityColor(
                                task.priority,
                              ),
                              fontWeight: FontWeight.w600,
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
                        task.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.location,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Action Controls for Worker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => ReportDetailSheet.show(context, task),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text(
                        'Details',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    if (isActive)
                      Row(
                        children: [
                          if (task.isAssigned)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B1FA2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => _updateStatus(
                                task,
                                AppConstants.statusInProgress,
                              ),
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: const Text(
                                'Start Pickup',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          if (task.isInProgress)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => _updateStatus(
                                task,
                                AppConstants.statusCompleted,
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text(
                                'Mark Cleaned',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      )
                    else if (task.resolutionNotes != null &&
                        task.resolutionNotes!.isNotEmpty)
                      Flexible(
                        child: Text(
                          task.resolutionNotes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
