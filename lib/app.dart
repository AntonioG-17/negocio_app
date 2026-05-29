import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/auth/screens/business_select_screen.dart';
import 'package:negocio_app/features/auth/screens/login_screen.dart';
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

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final hasBusiness = selectedBusiness != null;
      final path = state.matchedLocation;

      if (!isLoggedIn) return '/login';
      if (isLoggedIn && !hasBusiness && path != '/select-business') {
        return '/select-business';
      }
      if (isLoggedIn && hasBusiness && (path == '/login' || path == '/select-business')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/select-business', builder: (_, _) => const BusinessSelectScreen()),
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

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _routes = ['/dashboard', '/pos', '/inventory', '/fiados', '/reports'];
  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), label: 'Vender'),
    BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Fiados'),
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: _items,
        onTap: (i) {
          setState(() => _currentIndex = i);
          context.go(_routes[i]);
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
      title: 'NegocioApp',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
