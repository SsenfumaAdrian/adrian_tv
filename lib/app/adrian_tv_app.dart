import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class AdrianTvApp extends StatelessWidget {
  const AdrianTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ADRIAN TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
