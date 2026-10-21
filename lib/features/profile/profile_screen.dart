import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../repositories/waste_report_repository.dart';

class ProfileScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Color roleBadgeColor;
    String roleLabel;
    IconData roleIcon;

    if (user.isAdmin) {
      roleBadgeColor = const Color(0xFF1976D2);
      roleLabel = 'Municipal Administrator';
      roleIcon = Icons.admin_panel_settings;
    } else if (user.isWorker) {
      roleBadgeColor = const Color(0xFF7B1FA2);
      roleLabel = 'Field Sanitation Crew';
      roleIcon = Icons.engineering;
    } else {
      roleBadgeColor = const Color(0xFF2E7D32);
      roleLabel = 'Community Resident';
      roleIcon = Icons.person;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // User Avatar Card
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: roleBadgeColor.withValues(alpha: 0.15),
                child: Icon(roleIcon, color: roleBadgeColor, size: 48),
              ),
              const SizedBox(height: 14),
              Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: roleBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: roleBadgeColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(roleIcon, size: 14, color: roleBadgeColor),
                    const SizedBox(width: 6),
                    Text(
                      roleLabel,
                      style: TextStyle(
                        color: roleBadgeColor,
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
        const SizedBox(height: 28),

        // Evaluator Quick Role Switcher (Demo Mode Only) or Cloud Identity Card
        if (authService.isDemoMode)
          Card(
            color: const Color(0xFFF1F8E9),
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
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Evaluator Role Switcher (Simulated Sandbox)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
                          'SIMULATED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Preview Resident, Field Crew, and Admin workflows in local sandbox memory. This simulated switcher has no effect on live Cloud Firestore.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
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
                        title: 'Field Worker',
                        isSelected: user.isWorker,
                        role: AppConstants.roleWorker,
                        color: const Color(0xFF7B1FA2),
                      ),
                      _buildRoleChoiceChip(
                        context,
                        title: 'Admin',
                        isSelected: user.isAdmin,
                        role: AppConstants.roleAdmin,
                        color: const Color(0xFF1976D2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cloud Authenticated Identity',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'VERIFIED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'User UID: ${user.uid}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your role is securely resolved from Cloud Firestore (/users/{uid}) and Firebase Custom Claims. Client-side role escalation is prohibited by firestore.rules.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Storage & Infrastructure Status
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Infrastructure',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.cloud_outlined,
                  'Firebase Project',
                  'smart-waste-collection-manager',
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.storage_outlined,
                  'Persistence Engine',
                  authService.isDemoMode
                      ? 'Local In-Memory Sandbox (Isolated Evaluator Mode)'
                      : (repository.isUsingCloudFirestore
                            ? 'Cloud Firestore (Live Cloud Sync)'
                            : 'Local In-Memory Repository'),
                  highlightColor: authService.isDemoMode
                      ? const Color(0xFFE65100)
                      : const Color(0xFF2E7D32),
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.security,
                  'Security Enforcement',
                  authService.isDemoMode
                      ? 'Local Sandbox Simulation (Cloud writes disabled)'
                      : 'firestore.rules enforced (Immutable incidents, RBAC)',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // About EcoCollect
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1B5E20),
                ),
                title: const Text(
                  'About EcoCollect',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Smart Waste Collection Manager v1.0.0+1 • UN SDG 11 & 12',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: Color(0xFF1B5E20),
                ),
                title: const Text(
                  'Academic Project Evaluation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Flutter 3.41.4 Stable • Firebase Architecture',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Sign Out Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            await authService.signOut();
            onRoleSwitched();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out Session'),
        ),
        const SizedBox(height: 80),
      ],
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
        fontSize: 13,
      ),
      onSelected: (val) {
        if (!isSelected) {
          authService.switchDemoRole(role);
          onRoleSwitched();
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

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? highlightColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 10),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlightColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
