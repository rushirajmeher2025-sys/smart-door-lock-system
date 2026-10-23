import 'package:firebase_auth/firebase_auth.dart';

/// Production-ready Firebase Authentication Service.
/// Encapsulates authentication workflows, error mapping, and session state.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Stream of user authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently authenticated user, or null if unauthenticated
  User? get currentUser => _auth.currentUser;

  /// Whether a user is currently signed in
  bool get isAuthenticated => currentUser != null;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException('An unexpected error occurred during sign-in: ${e.toString()}');
    }
  }

  /// Register a new account with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException('An unexpected error occurred during registration: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      throw AuthException('Failed to send password reset email: ${e.toString()}');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out cleanly: ${e.toString()}');
    }
  }

  /// Maps Firebase error codes to user-friendly security messages
  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password. Please check your credentials.';
      case 'invalid-email':
        return 'The email address is improperly formatted.';
      case 'user-disabled':
        return 'This security access account has been disabled. Please contact the administrator.';
      case 'email-already-in-use':
        return 'An account already exists with this email address. Please sign in instead.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console. Please enable it under Authentication > Sign-in method.';
      case 'too-many-requests':
        return 'Access to this account has been temporarily disabled due to many failed login attempts. Try again later.';
      case 'network-request-failed':
        return 'Network connection failed. Please verify your internet connection.';
      default:
        return e.message ?? 'An authentication error occurred (${e.code}).';
    }
  }
}

/// Custom domain exception for authentication errors
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
