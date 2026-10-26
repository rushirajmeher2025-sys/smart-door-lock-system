import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';

/// Service managing biometric (fingerprint/face scan) and device credential authentication.
/// Includes seamless fallback to password verification for platforms/browsers without biometrics.
class BiometricService {
  BiometricService._internal();
  static final BiometricService instance = BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the hardware supports biometrics
  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Request biometric or device credential authentication.
  /// If unavailable or on Web, falls back to re-authenticating with the user's password.
  Future<bool> authenticateWithFallback({
    required BuildContext context,
    required String reason,
  }) async {
    final hasBiometrics = await canAuthenticate();

    if (hasBiometrics) {
      try {
        final didAuth = await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
        if (didAuth) return true;
      } catch (e) {
        if (kDebugMode) print('[BIOMETRIC] Failed: $e');
      }
    }

    // Fallback: Verify account password via dialog
    if (context.mounted) {
      return await _promptPasswordVerification(context, reason);
    }
    return false;
  }

  Future<bool> _promptPasswordVerification(BuildContext context, String reason) async {
    final controller = TextEditingController();
    bool obscure = true;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 22),
              SizedBox(width: 10),
              Text('Security Verification'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reason,
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Account Password',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pwd = controller.text.trim();
                if (pwd.isEmpty) {
                  setState(() => errorText = 'Enter your password');
                  return;
                }
                final email = AuthService.instance.currentUser?.email;
                if (email == null) {
                  Navigator.of(ctx).pop(false);
                  return;
                }
                try {
                  await AuthService.instance.signInWithEmailAndPassword(
                    email: email,
                    password: pwd,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  setState(() => errorText = 'Incorrect password');
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }
}
