import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/channels/channels_screen.dart';
import '../features/epg/guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/player/player_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';

abstract final class AppRoute {
  static const splash = '/splash';
  static const home = '/home';
  static const live = '/live';
  static const guide = '/guide';
  static const search = '/search';
  static const settings = '/settings';

  static String player(String channelId) => '/player/$channelId';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoute.splash,
  routes: [
    GoRoute(
      path: AppRoute.splash,
      builder: (context, state) => const SplashScreen(),
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
      path: '/player/:channelId',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          PlayerScreen(channelId: state.pathParameters['channelId']!),
    ),
  ],
);
