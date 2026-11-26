import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/auth/ui/splash_screen.dart';
import '../../features/auth/ui/verify_email_screen.dart';
import '../../features/chat/ui/conversation_screen.dart';
import '../../features/matching/ui/match_detail_screen.dart';
import '../../features/matching/ui/roommates_screen.dart';
import '../../features/notifications/ui/notifications_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/search_tab.dart';
import '../../features/home/post_tab.dart';
import '../../features/home/chat_tab.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/profile/ui/edit_profile_screen.dart';
import '../../features/profile/ui/preferences_screen.dart';
import '../../features/profile/ui/settings_screen.dart';
import '../widgets/main_scaffold.dart';
import '../../features/housing/ui/listing_details_screen.dart';
import '../../features/housing/ui/edit_listing_screen.dart';
import '../../features/housing/models/listing.dart';

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);

  late final GoRouter router;
  // A new account opens the profile setup ON TOP of the home screen (push), so Back returns to the
  // app. Redirecting straight to /profile/edit closed the app on Back (Android 16 predictive back).
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.status == AuthStatus.authenticated &&
        next.isNewAccount &&
        previous?.status != AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => router.push('/profile/edit'));
    }
  });

  return router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,

    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      if (auth.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      // Screens reachable without being logged in to the API
      const publicRoutes = ['/login', '/register', '/verify-email'];
      final onAuthRoute = publicRoutes.contains(loc) || loc == '/splash';

      if (auth.status == AuthStatus.unauthenticated) {
        return publicRoutes.contains(loc) ? null : '/login';
      }

      // Just logged in: home (a new account then gets the profile setup on top, see above)
      if (onAuthRoute) return '/';
      return null;
    },

    routes: [
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // ---- Tabs shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 1: Search
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                name: 'search',
                builder: (_, __) => const SearchTab(),
              ),
            ],
          ),

          // Tab 2: Post
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/post',
                name: 'post',
                builder: (_, __) => const PostTab(),
              ),
            ],
          ),

          // Tab 3: Chat
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                name: 'chat',
                // /chat?tab=messages|requests|sent (used by notification taps)
                builder: (_, state) => ChatTab(initialTab: state.uri.queryParameters['tab']),
              ),
            ],
          ),

          // Tab 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (_, __) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'profile-edit',
                    builder: (_, __) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'preferences',
                    name: 'profile-preferences',
                    builder: (_, __) => const PreferencesScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'profile-settings',
                    builder: (_, __) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

     GoRoute(
        path: '/listing/:id/edit',
        builder: (context, state) {
          final listing = state.extra as HousingListing;
          return EditListingScreen(listing: listing);
        },
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ListingDetailsScreen(listingId: id);
        },
      ),

      // ---- Sprint 3: notifications, chat, roommates ----
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/conversation/:id',
        name: 'conversation',
        builder: (_, state) => ConversationScreen(
          conversationId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/roommates',
        name: 'roommates',
        builder: (_, __) => const RoommatesScreen(),
      ),
      GoRoute(
        path: '/roommates/:userId',
        name: 'roommate-detail',
        builder: (_, state) => MatchDetailScreen(
          userId: int.parse(state.pathParameters['userId']!),
        ),
      ),
    ],
  );
});