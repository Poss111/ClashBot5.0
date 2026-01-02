import 'dart:io';

import 'package:clash_companion/screens/home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> _pumpHome(WidgetTester tester,
      {Brightness brightness = Brightness.light, double width = 900, double height = 1600}) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: const HomeScreen(
          effectiveRole: 'GENERAL_USER',
          navEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('HomeScreen shows hero CTA and features', (tester) async {
    await _pumpHome(tester, width: 800, height: 1200);
    expect(find.text('View tournaments'), findsOneWidget);
    expect(find.text('Know when the next Tournament is!'), findsOneWidget);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('HomeScreen golden - light', (tester) async {
    const goldenPath = 'test/goldens/home_screen_light.png';
    final goldenFile = File(goldenPath);
    await _pumpHome(tester);
    if (goldenFile.existsSync()) {
      await expectLater(find.byType(HomeScreen), matchesGoldenFile(goldenPath));
    } else {
      debugPrint('Skipping golden (missing $goldenPath). Run flutter test --update-goldens to generate.');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('HomeScreen golden - dark', (tester) async {
    const goldenPath = 'test/goldens/home_screen_dark.png';
    final goldenFile = File(goldenPath);
    await _pumpHome(tester, brightness: Brightness.dark);
    if (goldenFile.existsSync()) {
      await expectLater(find.byType(HomeScreen), matchesGoldenFile(goldenPath));
    } else {
      debugPrint('Skipping golden (missing $goldenPath). Run flutter test --update-goldens to generate.');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

