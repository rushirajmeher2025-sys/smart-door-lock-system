import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firebase_init.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/panel.dart';
import 'lock_selection_screen.dart';
import 'login_screen.dart';

/// Authentication Gate that dynamically listens to Firebase auth state changes.
/// Redirects authenticated users to the lock selection screen and unauthenticated users to Login.
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
          final Widget page;
          if (snapshot.connectionState == ConnectionState.waiting) {
            page = const _Splash(key: ValueKey('splash'));
          } else if (snapshot.data != null) {
            page = const LockSelectionScreen(key: ValueKey('locks'));
          } else {
            page = const LoginScreen(key: ValueKey('login'));
          }
          return AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: page);
        },
      );
    }

    // Fallback when demo mode is enabled
    return const LockSelectionScreen(key: ValueKey('demo_locks'));
  }

  Widget _buildFirebaseConfigPrompt(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        tint: AppColors.brand,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Reveal(child: Center(child: BrandMark(size: 34))),
                    const SizedBox(height: 40),
                    Reveal(
                      delay: const Duration(milliseconds: 80),
                      child: Text('SETUP', textAlign: TextAlign.center, style: AppTheme.label()),
                    ),
                    const SizedBox(height: 8),
                    Reveal(
                      delay: const Duration(milliseconds: 120),
                      child: Text(
                        'Connect LocKify\nto the cloud',
                        textAlign: TextAlign.center,
                        style: AppTheme.display(fontSize: 30, height: 1.1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Reveal(
                      delay: Duration(milliseconds: 160),
                      child: Text(
                        'This build isn’t linked to a Firebase project yet. Link it once and the app talks to your real lock.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Reveal(
                      delay: const Duration(milliseconds: 220),
                      child: Panel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _buildStepRow('01', 'Sign in to Firebase', 'npx firebase-tools login'),
                            const SizedBox(height: 16),
                            _buildStepRow('02', 'Generate the config (in mobile_app/)', 'flutterfire configure'),
                            const SizedBox(height: 16),
                            _buildStepRow('03', 'Turn on Email/Password sign-in', 'Console › Authentication › Sign-in method'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Reveal(
                      delay: const Duration(milliseconds: 280),
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: () => setState(() => _bypassedForDemo = true),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Explore the demo'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Demo mode simulates the lock so every screen works without hardware.',
                      textAlign: TextAlign.center,
                      style: AppTheme.mono(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
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
        Text(number, style: AppTheme.mono(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w600)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(code, style: AppTheme.mono(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LockifyLogo(size: 56),
              const SizedBox(height: 18),
              Text(AppConstants.appName.toUpperCase(), style: AppTheme.label()),
            ],
          ),
        ),
      ),
    );
  }
}
