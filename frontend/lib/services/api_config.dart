import 'package:clash_companion/services/logger.dart';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  // Optional override for non-web builds to force CloudFront origin.
  static const _cfOrigin = String.fromEnvironment('CLOUDFRONT_ORIGIN', defaultValue: '');
  // Force mock origin (overrides base) when defined.
  static const _mockOrigin = String.fromEnvironment('MOCK_API_ORIGIN', defaultValue: '');

  static String get _origin {
    logDebug("_env: $_env");
    logDebug("_cfOrigin: $_cfOrigin");
    logDebug("_mockOrigin: $_mockOrigin");
    logDebug("kIsWeb: ${kIsWeb}");
    // Highest priority: explicit mock origin (useful when running local mocks).
    if (_mockOrigin.isNotEmpty) {
      logDebug("Using mock origin: $_mockOrigin");
      return _mockOrigin;
    }

    // For mobile/desktop, prefer a provided CloudFront origin when available.
    if (_cfOrigin.isNotEmpty) {
      logDebug("Using CloudFront origin: $_cfOrigin");
      return _cfOrigin;
    }

    final origin = Uri.base.origin;
    if (origin.isNotEmpty && origin != 'null') {
      logDebug("Using base origin: $origin");
      return origin;
    }
    // Fallback: stay empty to force explicit origin configuration.
    logDebug("Using fallback origin: $_cfOrigin");
    return _cfOrigin.isNotEmpty ? _cfOrigin : '';
  }

  static String get baseUrl {
    final stage = _env == 'prod' ? '/prod' : '/dev';
    if (_origin.isEmpty || _origin == 'null' || _origin.contains('cloudfront')) {
      // Relative path if served from same host.
      logDebug("Using relative origin: /api$stage");
      return '/api$stage';
    }
    logDebug("Using origin: $_origin$stage");
    return '$_origin$stage';
  }
}

