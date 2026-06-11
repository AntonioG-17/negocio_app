import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:negocio_app/features/admin/screens/admin_panel_screen.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/auth/screens/auth_action_screen.dart';
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
import 'package:negocio_app/features/reports/screens/daily_reports_screen.dart';
import 'package:negocio_app/features/reports/screens/reports_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Refrescar el redirect cuando cambian auth/perfil/negocio SIN recrear el
  // GoRouter. Antes se usaba ref.watch en el cuerpo, así que el router se
  // recreaba en cada cambio (auth → perfil → negocio) durante la carga y
  // reseteaba el navegador → dashboard en blanco. Ahora se crea UNA vez y se
  // re-evalúa el redirect vía refreshListenable.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(selectedBusinessProvider, (_, _) => refresh.value++);
  ref.listen(selectedMembershipProvider, (_, _) => refresh.value++);

  // Cuando el stream de membresías cambia (ej. admin desactiva al worker),
  // limpiar el negocio y membresía activos para que el router los expulse.
  ref.listen(userMembershipsProvider, (prev, next) {
    final prevList = prev?.valueOrNull;
    final nextList = next.valueOrNull;
    if (prevList == null || nextList == null) {
      refresh.value++;
      return;
    }
    final activeMembership = ref.read(selectedMembershipProvider);
    if (activeMembership != null) {
      final stillActive = nextList.any((m) => m.id == activeMembership.id);
      if (!stillActive) {
        ref.read(selectedBusinessProvider.notifier).state = null;
        ref.read(selectedMembershipProvider.notifier).state = null;
      }
    }
    refresh.value++;
  });

  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final selectedBusiness = ref.read(selectedBusinessProvider);

      final path = state.matchedLocation;

      // Página pública de recuperación / invitación (llega del correo). No
      // depende de la sesión.
      if (path == '/recuperar') return null;

      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;

      if (!isLoggedIn) {
        return path != '/login' ? '/login' : null;
      }

      // CEO: cuenta especial por correo → panel CEO, o preview (solo lectura).
      if (ref.read(isCeoEmailProvider)) {
        final inPreview = selectedBusiness != null;
        if (!inPreview) {
          if (path != '/ceo') return '/ceo';
          return null;
        }
        const blocked = ['/pos', '/inventory/add', '/inventory/edit', '/admin-panel'];
        if (blocked.any((r) => path.startsWith(r))) return '/dashboard';
        const allowed = ['/ceo', '/dashboard', '/inventory', '/fiados', '/reports'];
        if (!allowed.any((r) => path.startsWith(r))) return '/dashboard';
        return null;
      }

      // No-CEO: el flujo depende de las membresías (0 / 1 / 2+ negocios).
      final memberships = ref.read(userMembershipsProvider);
      if (memberships.isLoading) return null;
      final list = memberships.valueOrNull ?? [];
      final role = ref.read(currentUserRoleProvider); // del negocio elegido

      // Ya hay un negocio activo.
      if (selectedBusiness != null) {
        if (path == '/' || path == '/login' || path == '/select-business') {
          return '/dashboard';
        }
        if (role == UserRole.worker) {
          const forbidden = ['/fiados', '/reports', '/admin-panel'];
          if (forbidden.any((r) => path.startsWith(r))) return '/dashboard';
          if (path.startsWith('/inventory/add') ||
              path.startsWith('/inventory/edit')) {
            return '/inventory';
          }
        }
        return null;
      }

      // Sin negocio activo: migrar (si es cuenta legacy) + auto-entrar si hay
      // un solo negocio. Con 0 o 2+ → menú de selección estilo CEO.
      Future.microtask(
          () => ref.read(authNotifierProvider.notifier).loadBusinessForCurrentUser());
      if (list.length == 1) {
        if (path == '/' || path == '/login' || path == '/select-business') {
          return '/dashboard';
        }
        return null;
      }
      if (path != '/select-business') return '/select-business';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/recuperar',
        builder: (_, state) => AuthActionScreen(
          mode: state.uri.queryParameters['mode'],
          oobCode: state.uri.queryParameters['oobCode'],
        ),
      ),
      GoRoute(path: '/select-business', builder: (_, _) => const BusinessSelectScreen()),
      GoRoute(path: '/ceo', builder: (_, _) => const CeoScreen()),
      // Fuera del shell → pantalla completa con botón de volver, sin barra inferior.
      GoRoute(path: '/admin-panel', builder: (_, _) => const AdminPanelScreen()),
      GoRoute(path: '/reports/daily', builder: (_, _) => const DailyReportsScreen()),
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

  // CEO en preview: ve todo menos Vender (POS). Solo lectura.
  static const _ceoRoutes = ['/dashboard', '/inventory', '/fiados', '/reports'];
  static const _ceoItems = [
    BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
    BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
    BottomNavigationBarItem(
        icon: Icon(Icons.people_outline), label: 'Fiados'),
    BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
  ];

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final (routes, items) = switch (role) {
      UserRole.worker => (_workerRoutes, _workerItems),
      UserRole.ceo => (_ceoRoutes, _ceoItems),
      _ => (_adminRoutes, _adminItems),
    };

    // Calcular el índice activo directamente desde la ruta — sin setState
    // ni addPostFrameCallback. Antes el doble rebuild causaba que los botones
    // parecieran necesitar doble tap para reaccionar.
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = routes
        .indexWhere((r) => location.startsWith(r))
        .clamp(0, items.length - 1);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        items: items,
        onTap: (i) => context.go(routes[i]),
      ),
    );
  }
}

class NegocioApp extends ConsumerStatefulWidget {
  const NegocioApp({super.key});

  @override
  ConsumerState<NegocioApp> createState() => _NegocioAppState();
}

class _NegocioAppState extends ConsumerState<NegocioApp>
    with WidgetsBindingObserver {
  Timer? _dayTimer;
  late DateTime _day;

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _day = _today();
    WidgetsBinding.instance.addObserver(this);
    // Revisa el cambio de día cada minuto (cubre el POS que queda abierto
    // cruzando la medianoche).
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkDayChange());
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app (p. ej. al otro día), revisa si cambió el día.
    if (state == AppLifecycleState.resumed) _checkDayChange();
  }

  void _checkDayChange() {
    final today = _today();
    if (today != _day) {
      _day = today;
      // Nuevo día → "Ventas hoy" arranca limpio (el provider captura el inicio
      // del día al construirse, así que se reinicia su consulta).
      ref.invalidate(todaySalesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      // buildTag en el título (no visible al usuario) — fuerza un build nuevo
      // cuando solo cambian archivos web/, sin mover la versión visible.
      title: 'NegocioApp ${AppConstants.buildTag}',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Español: calendario / selector de fechas y textos de Material en es.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
