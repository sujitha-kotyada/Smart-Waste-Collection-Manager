import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/impact_calculator.dart';
import '../../models/waste_report.dart';
import '../../models/app_user.dart';
import '../../repositories/waste_report_repository.dart';
import 'report_waste_dialog.dart';
import 'report_detail_sheet.dart';

class ResidentDashboard extends StatelessWidget {
  final AppUser user;
  final WasteReportRepository repository;
  final VoidCallback onViewAllReports;

  const ResidentDashboard({
    super.key,
    required this.user,
    required this.repository,
    required this.onViewAllReports,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WasteReport>>(
      stream: repository.streamUserReports(user.uid),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? [];
        final total = reports.length;
        final pending = reports.where((r) => r.isPending).length;
        final inProgress = reports
            .where((r) => r.isInProgress || r.isAssigned)
            .length;
        final resolved = reports.where((r) => r.isCompleted).length;

        final plasticCompleted = reports
            .where((r) => r.isCompleted && r.wasteCategory == 'Plastic Waste')
            .length;
        final organicCompleted = reports
            .where((r) => r.isCompleted && r.wasteCategory == 'Organic Waste')
            .length;

        final impact = EnvironmentalImpact.calculate(
          total: total,
          completed: resolved,
          inProgress: inProgress,
          pending: pending,
          completedPlasticReports: plasticCompleted,
          completedOrganicReports: organicCompleted,
        );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF388E3C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
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
                        Icons.waving_hand,
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
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Hello, Eco Champion!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Every report helps our municipal field crew clear hazards and build sustainable cities.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => ReportWasteDialog.show(
                      context,
                      user: user,
                      repository: repository,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Quick File Incident',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Overview Section Header
            const Text(
              'Your Waste Overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C2826),
              ),
            ),
            const SizedBox(height: 14),

            // Stat Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: isWide
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        'Total Reports',
                        '$total',
                        Icons.assignment_outlined,
                        const Color(0xFFE3F2FD),
                        const Color(0xFF1976D2),
                      ),
                    ),
                    SizedBox(
                      width: isWide
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        'Pending',
                        '$pending',
                        Icons.schedule,
                        const Color(0xFFFFF3E0),
                        const Color(0xFFE65100),
                      ),
                    ),
                    SizedBox(
                      width: isWide
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        'In Progress',
                        '$inProgress',
                        Icons.local_shipping_outlined,
                        const Color(0xFFF3E5F5),
                        const Color(0xFF7B1FA2),
                      ),
                    ),
                    SizedBox(
                      width: isWide
                          ? (constraints.maxWidth - 36) / 4
                          : (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        'Resolved',
                        '$resolved',
                        Icons.check_circle_outline,
                        const Color(0xFFE8F5E9),
                        const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // SDG Environmental Impact Card
            _buildImpactSummaryCard(impact),
            const SizedBox(height: 24),

            // Recent Reports Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Waste Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C2826),
                  ),
                ),
                TextButton(
                  onPressed: onViewAllReports,
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (reports.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6E2)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 44,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No reports submitted yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Found garbage, an overflowing bin, or discarded plastic? Submit a report now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => ReportWasteDialog.show(
                        context,
                        user: user,
                        repository: repository,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Report Waste Incident'),
                    ),
                  ],
                ),
              )
            else
              ...reports.take(3).map((r) => _buildReportTile(context, r)),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: bg,
            child: Icon(icon, color: fg, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C2826),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSummaryCard(EnvironmentalImpact impact) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UN SDG 11 & 12 Impact Metrics',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    Text(
                      'Estimations calculated from verified completed collections',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '${impact.estimatedKgDiverted} kg',
                  'Waste Diverted',
                  Icons.scale,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  '${impact.estimatedKgCo2Avoided} kg',
                  'CO₂e Avoided',
                  Icons.cloud_done_outlined,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  '${impact.completedReports}',
                  'Verified Cleanups',
                  Icons.verified,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildReportTile(BuildContext context, WasteReport report) {
    final statusColor = AppConstants.getStatusColor(report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ReportDetailSheet.show(context, report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Icon(
                  AppConstants.getCategoryIcon(report.wasteCategory),
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.wasteCategory,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          DateFormatter.timeAgo(report.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report.priority,
                            style: TextStyle(
                              color: AppConstants.getPriorityColor(
                                report.priority,
                              ),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
