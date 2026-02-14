import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/loading_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/recording/recording_screen.dart';
import '../screens/recording/start_session_screen.dart';
import '../../domain/entities/session_start_config.dart';
import '../screens/recordings/recordings_list_screen.dart';
import '../screens/recordings/recording_details_screen.dart';
import '../providers/auth_provider.dart';
import '../../core/utils/logger.dart';

// Create a ValueNotifier that tracks auth state for router refresh
final authStateNotifierProvider = Provider<ValueNotifier<RouterAuthState>>((ref) {
  final notifier = ValueNotifier<RouterAuthState>(const RouterAuthState(isChecking: true));
  
  // Watch auth state changes
  ref.listen<AuthState>(currentUserProvider, (previous, next) {
    notifier.value = RouterAuthState(
      isChecking: next.isChecking,
      isAuthenticated: next.user != null,
    );
    AppLogger.i('Auth state updated: checking=${next.isChecking}, authenticated=${next.user != null}');
  });
  
  return notifier;
});

// Router-specific AuthState for refreshListenable
class RouterAuthState {
  final bool isChecking;
  final bool isAuthenticated;
  
  const RouterAuthState({
    required this.isChecking,
    this.isAuthenticated = false,
  });
}

final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state - router will rebuild when these change
  final isCheckingAuth = ref.watch(isCheckingAuthProvider);
  final isAuth = ref.watch(isAuthenticatedProvider);
  final isEmailVerified = ref.watch(isEmailVerifiedProvider);
  final authStateNotifier = ref.watch(authStateNotifierProvider);
  
  // Determine initial location based on auth status
  final initialLocation = isCheckingAuth 
      ? '/loading' // Show loading while checking auth
      : (isAuth 
          ? (isEmailVerified ? '/home' : '/verify-email')
          : '/login');

  final router = GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authStateNotifier,
    redirect: (context, state) {
      // Read current state (not watch, to avoid rebuild loops)
      final currentlyChecking = ref.read(isCheckingAuthProvider);
      final currentlyAuthenticated = ref.read(isAuthenticatedProvider);
      final currentlyEmailVerified = ref.read(isEmailVerifiedProvider);
      final authState = ref.read(currentUserProvider);
      
      AppLogger.d('Router redirect called: checking=$currentlyChecking, auth=$currentlyAuthenticated, verified=$currentlyEmailVerified, location=${state.matchedLocation}');
      
      // If still checking auth, show loading screen
      if (currentlyChecking && state.matchedLocation != '/loading') {
        AppLogger.d('Redirecting to /loading (auth check in progress)');
        return '/loading';
      }

      // Once auth check is complete, handle redirects
      if (!currentlyChecking) {
        final isLoginRoute = state.matchedLocation == '/login' || 
                            state.matchedLocation == '/signup';
        final isVerifyEmailRoute = state.matchedLocation == '/verify-email';
        final isProtectedRoute = !isLoginRoute && !isVerifyEmailRoute && state.matchedLocation != '/loading';

        // If on loading screen and auth check is done, redirect appropriately
        if (state.matchedLocation == '/loading') {
          if (!currentlyAuthenticated) {
            AppLogger.d('Redirecting from /loading to /login (not authenticated)');
            return '/login';
          } else if (!currentlyEmailVerified) {
            AppLogger.d('Redirecting from /loading to /verify-email (not verified)');
            return '/verify-email';
          } else {
            AppLogger.d('Redirecting from /loading to /home (authenticated and verified)');
            return '/home';
          }
        }

        // If not authenticated and trying to access protected route
        if (!currentlyAuthenticated && isProtectedRoute) {
          AppLogger.d('Redirecting to /login (not authenticated)');
          return '/login';
        }

        // If authenticated but not verified, redirect to verify-email (unless already there)
        if (currentlyAuthenticated && !currentlyEmailVerified && !isVerifyEmailRoute) {
          // Allow access to verify-email route, but redirect protected routes
          if (isProtectedRoute) {
            AppLogger.d('Redirecting to /verify-email (authenticated but not verified)');
            // Get email from user state if available
            final email = authState.user?.email ?? '';
            return '/verify-email${email.isNotEmpty ? '?email=$email' : ''}';
          }
        }

        // If authenticated and verified, redirect away from login/signup/verify-email
        if (currentlyAuthenticated && currentlyEmailVerified && (isLoginRoute || isVerifyEmailRoute)) {
          AppLogger.d('Redirecting to /home (authenticated and verified)');
          return '/home';
        }

        // If authenticated but not verified and trying to access login/signup
        if (currentlyAuthenticated && !currentlyEmailVerified && isLoginRoute) {
          AppLogger.d('Redirecting to /verify-email (authenticated but not verified)');
          final email = authState.user?.email ?? '';
          return '/verify-email${email.isNotEmpty ? '?email=$email' : ''}';
        }
      }

      AppLogger.d('No redirect needed');
      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/loading',
        name: 'loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const AuthScreen(initialTab: AuthTab.login),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const AuthScreen(initialTab: AuthTab.signup),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          // Try to get email from extra first, then from query params
          final email = (state.extra as String?) ?? 
                       (state.uri.queryParameters['email'] ?? '');
          return VerifyEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/start-session',
        name: 'start-session',
        builder: (context, state) => const StartSessionScreen(),
      ),
      GoRoute(
        path: '/recording',
        name: 'recording',
        builder: (context, state) {
          final config = state.extra as SessionStartConfig?;
          return RecordingScreen(startConfig: config);
        },
      ),
      GoRoute(
        path: '/recordings',
        name: 'recordings',
        builder: (context, state) => const RecordingsListScreen(),
      ),
      GoRoute(
        path: '/recordings/:sessionId',
        name: 'recording_details',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return RecordingDetailsScreen(sessionId: sessionId);
        },
      ),
    ],
  );

  return router;
});
