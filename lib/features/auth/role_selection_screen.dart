import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onAuthenticated;

  const RoleSelectionScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  void _openPortal(BuildContext context, String role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LoginScreen(
          authService: authService,
          onAuthenticated: onAuthenticated,
          selectedRole: role,
        ),
      ),
    );
  }

  void _enterDemo(String role) {
    authService.enterDemoMode(role);
    onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Color(0xFF1B5E20),
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'EcoCollect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Smart Waste Collection & Urban Sustainability',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 28),

                // Portal Selection Title
                const Text(
                  'Select Your Portal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please select your authorized portal to sign in to your EcoCollect account.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // 1. Resident Portal Card
                _PortalCard(
                  title: 'Resident Portal',
                  badge: 'Public Citizen Access',
                  badgeColor: const Color(0xFFE8F5E9),
                  badgeTextColor: const Color(0xFF1B5E20),
                  icon: Icons.home_outlined,
                  iconColor: const Color(0xFF2E7D32),
                  description:
                      'Report neighborhood waste incidents, track collection requests, and view community eco-tips.',
                  buttonText: 'Sign In / Register',
                  onTap: () => _openPortal(context, AppConstants.roleResident),
                ),
                const SizedBox(height: 14),

                // 2. Field Operations Card
                _PortalCard(
                  title: 'Field Operations Portal',
                  badge: 'Authorized Staff Only',
                  badgeColor: const Color(0xFFE3F2FD),
                  badgeTextColor: const Color(0xFF1565C0),
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF1565C0),
                  description:
                      'For municipal collection crews: view assigned routes, execute bin pickups, and update telemetry.',
                  buttonText: 'Staff Sign In',
                  onTap: () => _openPortal(context, AppConstants.roleWorker),
                ),
                const SizedBox(height: 14),

                // 3. Municipal Governance Card
                _PortalCard(
                  title: 'Municipal Governance Portal',
                  badge: 'Restricted Administration',
                  badgeColor: const Color(0xFFECEFF1),
                  badgeTextColor: const Color(0xFF37474F),
                  icon: Icons.admin_panel_settings_outlined,
                  iconColor: const Color(0xFF37474F),
                  description:
                      'For city administrators: fleet telemetry, service-zone KPIs, incident triage, and staff auditing.',
                  buttonText: 'Administrator Sign In',
                  onTap: () => _openPortal(context, AppConstants.roleAdmin),
                ),
                const SizedBox(height: 28),

                // Demo Sandbox Section (Isolated in-memory simulation)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.flash_on,
                            color: Color(0xFF1B5E20),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demo Sandbox — Offline Simulation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Preview any persona in an isolated offline sandbox without credentials. Simulated data is strictly local and does not represent live municipal records or database changes.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () =>
                                  _enterDemo(AppConstants.roleResident),
                              child: const Text('Demo Resident'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () =>
                                  _enterDemo(AppConstants.roleWorker),
                              child: const Text('Demo Worker'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () =>
                                  _enterDemo(AppConstants.roleAdmin),
                              child: const Text('Demo Admin'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final String title;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final IconData icon;
  final Color iconColor;
  final String description;
  final String buttonText;
  final VoidCallback onTap;

  const _PortalCard({
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.icon,
    required this.iconColor,
    required this.description,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
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
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(buttonText),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
