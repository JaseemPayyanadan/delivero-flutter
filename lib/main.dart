import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/order_settings_provider.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/orders/business_day.dart';
import 'core/orders/daily_order_recreation_service.dart';
import 'features/owner/orders/unresolved_orders_sheet.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firebase_service.dart';
import 'core/services/local_notifications_service.dart';
import 'core/services/order_day_reset_notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'data/models/user.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
  await FirebaseService.init();
  if (Firebase.apps.isNotEmpty && !kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  PushNotificationService.instance.attachMessenger(rootScaffoldMessengerKey);
  await LocalNotificationsService.instance.init();
  runApp(const ProviderScope(child: DeliveroApp()));
}

class DeliveroApp extends ConsumerStatefulWidget {
  const DeliveroApp({super.key});

  @override
  ConsumerState<DeliveroApp> createState() => _DeliveroAppState();
}

Future<void> _syncOrderDayResetNotification(
  WidgetRef ref,
  User? user,
) async {
  if (user?.role != UserRole.owner || user?.factoryId == null) {
    await OrderDayResetNotificationService.instance.syncForOwner(
      user: user,
      rolloverHour: ref.read(orderRolloverHourProvider),
    );
    return;
  }
  await ref
      .read(orderRolloverHourProvider.notifier)
      .syncForFactory(user!.factoryId);
}

class _DeliveroAppState extends ConsumerState<DeliveroApp> {
  @override
  void initState() {
    super.initState();
    LocalNotificationsService.instance.setNotificationTapHandler((payload) {
      if (payload != 'order_day_reset') return;
      _runDailyRecreationCatchUp(showFeedback: true);
    });
    // Start initialization early but let the splash screen control the transition
    Future.microtask(() async {
      await ref.read(appStartupProvider.notifier).init();
      await ref.read(authProvider.notifier).init();
      await PushNotificationService.instance.configure();
      await PushNotificationService.instance.setUser(
        ref.read(authProvider).user,
      );
      await _syncOrderDayResetNotification(ref, ref.read(authProvider).user);
      _runDailyRecreationCatchUp(showFeedback: false);
    });
  }

  Future<void> _runDailyRecreationCatchUp({required bool showFeedback}) async {
    final user = ref.read(authProvider).user;
    final factoryId = user?.factoryId;
    if (factoryId == null || factoryId.isEmpty) return;
    if (!ref.read(ordersLoadedProvider)) return;
    if (!ref.read(customersLoadedProvider)) return;

    final result = await ref
        .read(ordersProvider.notifier)
        .runDailyRecreationCatchUp(factoryId);

    if (!showFeedback || !result.hasChanges || !mounted) return;
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final message = switch (result.createdCount) {
      0 => 'Daily orders synced for today',
      1 => '1 daily order auto-created for today',
      _ => '${result.createdCount} daily orders auto-created for today',
    };
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen(authProvider, (previous, next) {
      PushNotificationService.instance.setUser(next.user);
      _syncOrderDayResetNotification(ref, next.user);
      _runDailyRecreationCatchUp(showFeedback: false);
    });

    ref.listen(ordersLoadedProvider, (previous, loaded) {
      if (loaded) {
        _runDailyRecreationCatchUp(showFeedback: false);
      }
    });

    return MaterialApp.router(
      title: 'Delivro',
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final focus = FocusManager.instance.primaryFocus;
            if (focus != null && !focus.hasPrimaryFocus) {
              focus.unfocus();
            }
          },
          child: child,
        );
      },
    );
  }
}
