import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../services/network/api_client.dart';
import '../../core/utils/logger.dart';

// Auth State class that includes both user and checking status
class AuthState extends Equatable {
  final User? user;
  final bool isChecking;

  const AuthState({
    this.user,
    this.isChecking = false,
  });

  AuthState copyWith({
    User? user,
    bool? isChecking,
  }) {
    return AuthState(
      user: user ?? this.user,
      isChecking: isChecking ?? this.isChecking,
    );
  }

  @override
  List<Object?> get props => [user, isChecking];
}

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

// Current User Provider (State)
final currentUserProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState(isChecking: true)) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      state = state.copyWith(isChecking: true);
      AppLogger.i('Checking authentication status...');
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        AppLogger.i('User is authenticated, loading user data...');
        final user = await _authRepository.getCurrentUser();
        state = AuthState(user: user, isChecking: false);
        AppLogger.i('User loaded: ${user?.email ?? "unknown"}');
      } else {
        AppLogger.i('User is not authenticated');
        state = const AuthState(user: null, isChecking: false);
      }
    } catch (e) {
      AppLogger.e('Error checking auth status', e);
      state = const AuthState(user: null, isChecking: false);
    } finally {
      AppLogger.i('Auth check complete');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      AppLogger.i('Starting login for: $email');
      final user = await _authRepository.login(email, password);
      AppLogger.i('Login successful, user ID: ${user.id}');
      
      // Ensure state is updated with the new user
      state = AuthState(user: user, isChecking: false);
      AppLogger.i('User state updated in AuthNotifier');
      
      // Verify tokens were stored
      final token = await _authRepository.getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.e('Token verification failed - token is null or empty', null);
        throw Exception('Failed to store authentication token');
      }
      AppLogger.i('Token verified successfully, length: ${token.length}');
      AppLogger.i('Login complete, user is authenticated. User ID: ${user.id}');
      
      return true;
    } catch (e) {
      AppLogger.e('Login failed', e);
      state = const AuthState(user: null, isChecking: false);
      rethrow;
    }
  }

  Future<bool> signUp(String firstName, String lastName, String email, String password) async {
    try {
      AppLogger.i('Starting signup for: $email');
      final user = await _authRepository.signUp(firstName, lastName, email, password);
      AppLogger.i('Signup successful, user ID: ${user.id}');
      
      // Ensure state is updated with the new user
      state = AuthState(user: user, isChecking: false);
      AppLogger.i('User state updated in AuthNotifier');
      
      // Verify tokens were stored
      final token = await _authRepository.getAuthToken();
      if (token == null || token.isEmpty) {
        AppLogger.e('Token verification failed - token is null or empty', null);
        throw Exception('Failed to store authentication token');
      }
      AppLogger.i('Token verified successfully, length: ${token.length}');
      AppLogger.i('Signup complete, user is authenticated. User ID: ${user.id}');
      
      return true;
    } catch (e) {
      AppLogger.e('Signup failed', e);
      state = const AuthState(user: null, isChecking: false);
      rethrow;
    }
  }

  Future<void> verifyEmail(String code) async {
    try {
      AppLogger.i('Verifying email with code');
      final user = await _authRepository.verifyEmail(code);
      AppLogger.i('Email verified successfully');
      
      // Update state with verified user
      state = AuthState(user: user, isChecking: false);
    } catch (e) {
      AppLogger.e('Email verification failed', e);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState(user: null, isChecking: false);
  }

  Future<void> refreshUser() async {
    final user = await _authRepository.getCurrentUser();
    state = state.copyWith(user: user);
  }

  Future<String?> getAuthToken() async {
    return await _authRepository.getAuthToken();
  }
}

// Is Authenticated Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentUserProvider);
  return authState.user != null;
});

// Is Checking Auth Provider
final isCheckingAuthProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentUserProvider);
  return authState.isChecking;
});

// Email Verified Provider
final isEmailVerifiedProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentUserProvider);
  return authState.user?.emailVerified ?? false;
});
