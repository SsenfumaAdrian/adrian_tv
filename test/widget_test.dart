import 'package:adrian_tv/app/adrian_tv_app.dart';
import 'package:adrian_tv/data/local/app_preferences.dart';
import 'package:adrian_tv/data/models/channel.dart';
import 'package:adrian_tv/data/parsers/xmltv_parser.dart';
import 'package:adrian_tv/features/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<AppPreferences> buildPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return AppPreferences(await SharedPreferences.getInstance());
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    List<Channel> channels = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(await buildPrefs()),
          channelsProvider.overrideWith((ref) => Future.value(channels)),
          epgIndexProvider.overrideWith((ref) => EpgIndex(const [])),
        ],
        child: const AdrianTvApp(),
      ),
    );
  }

  testWidgets('splash shows branding then lands on home', (tester) async {
    await pumpApp(tester);
    expect(find.text('ADRIAN TV'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ADRIAN TV'), findsOneWidget);
  });

  testWidgets('home lists channels in group rails', (tester) async {
    const channels = [
      Channel(
        id: 'c1',
        name: 'Demo One',
        streamUrl: 'http://example.com/1.ts',
        sourceId: 'demo',
        group: 'News',
      ),
      Channel(
        id: 'c2',
        name: 'Demo Two',
        streamUrl: 'http://example.com/2.ts',
        sourceId: 'demo',
        group: 'News',
      ),
    ];
    await pumpApp(tester, channels: channels);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('News'), findsWidgets);
    expect(find.text('Demo One'), findsWidgets);
  });

  testWidgets('channels screen supports favourites toggle', (tester) async {
    const channels = [
      Channel(
        id: 'c1',
        name: 'Fav Me',
        streamUrl: 'http://example.com/1.ts',
        sourceId: 'demo',
      ),
    ];
    await pumpApp(tester, channels: channels);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Navigate to Live TV tab and switch grid -> list for the star button.
    await tester.tap(find.text('Live TV').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to list'));
    await tester.pumpAndSettle();
    expect(find.text('Fav Me'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });
}
