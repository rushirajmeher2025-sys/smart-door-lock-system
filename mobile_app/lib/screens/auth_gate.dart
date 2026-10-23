import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firebase_init.dart';
import '../theme/app_colors.dart';
import '../widgets/app_loading_indicator.dart';
import 'login_screen.dart';
import 'main_nav_screen.dart';

/// Authentication Gate that dynamically listens to Firebase auth state changes.
/// Redirects authenticated users to the dashboard and unauthenticated users to Login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _bypassedForDemo = false;

  @override
  Widget build(BuildContext context) {
    // If Firebase project credentials are not yet configured on this machine
    if (!FirebaseInitService.isConfigured && !_bypassedForDemo) {
      return _buildFirebaseConfigPrompt(context);
    }

    // When Firebase is configured, listen to real-time auth state
    if (FirebaseInitService.isConfigured) {
      return StreamBuilder<User?>(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: AppLoadingIndicator(message: 'Verifying security credentials...'),
            );
          }

          final user = snapshot.data;
          if (user != null) {
            return const MainNavScreen();
          }

          return const LoginScreen();
        },
      );
    }

    // Fallback when demo mode is enabled
    return const LoginScreen();
  }

  Widget _buildFirebaseConfigPrompt(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.warning, width: 2),
                  ),
                  child: const Icon(
                    Icons.cloud_sync_outlined,
                    color: AppColors.warning,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Firebase Setup Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'To enable live cloud authentication, your Firebase project needs to be linked with FlutterFire.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Step-by-step instructions card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONFIGURATION STEPS:',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildStepRow(
                        '1',
                        'Login to Firebase in terminal:',
                        'npx -y firebase-tools login',
                      ),
                      const SizedBox(height: 12),
                      _buildStepRow(
                        '2',
                        'Generate configuration files:',
                        'flutterfire configure',
                      ),
                      const SizedBox(height: 12),
                      _buildStepRow(
                        '3',
                        'Enable Email/Password sign-in:',
                        'Firebase Console > Auth > Sign-in method',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Button to proceed in local demo mode
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _bypassedForDemo = true;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Continue in Demo / UI Mode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'All UI validation, screens, and error handlers remain fully functional.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String code) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.accent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
