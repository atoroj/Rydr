import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/rides/presentation/home_screen.dart';
import '../../features/rides/presentation/rides_history_screen.dart';
import '../../features/routes/presentation/routes_screen.dart';
import '../../features/motorbikes/presentation/motorbikes_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../../shared/models/user_model.dart';

// ─── Notifier que dispara al router cuando cambia la sesión ──────────────────

/// Escucha authProvider y notifica al GoRouter para que re-evalúe los redirects.
/// Sin esto el router no sabe cuándo el usuario hace login/logout.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<UserModel?>>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;

  /// Lógica de redirección centralizada.
  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggedIn = authState.value != null;
    final isGoingToLogin = state.matchedLocation == '/login';

    if (authState.isLoading) return null;
    if (!isLoggedIn && !isGoingToLogin) return '/login';
    if (isLoggedIn && isGoingToLogin) return '/';
    return null;
  }
}

// ─── Router ──────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,   // re-evalúa redirect al cambiar auth
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, routerState, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/routes',
            builder: (context, state) => const RoutesScreen(),
          ),
          GoRoute(
            path: '/motorbikes',
            builder: (context, state) => const MotorbikesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/rides',
        builder: (context, state) => const RidesHistoryScreen(),
      ),
    ],
  );
});

// ─── Shell con navegación inferior (4 tabs) ───────────────────────────────────

class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});
  final Widget child;

  static const _tabs = ['/', '/routes', '/motorbikes', '/profile'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexOf(location).clamp(0, _tabs.length - 1);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Rutas',
          ),
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Mis motos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
