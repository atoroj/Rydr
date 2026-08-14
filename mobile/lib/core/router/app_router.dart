import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/register/presentation/register_screen.dart';
import '../../features/rides/presentation/rides_history_screen.dart';
import '../../features/routes/presentation/routes_screen.dart';
import '../../features/routes/presentation/my_routes_screen.dart';
import '../../features/motorbikes/presentation/motorbikes_screen.dart';
import '../../features/riders/presentation/riders_screen.dart';
import '../../features/riders/presentation/rider_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../../shared/models/user_model.dart';
import '../widgets/network_avatar.dart';

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
    if (isLoggedIn && isGoingToLogin) return '/routes';
    return null;
  }
}

// ─── Router ──────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/routes',
    refreshListenable: notifier, // re-evalúa redirect al cambiar auth
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
            path: '/routes',
            builder: (context, state) => const RoutesScreen(),
          ),
          GoRoute(
            path: '/my-routes',
            builder: (context, state) => const MyRoutesScreen(),
          ),
          GoRoute(
            path: '/motorbikes',
            builder: (context, state) => const MotorbikesScreen(),
          ),
          GoRoute(
            path: '/riders',
            builder: (context, state) => const RidersScreen(),
          ),
        ],
      ),
      // ── Fuera del shell: pantallas a pantalla completa o "de detalle",
      // sin bottom bar ni top bar del shell ────────────────────────────────
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/rides',
        builder: (context, state) => const RidesHistoryScreen(),
      ),
      GoRoute(
        path: '/riders/:id',
        builder: (context, state) => RiderProfileScreen(
          userId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});

// ─── Shell con top bar + navegación inferior de 5 destinos ──────────────────

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.child});
  final Widget child;

  // Los 4 destinos que sí son pestañas del shell (Registrar no lo es: abre
  // su propia pantalla a pantalla completa, ver botón central más abajo).
  static const _tabs = ['/routes', '/my-routes', '/motorbikes', '/riders'];
  static const _titles = ['Rutas', 'Mis Rutas', 'Mis Motos', 'Riders'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexOf(location).clamp(0, _tabs.length - 1);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_titles[currentIndex]),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.center,
            child: NetworkAvatar(
              imageUrl: user?.avatarUrl,
              fallbackName: user?.username ?? '?',
              radius: 18,
              onTap: () => context.push('/profile'),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: child,
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'register',
        tooltip: 'Registrar ruta',
        onPressed: () => context.push('/register'),
        child: const Icon(Icons.fiber_manual_record, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.route_outlined,
                    selectedIcon: Icons.route,
                    label: 'Rutas',
                    selected: currentIndex == 0,
                    onTap: () => context.go(_tabs[0]),
                  ),
                  _NavItem(
                    icon: Icons.bookmark_outline,
                    selectedIcon: Icons.bookmark,
                    label: 'Mis Rutas',
                    selected: currentIndex == 1,
                    onTap: () => context.go(_tabs[1]),
                  ),
                ],
              ),
            ),
            // Hueco para el FAB incrustado (Registrar).
            const SizedBox(width: 64),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.two_wheeler_outlined,
                    selectedIcon: Icons.two_wheeler,
                    label: 'Mis Motos',
                    selected: currentIndex == 2,
                    onTap: () => context.go(_tabs[2]),
                  ),
                  _NavItem(
                    icon: Icons.groups_outlined,
                    selectedIcon: Icons.groups,
                    label: 'Riders',
                    selected: currentIndex == 3,
                    onTap: () => context.go(_tabs[3]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de pestaña de la bottom bar. Área táctil generosa (pensada para
/// pulsarse con guantes), icono relleno cuando está seleccionada.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
