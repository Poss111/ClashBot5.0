import 'package:flutter/foundation.dart';

class ApiConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  // Optional override for non-web builds to force CloudFront origin.
  static const _cfOrigin = String.fromEnvironment('CLOUDFRONT_ORIGIN', defaultValue: '');
  // Force mock origin (overrides base) when defined.
  static const _mockOrigin = String.fromEnvironment('MOCK_API_ORIGIN', defaultValue: '');

  static String get _origin {
    // Highest priority: explicit mock origin (useful when running local mocks).
    if (_mockOrigin.isNotEmpty) {
      return _mockOrigin;
    }

    // For mobile/desktop, prefer a provided CloudFront origin when available.
    if (!kIsWeb && _cfOrigin.isNotEmpty) {
      return _cfOrigin;
    }

    final origin = Uri.base.origin;
    if (origin.isNotEmpty && origin != 'null') {
      return origin;
    }
    // Fallback: stay empty to force explicit origin configuration.
    return _cfOrigin.isNotEmpty ? _cfOrigin : '';
  }

  static String get baseUrl {
    final stage = _env == 'prod' ? '/prod' : '/dev';
    if (_origin.isEmpty || _origin == 'null' || _origin.contains('cloudfront')) {
      // Relative path if served from same host.
      return '/api$stage';
    }
    return '$_origin$stage';
  }
}

