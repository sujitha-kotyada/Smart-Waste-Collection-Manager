import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'models/app_user.dart';
import 'repositories/waste_report_repository.dart';
import 'services/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/resident/resident_dashboard.dart';
import 'features/resident/resident_reports_screen.dart';
import 'features/resident/report_waste_dialog.dart';
import 'features/worker/worker_dashboard.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/eco_tips/eco_tips_screen.dart';
import 'features/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase Core initialization notice: $e');
  }

  runApp(const SmartWasteApp());
}

class SmartWasteApp extends StatefulWidget {
  final AuthService? authService;
  final WasteReportRepository? repository;

  const SmartWasteApp({super.key, this.authService, this.repository});

  @override
  State<SmartWasteApp> createState() => _SmartWasteAppState();
}

class _SmartWasteAppState extends State<SmartWasteApp> {
  late final AuthService _authService;
  late final WasteReportRepository? _explicitRepository;
  late final WasteReportRepository _cloudRepository;
  late final WasteReportRepository _demoRepository;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _explicitRepository = widget.repository;
    _cloudRepository = FirestoreWasteReportRepository();
    _demoRepository = LocalWasteReportRepository();
  }

  WasteReportRepository get _activeRepository {
    final explicit = _explicitRepository;
    if (explicit != null) return explicit;
    if (_authService.isDemoMode) return _demoRepository;
    return _cloudRepository;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        final repository = _activeRepository;
        return MaterialApp(
          title: 'Smart Waste Collection Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: _authService.isAuthenticated
              ? MainNavigationShell(
                  user: _authService.currentUser!,
                  authService: _authService,
                  repository: repository,
                )
              : LoginScreen(
                  authService: _authService,
                  onAuthenticated: () => setState(() {}),
                ),
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final AppUser user;
  final AuthService authService;
  final WasteReportRepository repository;

  const MainNavigationShell({
    super.key,
    required this.user,
    required this.authService,
    required this.repository,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // Define navigation destinations based on user role
    final List<Widget> pages;
    final List<NavigationDestination> destinations;

    if (user.isWorker) {
      pages = [
        WorkerDashboard(user: user, repository: widget.repository),
        const EcoTipsScreen(),
        ProfileScreen(
          user: user,
          authService: widget.authService,
          repository: widget.repository,
          onRoleSwitched: () => setState(() {}),
        ),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.engineering_outlined),
          selectedIcon: Icon(Icons.engineering),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(Icons.lightbulb_outline),
          selectedIcon: Icon(Icons.lightbulb),
          label: 'Eco Tips',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else if (user.isAdmin) {
      pages = [
        AdminDashboard(user: user, repository: widget.repository),
        ResidentReportsScreen(user: user, repository: widget.repository),
        const EcoTipsScreen(),
        ProfileScreen(
          user: user,
          authService: widget.authService,
          repository: widget.repository,
          onRoleSwitched: () => setState(() {}),
        ),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Console',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'All Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.lightbulb_outline),
          selectedIcon: Icon(Icons.lightbulb),
          label: 'Eco Tips',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      // Resident
      pages = [
        ResidentDashboard(
          user: user,
          repository: widget.repository,
          onViewAllReports: () => setState(() => _selectedIndex = 1),
        ),
        ResidentReportsScreen(user: user, repository: widget.repository),
        const EcoTipsScreen(),
        ProfileScreen(
          user: user,
          authService: widget.authService,
          repository: widget.repository,
          onRoleSwitched: () => setState(() {}),
        ),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.lightbulb_outline),
          selectedIcon: Icon(Icons.lightbulb),
          label: 'Eco Tips',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }

    final currentIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco, color: Color(0xFF1B5E20), size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EcoCollect',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  user.isAdmin
                      ? 'Administrator Mode'
                      : (user.isWorker
                            ? 'Field Worker Mode'
                            : 'Smart Waste Collection'),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Role Indicator Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: user.isAdmin
                  ? const Color(0xFFE3F2FD)
                  : (user.isWorker
                        ? const Color(0xFFF3E5F5)
                        : const Color(0xFFE8F5E9)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: user.isAdmin
                    ? const Color(0xFF1976D2)
                    : (user.isWorker
                          ? const Color(0xFF7B1FA2)
                          : const Color(0xFF2E7D32)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'System Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Notifications: All systems operational in sector 2.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (widget.authService.isDemoMode)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3E0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: const Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 16,
                    color: Color(0xFFE65100),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SIMULATED DEMO SANDBOX — In-memory evaluation only. Cloud Firestore writes are disabled.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(index: currentIndex, children: pages),
          ),
        ],
      ),
      floatingActionButton:
          user.isResident && (currentIndex == 0 || currentIndex == 1)
          ? FloatingActionButton.extended(
              onPressed: () => ReportWasteDialog.show(
                context,
                user: user,
                repository: widget.repository,
              ),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Report Waste'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: destinations,
      ),
    );
  }
}
