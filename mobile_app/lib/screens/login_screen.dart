import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firebase_init.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/backdrop.dart';
import '../widgets/brand_mark.dart';
import '../widgets/panel.dart';
import '../widgets/segment_toggle.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (FirebaseInitService.isConfigured) {
        if (_isRegisterMode) {
          await AuthService.instance.registerWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
        } else {
          await AuthService.instance.signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppConstants.routeHome);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    bool isResetting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reset password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter your email and we’ll send you a link to reset your password.'),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        if (email.isEmpty || !email.contains('@')) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Enter a valid email address.')),
                          );
                          return;
                        }

                        setDialogState(() => isResetting = true);
                        final navigator = Navigator.of(ctx);

                        try {
                          if (FirebaseInitService.isConfigured) {
                            await AuthService.instance.sendPasswordResetEmail(email);
                          } else {
                            await Future.delayed(const Duration(milliseconds: 600));
                          }
                          if (!mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text('Reset link sent to $email')),
                          );
                        } on AuthException catch (e) {
                          setDialogState(() => isResetting = false);
                          messenger.showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      },
                child: isResetting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send link'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demo = !FirebaseInitService.isConfigured;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        tint: AppColors.brand,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Reveal(child: Center(child: LockifyLogo(size: 64))),
                      const SizedBox(height: 22),
                      const Reveal(
                        delay: Duration(milliseconds: 80),
                        child: Center(child: LockifyWordmark(fontSize: 34)),
                      ),
                      const SizedBox(height: 8),
                      Reveal(
                        delay: const Duration(milliseconds: 140),
                        child: Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Reveal(
                        delay: const Duration(milliseconds: 220),
                        child: Panel(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentToggle(
                                labels: const ['Sign in', 'Create account'],
                                index: _isRegisterMode ? 1 : 0,
                                onChanged: (i) => setState(() {
                                  _isRegisterMode = i == 1;
                                  _errorMessage = null;
                                }),
                              ),
                              const SizedBox(height: 20),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                child: _errorMessage == null
                                    ? const SizedBox(width: double.infinity)
                                    : Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.alarm.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.alarm.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: AppColors.alarm, size: 18),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter your email address.';
                                  if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email address.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: _isRegisterMode ? TextInputAction.next : TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) {
                                  if (!_isRegisterMode && !_isLoading) _submitAuth();
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Enter your password.';
                                  if (val.length < 6) return 'Use at least 6 characters.';
                                  return null;
                                },
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: _isRegisterMode
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                                        child: TextFormField(
                                          controller: _confirmPasswordController,
                                          obscureText: _obscureConfirmPassword,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                            labelText: 'Confirm password',
                                            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                                            suffixIcon: IconButton(
                                              tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                                              icon: Icon(
                                                _obscureConfirmPassword
                                                    ? Icons.visibility_outlined
                                                    : Icons.visibility_off_outlined,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                            ),
                                          ),
                                          validator: (val) {
                                            if (!_isRegisterMode) return null;
                                            if (val != _passwordController.text) return 'Passwords don’t match.';
                                            return null;
                                          },
                                        ),
                                      )
                                    : Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: TextButton(
                                            onPressed: _showForgotPasswordDialog,
                                            child: const Text('Forgot password?'),
                                          ),
                                        ),
                                      ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                                onPressed: _isLoading ? null : _submitAuth,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.background),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_isRegisterMode ? 'Create account' : 'Sign in'),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward_rounded, size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Reveal(
                        delay: const Duration(milliseconds: 300),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              demo ? Icons.science_outlined : Icons.shield_outlined,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                demo
                                    ? 'Demo mode · any email and a 6+ character password'
                                    : FirebaseInitService.usingEmulator
                                        ? 'Local emulator · ${FirebaseInitService.emulatorHost}'
                                        : 'Secured by Firebase Authentication',
                                textAlign: TextAlign.center,
                                style: AppTheme.mono(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
