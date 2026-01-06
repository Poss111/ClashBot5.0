# ClashBot Flutter Frontend

This is the Flutter frontend application for ClashBot. It supports multiple platforms (web, iOS, Android, desktop) allowing you to create multiple clients.

## Setup

1. Install Flutter SDK from https://flutter.dev/docs/get-started/install
2. Run `flutter pub get` to install dependencies
3. Run `flutter run -d chrome` for web development
4. Run `flutter run` to see available devices

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
