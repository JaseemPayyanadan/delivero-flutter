import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/navigation.dart';
import 'app/order_settings_provider.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firebase_service.dart';
import 'core/services/local_notifications_service.dart';
import 'core/services/order_day_reset_notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'data/models/user.dart';
import 'features/owner/orders/unresolved_orders_sheet.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
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

Future<void> _syncOrderDayResetNotification(WidgetRef ref, User? user) async {
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
  bool _unresolvedSheetShowing = false;
  bool _recreationCatchUpInFlight = false;

  @override
  void initState() {
    super.initState();
    LocalNotificationsService.instance.setNotificationTapHandler((payload) {
      if (payload != 'order_day_reset') return;
      _scheduleDailyRecreationCatchUp(showFeedback: true);
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
      _scheduleDailyRecreationCatchUp(showFeedback: false);
    });
  }

  void _scheduleDailyRecreationCatchUp({required bool showFeedback}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runDailyRecreationCatchUp(showFeedback: showFeedback);
    });
  }

  Future<void> _showUnresolvedOrdersSheet(List<String> orderIds) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;

    _unresolvedSheetShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: navigator.context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UnresolvedOrdersSheet(
          orderIds: orderIds,
          title: 'Unresolved orders from yesterday',
          subtitle:
              "Review and update each order before today's orders are created.",
          doneLabel: "Done — create today's orders",
        ),
      );
    } finally {
      _unresolvedSheetShowing = false;
    }
  }

  Future<void> _completeUnresolvedReviewAndGenerate() async {
    final user = ref.read(authProvider).user;
    final factoryId = user?.factoryId;
    if (factoryId == null || factoryId.isEmpty) return;
    if (user?.role != UserRole.owner) return;

    ref.read(pendingUnresolvedDailyReviewProvider.notifier).clear();

    final result = await ref
        .read(ordersProvider.notifier)
        .runDailyRecreationCatchUp(
          factoryId,
          allowUnresolvedSources: true,
        );

    if (!result.hasChanges || !mounted) return;
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final message = switch (result.createdCount) {
      0 => 'Daily orders synced for today',
      1 => '1 daily order auto-created for today',
      _ => '${result.createdCount} daily orders auto-created for today',
    };
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _runDailyRecreationCatchUp({required bool showFeedback}) async {
    if (_recreationCatchUpInFlight || _unresolvedSheetShowing) return;

    final user = ref.read(authProvider).user;
    final factoryId = user?.factoryId;
    if (factoryId == null || factoryId.isEmpty) return;
    if (user?.role != UserRole.owner) return;
    if (!ref.read(ordersLoadedProvider)) return;
    if (!ref.read(customersLoadedProvider)) return;

    _recreationCatchUpInFlight = true;
    try {
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      _recreationCatchUpInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen(authProvider, (previous, next) {
      PushNotificationService.instance.setUser(next.user);
      _syncOrderDayResetNotification(ref, next.user);
      _scheduleDailyRecreationCatchUp(showFeedback: false);
    });

    ref.listen(ordersLoadedProvider, (previous, loaded) {
      if (loaded) {
        _scheduleDailyRecreationCatchUp(showFeedback: false);
      }
    });

    ref.listen(customersLoadedProvider, (previous, loaded) {
      if (loaded) {
        _scheduleDailyRecreationCatchUp(showFeedback: false);
      }
    });

    ref.listen(pendingUnresolvedDailyReviewProvider, (previous, orderIds) {
      if (orderIds == null || orderIds.isEmpty || _unresolvedSheetShowing) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _unresolvedSheetShowing) return;
        await _showUnresolvedOrdersSheet(orderIds);
        if (!mounted) return;
        await _completeUnresolvedReviewAndGenerate();
      });
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
