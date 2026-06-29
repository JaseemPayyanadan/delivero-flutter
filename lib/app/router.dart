import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user.dart';
import '../features/auth/otp_verify_screen.dart';
import '../features/auth/phone_login_screen.dart';
import '../features/delivery/driver_create_order_screen.dart';
import '../features/delivery/delivery_shell.dart';
import '../features/delivery/order_details/driver_order_details_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/owner/owner_shell.dart';
import '../features/owner/customers/customer_list_screen.dart';
import '../features/owner/customers/add_edit_customer_screen.dart';
import '../features/owner/customers/customer_details_screen.dart';
import '../features/owner/routes/route_management_screen.dart';
import '../features/owner/food/food_items_screen.dart';
import '../features/owner/orders/order_list_screen.dart';
import '../features/owner/orders/order_details_screen.dart';
import '../features/owner/orders/create_order_screen.dart';
import '../features/owner/reports/reports_screen.dart';
import '../features/owner/search/global_search_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/startup/app_intro_screen.dart';
import '../features/startup/app_launcher_screen.dart';
import 'providers.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, _) => notifyListeners());
    _ref.listen(appStartupProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final startupState = _ref.read(appStartupProvider);

    final loc = state.uri.toString();
    final isAtSplash = loc == '/splash';
    final isAtIntro = loc == '/intro';
    final isAtLogin = loc == '/login';
    final isAtOtp = loc == '/otp';
    final isAtOnboarding = loc == '/onboarding';
    final isAtOwner = loc.startsWith('/owner');
    final isAtDelivery = loc.startsWith('/delivery');

    if (!startupState.isInitialized || !authState.isInitialized) {
      return isAtSplash ? null : '/splash';
    }

    if (!startupState.hasSeenAppIntro) {
      return isAtIntro ? null : '/intro';
    }

    if (!authState.isAuthenticated) {
      // Pre-auth flows: phone-entry and OTP screens.
      if (isAtLogin) return null;
      if (isAtOtp && authState.pendingPhone != null) return null;
      return '/login';
    }

    // Owner onboarding (first-time setup wizard).
    if (authState.user!.role == UserRole.owner &&
        !authState.user!.hasFinishedOnboarding) {
      final isAllowedSetupPath =
          loc.startsWith('/owner/routes') ||
          loc.startsWith('/owner/customers') ||
          loc.startsWith('/owner/food-items');
      if (isAtOnboarding || isAllowedSetupPath) return null;
      return '/onboarding';
    }

    final role = authState.user!.role;
    if (role == UserRole.owner) {
      return isAtOwner ? null : '/owner';
    } else {
      return isAtDelivery ? null : '/delivery';
    }
  }
}

final routerNotifierProvider = Provider<RouterNotifier>(
  (ref) => RouterNotifier(ref),
);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const AppLauncherScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const AppIntroScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerShell(),
        routes: [
          GoRoute(
            path: 'customers',
            builder: (context, state) => const CustomerListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddEditCustomerScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) => AddEditCustomerScreen(
                  customerId: state.pathParameters['id'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CustomerDetailsScreen(
                  customerId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'routes',
            builder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              final initialTabIndex = tab == 'drivers' ? 1 : 0;
              return RouteManagementScreen(initialTabIndex: initialTabIndex);
            },
          ),
          GoRoute(
            path: 'food-items',
            builder: (context, state) => const FoodItemsScreen(),
          ),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const OrderListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => CreateOrderScreen(
                  preselectedCustomerId: state.extra as String?,
                ),
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) =>
                    CreateOrderScreen(orderId: state.pathParameters['id']),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    OrderDetailsScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'search',
            builder: (context, state) => const GlobalSearchScreen(),
          ),
          GoRoute(
            path: 'order-settings',
            builder: (context, state) => const OrderSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/delivery',
        builder: (context, state) => const DeliveryShell(),
        routes: [
          GoRoute(
            path: 'new-order',
            builder: (context, state) => const DriverCreateOrderScreen(),
          ),
          GoRoute(
            path: 'orders/:id',
            builder: (context, state) =>
                DriverOrderDetailsScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});
