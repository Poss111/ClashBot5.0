# ClashBot Flutter Frontend

This is the Flutter frontend application for ClashBot. It supports multiple platforms (web, iOS, Android, desktop) allowing you to create multiple clients.

## Setup

1. Install Flutter SDK from https://flutter.dev/docs/get-started/install
2. Run `flutter pub get` to install dependencies
3. Run `flutter run -d chrome` for web development
4. Run `flutter run` to see available devices

### Local mock stack (one command)
- Start REST, WebSocket, and Flutter against mocks: `./scripts/dev_mock_stack.sh`
- Defaults: APP_ENV=dev, REST on :4000/api/dev, WS on :4001/events/dev, device=chrome.
- Customize: `-d macos`, `-a/--android` (sets host to 10.0.2.2 and uses `ANDROID_DEVICE` or emulator-5556), `--env prod`, `--api-port 4100`, `--ws-port 4101`, `--host 10.0.2.2`, or `--no-flutter` to just run mocks.
- Pass extra Flutter flags after `--`, e.g. `./scripts/dev_mock_stack.sh -- --web-renderer html`.

## Building

- **Web**: `flutter build web`
- **iOS**: `flutter build ios`
- **Android**: `flutter build apk` or `flutter build appbundle`
- **Windows**: `flutter build windows`
- **macOS**: `flutter build macos`
- **Linux**: `flutter build linux`

## Configuration

The API base URL can be configured in `lib/services/api_config.dart`.

## Screenshots

Screenshots can be taken using the `flutter test integration_test/screenshot_test.dart` command.
The screenshots will be saved in the `screenshots` directory.
The screenshots will be named after the device name.
The screenshots will be saved in the `screenshots` directory.
