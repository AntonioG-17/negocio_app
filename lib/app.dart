import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/admin/screens/admin_panel_screen.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/auth/screens/business_select_screen.dart';
import 'package:negocio_app/features/auth/screens/login_screen.dart';
import 'package:negocio_app/features/ceo/screens/ceo_screen.dart';
import 'package:negocio_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:negocio_app/features/fiados/screens/client_detail_screen.dart';
import 'package:negocio_app/features/fiados/screens/fiados_screen.dart';
import 'package:negocio_app/features/inventory/screens/inventory_screen.dart';
import 'package:negocio_app/features/inventory/screens/product_form_screen.dart';
import 'package:negocio_app/features/pos/screens/checkout_screen.dart';
import 'package:negocio_app/features/pos/screens/pos_screen.dart';
import 'package:negocio_app/features/reports/screens/reports_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final selectedBusiness = ref.watch(selectedBusinessProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final path = state.matchedLocation;

      if (!isLoggedIn) {
        return path != '/login' ? '/login' : null;
      }

      // Esperar que cargue el perfil
      if (userProfile.isLoading) return null;

      final role = userProfile.valueOrNull?.role;

      // CEO: siempre al panel CEO
      if (role == UserRole.ceo) {
        const ceoAllowed = ['/ceo'];
        if (!ceoAllowed.any((r) => path.startsWith(r))) return '/ceo';
        return null;
      }

      // Trabajador desactivado: cerrar sesión y mandar al login
      final profile = userProfile.valueOrNull;
      if (profile != null && profile.role == UserRole.worker && !profile.isActive) {
        Future.microtask(() => ref.read(authNotifierProvider.notifier).logout());
        return '/login';
      }

      final hasBusiness = selectedBusiness != null;

      if (hasBusiness) {
        if (path == '/login' || path == '/select-business') {
          return '/dashboard';
        }
        // Trabajadores no pueden acceder a estas rutas
        if (role == UserRole.worker) {
          const forbidden = ['/fiados', '/reports', '/admin-panel'];
          if (forbidden.any((r) => path.startsWith(r))) return '/dashboard';
          // Pueden ver inventario pero no agregar/editar productos
          if (path.startsWith('/inventory/add') || path.startsWith('/inventory/edit')) {
            return '/inventory';
          }
        }
        return null;
      }

      // Sin negocio cargado → pantalla de selección (legacy/fallback)
      if (path != '/select-business') return '/select-business';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/select-business', builder: (_, _) => const BusinessSelectScreen()),
      GoRoute(path: '/ceo', builder: (_, _) => const CeoScreen()),
      // Fuera del shell → pantalla completa con botón de volver, sin barra inferior.
      GoRoute(path: '/admin-panel', builder: (_, _) => const AdminPanelScreen()),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(
            path: '/inventory',
            builder: (_, _) => const InventoryScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, _) => const ProductFormScreen()),
              GoRoute(
                path: 'edit/:id',
                builder: (_, state) =>
                    ProductFormScreen(productId: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/pos',
            builder: (_, _) => const POSScreen(),
            routes: [
              GoRoute(path: 'checkout', builder: (_, _) => const CheckoutScreen()),
            ],
          ),
          GoRoute(
            path: '/fiados',
            builder: (_, _) => const FiadosScreen(),
            routes: [
              GoRoute(
                path: ':clientId',
                builder: (_, state) =>
                    ClientDetailScreen(clientId: state.pathParameters['clientId']!),
              ),
            ],
          ),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
        ],
      ),
    ],
  );
});

// ────────────────────────────────────────────────
// Shell con nav por rol
// ────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _adminRoutes = [
    '/dashboard', '/pos', '/inventory', '/fiados', '/reports',
  ];
  static const _adminItems = [
    BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
    BottomNavigationBarItem(
        icon: Icon(Icons.point_of_sale_outlined), label: 'Vender'),
    BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
    BottomNavigationBarItem(
        icon: Icon(Icons.people_outline), label: 'Fiados'),
    BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
  ];

  static const _workerRoutes = ['/dashboard', '/pos', '/inventory'];
  static const _workerItems = [
    BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
    BottomNavigationBarItem(
        icon: Icon(Icons.point_of_sale_outlined), label: 'Vender'),
    BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final routes = role == UserRole.worker ? _workerRoutes : _adminRoutes;
    final items = role == UserRole.worker ? _workerItems : _adminItems;

    // Sincronizar índice con ruta actual
    final location = GoRouterState.of(context).matchedLocation;
    final idx = routes.indexWhere((r) => location.startsWith(r));
    if (idx != -1 && idx != _currentIndex) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _currentIndex = idx));
    }

    return Scaffold(
      appBar: role == UserRole.admin
          ? null // el dashboard screen tiene su propio AppBar con el botón de equipo
          : null,
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, items.length - 1),
        items: items,
        onTap: (i) {
          setState(() => _currentIndex = i);
          context.go(routes[i]);
        },
      ),
    );
  }
}

class NegocioApp extends ConsumerWidget {
  const NegocioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      // buildTag en el título (no visible al usuario) — fuerza un build nuevo
      // cuando solo cambian archivos web/, sin mover la versión visible.
      title: 'NegocioApp ${AppConstants.buildTag}',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
