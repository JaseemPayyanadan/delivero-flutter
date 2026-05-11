import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firebase_service.dart';
import 'core/services/local_notifications_service.dart';
import 'core/services/push_notification_service.dart';

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

class _DeliveroAppState extends ConsumerState<DeliveroApp> {
  @override
  void initState() {
    super.initState();
    // Start initialization early but let the splash screen control the transition
    Future.microtask(() async {
      await ref.read(appStartupProvider.notifier).init();
      await ref.read(authProvider.notifier).init();
      await PushNotificationService.instance.configure();
      await PushNotificationService.instance.setUser(
        ref.read(authProvider).user,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen(authProvider, (previous, next) {
      PushNotificationService.instance.setUser(next.user);
    });

    return MaterialApp.router(
      title: 'Delivero',
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
