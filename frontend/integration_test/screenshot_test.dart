import 'dart:convert';
import 'dart:io';

import 'package:clash_companion/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _mockPort = 8080;
const _stagePrefix = '/prod';
const _mockAuthEnabled = bool.fromEnvironment('MOCK_AUTH', defaultValue: false);
const _mockOrigin = String.fromEnvironment('MOCK_API_ORIGIN', defaultValue: '');
const _screenshotDir = String.fromEnvironment('SCREENSHOT_DIR', defaultValue: 'screenshots/default');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;

  setUpAll(() async {
    _assertEnv();
    server = await _startMockServer();
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  testWidgets('capture primary screenshots with mock data', (tester) async {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    await tester.pumpWidget(const ClashCompanionApp());
    await tester.pumpAndSettle();
    await _dismissDisclaimerIfPresent(tester);

    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('$_screenshotDir/home');

    final viewTournamentsButton = find.text('View tournaments');
    expect(viewTournamentsButton, findsOneWidget);
    await tester.tap(viewTournamentsButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await binding.takeScreenshot('$_screenshotDir/tournaments');
  });
}

void _assertEnv() {
  if (!_mockAuthEnabled) {
    throw StateError('Run with --dart-define=MOCK_AUTH=true for screenshots');
  }
  if (_mockOrigin.isEmpty) {
    throw StateError('Run with --dart-define=MOCK_API_ORIGIN=http://127.0.0.1:$_mockPort');
  }
}

Future<HttpServer> _startMockServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _mockPort);
  server.listen((HttpRequest request) async {
    final path = request.uri.path;
    if (path == '$_stagePrefix/users/me') {
      await _writeJson(
        request,
        {
          'userId': 'user-123',
          'email': 'player@example.com',
          'displayName': 'Clasher',
          'name': 'Clasher',
          'picture': null,
          'role': 'ADMIN',
        },
      );
      return;
    }
    if (path == '$_stagePrefix/tournaments') {
      await _writeJson(
        request,
        {
          'items': [
            {
              'tournamentId': 'spring-clash',
              'name': 'Spring Clash Cup',
              'nameKeySecondary': 'Mid Lane Madness',
              'startTime': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
              'registrationTime': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
              'region': 'NA',
              'status': 'OPEN',
              'themeId': 5,
              'schedule': [],
            },
            {
              'tournamentId': 'summer-clash',
              'name': 'Summer Clash Series',
              'nameKeySecondary': 'Bot Lane Brawl',
              'startTime': DateTime.now().add(const Duration(days: 21)).toUtc().toIso8601String(),
              'registrationTime': DateTime.now().add(const Duration(days: 14)).toUtc().toIso8601String(),
              'region': 'EU',
              'status': 'COMING_SOON',
              'themeId': 7,
              'schedule': [],
            },
          ],
        },
      );
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  });
  return server;
}

Future<void> _writeJson(HttpRequest request, Map<String, dynamic> body) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(json.encode(body));
  await request.response.close();
}

Future<void> _dismissDisclaimerIfPresent(WidgetTester tester) async {
  final agreeButton = find.text('I understand');
  if (agreeButton.evaluate().isNotEmpty) {
    await tester.tap(agreeButton);
    await tester.pumpAndSettle();
  }
}

