import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/channels/channels_screen.dart';
import '../features/epg/guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/player/player_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/vod/series_detail_screen.dart';
import '../features/vod/vod_screen.dart';

abstract final class AppRoute {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const live = '/live';
  static const vod = '/vod';
  static const guide = '/guide';
  static const search = '/search';
  static const settings = '/settings';

  static String player(String targetId) =>
      '/player/${Uri.encodeComponent(targetId)}';

  static String series(String sourceId, String seriesId) =>
      '/series/$sourceId/$seriesId';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Built per app instance (and per widget test) so navigation state never
/// leaks across restarts.
GoRouter buildRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoute.splash,
  routes: [
    GoRoute(
      path: AppRoute.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoute.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(
          path: AppRoute.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoute.live,
          builder: (context, state) => const ChannelsScreen(),
        ),
        GoRoute(
          path: AppRoute.vod,
          builder: (context, state) => const VodScreen(),
        ),
        GoRoute(
          path: AppRoute.guide,
          builder: (context, state) => const GuideScreen(),
        ),
        GoRoute(
          path: AppRoute.search,
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: AppRoute.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/player/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          PlayerScreen(targetId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/series/:sourceId/:seriesId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => SeriesDetailScreen(
        sourceId: state.pathParameters['sourceId']!,
        seriesId: state.pathParameters['seriesId']!,
      ),
    ),
  ],
);
