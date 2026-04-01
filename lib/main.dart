import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
  await FirebaseService.init();
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
    // Initialize startup flags and auth state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(appStartupProvider.notifier).init();
      await ref.read(authProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Delivero',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
