import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/constants/app_constants.dart';
import 'package:smart_waste_collection_manager/features/auth/login_screen.dart';
import 'package:smart_waste_collection_manager/features/auth/register_screen.dart';
import 'package:smart_waste_collection_manager/features/auth/role_selection_screen.dart';
import 'package:smart_waste_collection_manager/main.dart';
import 'package:smart_waste_collection_manager/repositories/waste_report_repository.dart';
import 'package:smart_waste_collection_manager/services/auth_service.dart';

void main() {
  group('RoleSelectionScreen & Portal Navigation Tests', () {
    testWidgets('RoleSelectionScreen displays all 3 portals and demo sandbox banner', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: RoleSelectionScreen(
            authService: authService,
            onAuthenticated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header Branding
      expect(find.text('EcoCollect'), findsWidgets);
      expect(find.text('Select Your Portal'), findsOneWidget);

      // Verify all 3 role portal cards exist
      expect(find.text('Resident Portal'), findsOneWidget);
      expect(find.text('Field Operations Portal'), findsOneWidget);
      expect(find.text('Municipal Governance Portal'), findsOneWidget);

      // Verify portal badges
      expect(find.text('Public Citizen Access'), findsOneWidget);
      expect(find.text('Authorized Staff Only'), findsOneWidget);
      expect(find.text('Restricted Administration'), findsOneWidget);

      // Verify Demo Sandbox section is present and explicitly labeled
      expect(find.text('Demo Sandbox — Offline Simulation'), findsOneWidget);
      expect(
        find.textContaining('Simulated data is strictly local'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Resident portal opens LoginScreen with registration option and Change role button', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: RoleSelectionScreen(
            authService: authService,
            onAuthenticated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Resident Portal card
      await tester.tap(find.text('Resident Portal'));
      await tester.pumpAndSettle();

      // Verify LoginScreen is shown
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Resident Portal'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);

      // Change role back-navigation tooltip button exists
      final changeRoleBtn = find.byTooltip('Change role');
      expect(changeRoleBtn, findsOneWidget);

      // Registration is available for Resident
      expect(find.text('Register'), findsOneWidget);
      expect(find.textContaining("Don't have an account"), findsOneWidget);

      // Tapping Change role navigates back to RoleSelectionScreen
      await tester.tap(changeRoleBtn);
      await tester.pumpAndSettle();
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });

    testWidgets('Tapping Worker portal opens LoginScreen with staff notice and NO registration link', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: RoleSelectionScreen(
            authService: authService,
            onAuthenticated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Field Operations Portal card
      await tester.tap(find.text('Field Operations Portal'));
      await tester.pumpAndSettle();

      // Verify LoginScreen opens with Worker context
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Field Operations Portal'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(
        find.textContaining('Staff and administrator accounts are provisioned exclusively'),
        findsOneWidget,
      );

      // Public registration must NOT be available
      expect(find.text('Register'), findsNothing);
      expect(find.textContaining("Don't have an account"), findsNothing);
    });

    testWidgets('Tapping Admin portal opens LoginScreen with admin notice and NO registration link', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: RoleSelectionScreen(
            authService: authService,
            onAuthenticated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Municipal Governance Portal card
      await tester.tap(find.text('Municipal Governance Portal'));
      await tester.pumpAndSettle();

      // Verify LoginScreen opens with Admin context
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Municipal Admin Portal'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(
        find.textContaining('Self-registration is disabled for privileged portals'),
        findsOneWidget,
      );

      // Public registration must NOT be available
      expect(find.text('Register'), findsNothing);
      expect(find.textContaining("Don't have an account"), findsNothing);
    });

    testWidgets('Sign-in passes selectedRole as expectedRole and rejects mismatch without dashboard access', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Authenticator returns valid credentials, but profile fetcher returns Resident
      final authService = AuthService(
        authenticator: (email, pass) async => 'uid-resident-123',
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
          'email': 'sujitha@ecocollect.org',
          'displayName': 'Sujitha',
        },
        claimsFetcher: (u) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: authService,
            selectedRole: AppConstants.roleWorker, // Expecting Worker portal!
            onAuthenticated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'sujitha@ecocollect.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'validpassword123',
      );

      // Tap Sign In button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify clear role-mismatch error snackbar displays
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Access denied. Your account is registered as a Resident'),
        findsOneWidget,
      );

      // User remains unauthenticated and still on LoginScreen (NO dashboard access)
      expect(authService.isAuthenticated, false);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('SmartWasteApp displays verifying spinner while restored session is in-flight', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      final repository = LocalWasteReportRepository();

      // Manually set verifying restored session flag on authService
      authService.setVerifyingRestoredSessionForTest(true);

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pump();

      // Shows verification spinner and text
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Verifying EcoCollect session...'),
        findsOneWidget,
      );

      // Finish verification
      authService.setVerifyingRestoredSessionForTest(false);
      await tester.pumpAndSettle();

      // Resolves to RoleSelectionScreen (since no user authenticated)
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });

    testWidgets('Demo Sandbox buttons in RoleSelectionScreen launch simulated roles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService();
      final repository = LocalWasteReportRepository();

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      // Click Demo Worker button in RoleSelectionScreen
      final demoWorkerBtn = find.widgetWithText(OutlinedButton, 'Demo Worker');
      expect(demoWorkerBtn, findsOneWidget);
      await tester.ensureVisible(demoWorkerBtn);
      await tester.tap(demoWorkerBtn);
      await tester.pumpAndSettle();

      // Directly lands on worker dashboard in simulated sandbox
      expect(find.text('Field Worker Mode'), findsOneWidget);
      expect(find.text('WORKER'), findsOneWidget);
      expect(find.textContaining('SIMULATED DEMO SANDBOX'), findsOneWidget);
    });

    testWidgets('Successful resident sign-in opens Resident Dashboard immediately without refresh', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService(
        authenticator: (email, pass) async => 'resident-test-uid-1',
        profileFetcher: (uid) async => {
          'role': AppConstants.roleResident,
          'email': 'resident@ecocollect.org',
          'displayName': 'Alice Resident',
        },
      );
      final repository = LocalWasteReportRepository();

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      // Verify on RoleSelectionScreen initially
      expect(find.byType(RoleSelectionScreen), findsOneWidget);

      // Tap Resident Portal card
      await tester.tap(find.text('Resident Portal'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // Enter valid resident credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'resident@ecocollect.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      // Tap Sign In
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // LoginScreen must be popped immediately; Resident Dashboard must be visible
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Your Waste Overview'), findsOneWidget);
      expect(find.text('Hello, Eco Champion!'), findsOneWidget);
      expect(find.text('resident'), findsOneWidget);
      expect(authService.isAuthenticated, isTrue);
    });

    testWidgets('Invalid credentials remain on LoginScreen and show error snackbar', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService(
        authenticator: (email, pass) async => throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'The email address or password entered is incorrect.',
        ),
      );
      final repository = LocalWasteReportRepository();

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      // Tap Resident Portal
      await tester.tap(find.text('Resident Portal'));
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'wrong@ecocollect.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrongpassword',
      );

      // Tap Sign In
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verifications: Error snackbar visible, LoginScreen remains, NO dashboard
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Your Waste Overview'), findsNothing);
      expect(authService.isAuthenticated, isFalse);
    });

    testWidgets('Missing profile remains blocked and keeps user on LoginScreen with support message', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService(
        authenticator: (email, pass) async => 'orphaned-uid-999',
        profileFetcher: (uid) async => null, // Genuinely nonexistent document
      );
      final repository = LocalWasteReportRepository();

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resident Portal'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'orphaned@ecocollect.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Account profile not found in EcoCollect database'),
        findsOneWidget,
      );
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Your Waste Overview'), findsNothing);
      expect(authService.isAuthenticated, isFalse);
    });

    testWidgets('Successful resident registration dismisses all auth routes and opens Resident Dashboard', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService(
        registrationCreator: (email, pass, name) async => 'new-resident-uid-42',
        profileWriter: (uid, data) async {},
      );
      final repository = LocalWasteReportRepository();

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      // Open Resident Portal -> LoginScreen
      await tester.tap(find.text('Resident Portal'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // Open RegisterScreen
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);

      // Fill out registration form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Bob Newbie',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'bob.newbie@ecocollect.org',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password (min 6 characters)'),
        'securePass123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'securePass123',
      );

      // Submit registration
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Both RegisterScreen and LoginScreen must be dismissed; Dashboard must open directly
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Your Waste Overview'), findsOneWidget);
      expect(find.text('Hello, Eco Champion!'), findsOneWidget);
      expect(find.text('Bob Newbie'), findsOneWidget);
      expect(authService.isAuthenticated, isTrue);
    });

    testWidgets('Restored authenticated session renders MainNavigationShell directly on boot', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = AuthService()
        ..enterDemoMode(AppConstants.roleResident);
      final repository = LocalWasteReportRepository();

      await tester.pumpWidget(
        SmartWasteApp(authService: authService, repository: repository),
      );
      await tester.pumpAndSettle();

      // Renders dashboard directly; no LoginScreen or RoleSelectionScreen
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(RoleSelectionScreen), findsNothing);
      expect(find.text('Your Waste Overview'), findsOneWidget);
      expect(find.text('Hello, Eco Champion!'), findsOneWidget);
      expect(find.textContaining('Sujitha'), findsOneWidget);
    });
  });
}
