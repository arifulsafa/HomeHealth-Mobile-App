import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../services/network/api_client.dart';
import '../../core/utils/logger.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepository(this._apiClient);

  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final user = User(
          id: data['user']['id'],
          email: data['user']['email'],
          firstName: data['user']['firstName'] ?? '',
          lastName: data['user']['lastName'] ?? '',
          role: data['user']['role'],
          emailVerified: data['user']['emailVerified'] ?? false,
        );

        // Store tokens
        await _storage.write(
          key: AppConstants.keyAuthToken,
          value: data['token'],
        );
        await _storage.write(
          key: AppConstants.keyRefreshToken,
          value: data['refreshToken'],
        );
        await _storage.write(
          key: AppConstants.keyUserId,
          value: user.id,
        );
        await _storage.write(
          key: AppConstants.keyUserEmail,
          value: user.email,
        );

        AppLogger.i('User logged in: ${user.email}');
        return user;
      } else {
        throw AuthenticationFailure('Login failed');
      }
    } catch (e) {
      AppLogger.e('Login error', e);
      if (e is Failure) rethrow;
      throw AuthenticationFailure('Login failed: ${e.toString()}');
    }
  }

  Future<User> signUp(String firstName, String lastName, String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/signup',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final user = User(
          id: data['user']['id'],
          email: data['user']['email'],
          firstName: data['user']['firstName'] ?? '',
          lastName: data['user']['lastName'] ?? '',
          role: data['user']['role'] ?? 'PT',
          emailVerified: data['user']['emailVerified'] ?? false,
        );

        // Store tokens
        await _storage.write(
          key: AppConstants.keyAuthToken,
          value: data['token'],
        );
        await _storage.write(
          key: AppConstants.keyRefreshToken,
          value: data['refreshToken'],
        );
        await _storage.write(
          key: AppConstants.keyUserId,
          value: user.id,
        );
        await _storage.write(
          key: AppConstants.keyUserEmail,
          value: user.email,
        );

        AppLogger.i('User signed up: ${user.email}');
        return user;
      } else {
        throw AuthenticationFailure('Sign up failed');
      }
    } catch (e) {
      AppLogger.e('Sign up error', e);
      if (e is Failure) rethrow;
      throw AuthenticationFailure('Sign up failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (e) {
      AppLogger.e('Logout error', e);
    } finally {
      // Clear local storage
      await _storage.delete(key: AppConstants.keyAuthToken);
      await _storage.delete(key: AppConstants.keyRefreshToken);
      await _storage.delete(key: AppConstants.keyUserId);
      await _storage.delete(key: AppConstants.keyUserEmail);
    }
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: AppConstants.keyAuthToken);
  }

  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      if (response.statusCode == 200) {
        final data = response.data;
        return User(
          id: data['id'],
          email: data['email'],
          firstName: data['firstName'] ?? '',
          lastName: data['lastName'] ?? '',
          role: data['role'],
          emailVerified: data['emailVerified'] ?? false,
        );
      }
      return null;
    } catch (e) {
      AppLogger.e('Get current user error', e);
      return null;
    }
  }

  Future<User> verifyEmail(String code) async {
    try {
      final response = await _apiClient.post(
        '/auth/verify-email',
        data: {
          'code': code,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final user = User(
          id: data['user']['id'],
          email: data['user']['email'],
          firstName: data['user']['firstName'] ?? '',
          lastName: data['user']['lastName'] ?? '',
          role: data['user']['role'],
          emailVerified: data['user']['emailVerified'] ?? true,
        );

        // Update stored user email if needed
        await _storage.write(
          key: AppConstants.keyUserEmail,
          value: user.email,
        );

        AppLogger.i('Email verified for: ${user.email}');
        return user;
      } else {
        throw AuthenticationFailure('Email verification failed');
      }
    } catch (e) {
      AppLogger.e('Email verification error', e);
      if (e is Failure) rethrow;
      throw AuthenticationFailure('Email verification failed: ${e.toString()}');
    }
  }

  Future<void> resendVerificationCode(String email) async {
    try {
      final response = await _apiClient.post(
        '/auth/resend-verification',
        data: {
          'email': email,
        },
      );

      if (response.statusCode != 200) {
        throw AuthenticationFailure('Failed to resend verification code');
      }

      AppLogger.i('Verification code resent to: $email');
    } catch (e) {
      AppLogger.e('Resend verification code error', e);
      if (e is Failure) rethrow;
      throw AuthenticationFailure('Failed to resend verification code: ${e.toString()}');
    }
  }
}
