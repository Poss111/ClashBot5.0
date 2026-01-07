import 'package:clash_companion/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  testGoldens('Home screen per device', (tester) async {
    final widget = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Clash Companion'),
      ),
      body: const ColoredBox(
        color: Color(0xFFF5F6FA),
        child: HomeScreen(
          effectiveRole: 'GENERAL_USER',
          navEnabled: true,
        ),
      ),
    );

    await tester.pumpWidgetBuilder(
      widget,
      wrapper: materialAppWrapper(
        theme: ThemeData.light(useMaterial3: true),
      ),
    );

    await multiScreenGolden(
      tester,
      'home_screen',
      devices: const [
        Device.phone,
        Device.iphone11,
        Device.tabletPortrait,
      ],
    );
  });
}

