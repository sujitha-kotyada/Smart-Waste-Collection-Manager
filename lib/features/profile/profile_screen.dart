import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/app_user.dart';
import '../../models/waste_report.dart';
import '../../services/auth_service.dart';
import '../../repositories/waste_report_repository.dart';
import '../resident/report_detail_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;
  final AuthService authService;
  final WasteReportRepository repository;
  final VoidCallback onRoleSwitched;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.repository,
    required this.onRoleSwitched,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSavingName = false;
  int _streamRetryKey = 0;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'EC';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _openEditNameDialog() async {
    final nameController = TextEditingController(text: widget.user.displayName);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: Color(0xFF2E7D32)),
                  SizedBox(width: 8),
                  Text('Edit Full Name'),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update your profile display name. Email address and account role are governed by system security policies.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'Enter your name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name cannot be empty.';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Role (${widget.user.role}) and Account UID are protected and cannot be self-modified.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSavingName ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSavingName
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            setDialogState(() => _isSavingName = true);
                            Navigator.of(ctx).pop(true);
                          }
                        },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSavingName = true);
      final newName = nameController.text.trim();
      final success = await widget.authService.updateDisplayName(newName);
      if (!mounted) return;
      setState(() => _isSavingName = false);
      if (success) {
        widget.onRoleSwitched();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Text('Profile name updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final err = widget.authService.lastErrorMessage ?? 'Failed to update name';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(err),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final Color roleThemeColor;
    final String roleTitle;
    final IconData roleIcon;

    if (user.isAdmin) {
      roleThemeColor = const Color(0xFF1976D2);
      roleTitle = 'Municipal Administrator';
      roleIcon = Icons.admin_panel_settings;
    } else if (user.isWorker) {
      roleThemeColor = const Color(0xFF7B1FA2);
      roleTitle = 'Municipal Field Crew';
      roleIcon = Icons.engineering;
    } else {
      roleThemeColor = const Color(0xFF2E7D32);
      roleTitle = 'Community Resident';
      roleIcon = Icons.person;
    }

    // Role-authorized reports stream
    final Stream<List<WasteReport>> reportsStream = user.isAdmin
        ? widget.repository.streamAllReports()
        : user.isWorker
            ? widget.repository.streamWorkerReports(user.uid)
            : widget.repository.streamUserReports(user.uid);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // 1. Human-Centered Profile Header
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: roleThemeColor.withValues(alpha: 0.15),
                    child: Text(
                      _getInitials(user.displayName),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: roleThemeColor,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _openEditNameDialog(),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: roleThemeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: Colors.black54,
                    tooltip: 'Edit Name',
                    onPressed: () => _openEditNameDialog(),
                  ),
                ],
              ),
              Text(
                user.email.isNotEmpty ? user.email : 'No email provided',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: roleThemeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: roleThemeColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(roleIcon, size: 14, color: roleThemeColor),
                    const SizedBox(width: 6),
                    Text(
                      roleTitle,
                      style: TextStyle(
                        color: roleThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Personal Information Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: roleThemeColor,
                      ),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit Name', style: TextStyle(fontSize: 12)),
                      onPressed: () => _openEditNameDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDataRow(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: user.displayName,
                ),
                const Divider(height: 18),
                _buildDataRow(
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: user.email.isNotEmpty ? user.email : 'None',
                ),
                const Divider(height: 18),
                _buildDataRow(
                  icon: Icons.badge_outlined,
                  label: 'Account Role',
                  value: roleTitle,
                  valueColor: roleThemeColor,
                ),
                const Divider(height: 18),
                if (user.isWorker) ...[
                  _buildDataRow(
                    icon: Icons.work_outline,
                    label: 'Field Crew Identifier (Generated)',
                    value: 'CREW-${user.uid.length >= 8 ? user.uid.substring(0, 8).toUpperCase() : user.uid.toUpperCase()}',
                    subtext: 'System-generated identifier derived from account UID.',
                  ),
                  const Divider(height: 18),
                  _buildDataRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'Assigned Fleet / Unit',
                    value: 'Not specified',
                    subtext: 'Fleet assignments are managed dynamically by municipal dispatch.',
                  ),
                  const Divider(height: 18),
                ] else if (user.isResident) ...[
                  _buildDataRow(
                    icon: Icons.location_city_outlined,
                    label: 'Service Zone',
                    value: 'Not configured',
                    subtext: 'Service zone is determined dynamically by incident location.',
                  ),
                  const Divider(height: 18),
                ],
                _buildDataRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: DateFormatter.format(user.createdAt),
                ),
                const Divider(height: 18),
                _buildDataRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact Number',
                  value: 'Not provided',
                  subtext: 'Contact number & home address are not stored in the current user schema.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Activity Overview & Key Metrics (Live stream query)
        StreamBuilder<List<WasteReport>>(
          key: ValueKey('reports_stream_${user.uid}_$_streamRetryKey'),
          stream: reportsStream,
          builder: (context, snapshot) {
            // Error State
            if (snapshot.hasError) {
              return Card(
                elevation: 0,
                color: const Color(0xFFFFEBEE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Color(0xFFC62828),
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Unable to load activity records',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFFB71C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'A network or authorization error occurred while retrieving reports. Please verify your connection.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          side: const BorderSide(color: Color(0xFFC62828)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => setState(() => _streamRetryKey++),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry Connection'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Loading State
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Card(
                elevation: 0,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading activity records...',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final reports = snapshot.data ?? [];

            final int statTotal = reports.length;
            final int statPending = reports.where((r) => r.isPending).length;
            final int statActive = reports.where((r) => r.isInProgress || r.isAssigned).length;
            final int statCompleted = reports.where((r) => r.isCompleted).length;

            final String stat1Label;
            final String stat2Label;
            final String stat3Label;
            final String stat4Label;

            if (user.isWorker) {
              stat1Label = 'Assigned Tasks';
              stat2Label = 'In Progress';
              stat3Label = 'Completed Work';
              stat4Label = 'Total Handled';
            } else if (user.isAdmin) {
              stat1Label = 'City Reports';
              stat2Label = 'Awaiting Dispatch';
              stat3Label = 'Field Operations';
              stat4Label = 'Resolved Rate';
            } else {
              stat1Label = 'My Reports';
              stat2Label = 'Pending Review';
              stat3Label = 'In Progress';
              stat4Label = 'Resolved';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Activity Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    Text(
                      '$statTotal Total Records',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: stat1Label,
                        value: user.isAdmin ? '$statTotal' : (user.isWorker ? '${reports.where((r) => r.isAssigned).length}' : '$statTotal'),
                        icon: Icons.assignment_outlined,
                        color: roleThemeColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        title: stat2Label,
                        value: user.isWorker ? '${reports.where((r) => r.isInProgress).length}' : '$statPending',
                        icon: Icons.hourglass_top_outlined,
                        color: const Color(0xFFF57C00),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        title: stat3Label,
                        value: user.isWorker ? '$statCompleted' : '$statActive',
                        icon: user.isWorker ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                        color: user.isWorker ? const Color(0xFF2E7D32) : const Color(0xFF0288D1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        title: stat4Label,
                        value: user.isWorker ? '$statTotal' : (user.isAdmin && statTotal > 0 ? '${((statCompleted / statTotal) * 100).toInt()}%' : '$statCompleted'),
                        icon: Icons.task_alt_outlined,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. Recent Activity List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      user.isWorker
                          ? 'Recent Field Tasks'
                          : user.isAdmin
                              ? 'Recent Municipal Incidents'
                              : 'Recent Incident Reports',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263238),
                      ),
                    ),
                    if (reports.isNotEmpty)
                      Text(
                        'Showing up to 4',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (reports.isEmpty)
                  Card(
                    elevation: 0,
                    color: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade500),
                            const SizedBox(height: 8),
                            Text(
                              user.isWorker
                                  ? 'No assigned collection tasks yet.'
                                  : user.isAdmin
                                      ? 'No municipal waste reports registered.'
                                      : 'You have not submitted any waste reports yet.',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...reports.take(4).map((report) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0.8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(report.status).withValues(alpha: 0.15),
                          child: Icon(
                            _categoryIcon(report.wasteCategory),
                            color: _statusColor(report.status),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          report.wasteCategory,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              report.location,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.timeAgo(report.createdAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(report.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _statusColor(report.status).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            report.status,
                            style: TextStyle(
                              color: _statusColor(report.status),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => ReportDetailSheet(report: report),
                          );
                        },
                      ),
                    );
                  }),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // 5. Evaluator Sandbox Persona Switcher (Demo Sandbox Only)
        if (widget.authService.isDemoMode)
          Card(
            color: const Color(0xFFF1F8E9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFC8E6C9)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Evaluator Sandbox Preview',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'DEMO ONLY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Quickly preview the profile and dashboard experience across roles in this simulated sandbox.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildRoleChoiceChip(
                        context,
                        title: 'Resident',
                        isSelected: user.isResident,
                        role: AppConstants.roleResident,
                        color: const Color(0xFF2E7D32),
                      ),
                      _buildRoleChoiceChip(
                        context,
                        title: 'Field Crew',
                        isSelected: user.isWorker,
                        role: AppConstants.roleWorker,
                        color: const Color(0xFF7B1FA2),
                      ),
                      _buildRoleChoiceChip(
                        context,
                        title: 'Administrator',
                        isSelected: user.isAdmin,
                        role: AppConstants.roleAdmin,
                        color: const Color(0xFF1976D2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),

        // 6. Sign Out Action
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to end your current session?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await widget.authService.signOut();
              widget.onRoleSwitched();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out Session'),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtext,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
              if (subtext != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChoiceChip(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required String role,
    required Color color,
  }) {
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.18),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (!isSelected) {
          widget.authService.switchDemoRole(role);
          widget.onRoleSwitched();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: color,
              content: Text('Switched view to $title role'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return const Color(0xFFF57C00); // Orange
      case AppConstants.statusAssigned:
        return const Color(0xFF1976D2); // Blue
      case AppConstants.statusInProgress:
        return const Color(0xFF7B1FA2); // Purple
      case AppConstants.statusCompleted:
        return const Color(0xFF2E7D32); // Green
      case AppConstants.statusRejected:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Plastic Waste':
        return Icons.local_drink;
      case 'Organic Waste':
        return Icons.eco;
      case 'E-Waste':
        return Icons.electrical_services;
      case 'Hazardous Waste':
        return Icons.warning_amber;
      case 'Paper & Cardboard':
        return Icons.inventory_2;
      case 'Overflowing Bin':
        return Icons.delete_sweep;
      default:
        return Icons.delete_outline;
    }
  }
}
