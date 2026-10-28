import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class AdrianTvApp extends StatelessWidget {
  const AdrianTvApp({super.key, this.router});

  /// Null in production: a fresh router is built per app instance.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ADRIAN TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router ?? buildRouter(),
    );
  }
}
