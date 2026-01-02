import 'package:flutter/foundation.dart';

class WebSocketConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  // Optional override for non-web builds to force CloudFront origin.
  static const _cfWsOrigin = String.fromEnvironment('CLOUDFRONT_WS_ORIGIN', defaultValue: '');
  // Force mock origin (overrides base) when defined.
  static const _mockWsOrigin = String.fromEnvironment('MOCK_WS_ORIGIN', defaultValue: '');

  static String get _origin {
    if (_mockWsOrigin.isNotEmpty) {
      return _mockWsOrigin;
    }

    if (_cfWsOrigin.isNotEmpty) {
      return _cfWsOrigin;
    }

    final base = Uri.base;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    if (base.hasAuthority && base.authority.isNotEmpty) {
      return '$scheme://${base.authority}';
    }
    // Fallback: stay empty to force explicit origin configuration.
    return _cfWsOrigin.isNotEmpty ? _cfWsOrigin : '';
  }

  static String get baseUrl {
    final stage = _env == 'prod' ? '/prod' : '/dev';
    if (_origin.isEmpty || _origin == 'null' || _origin.contains('cloudfront')) {
      return '/events$stage';
    }
    return '$_origin$stage';
  }
}

