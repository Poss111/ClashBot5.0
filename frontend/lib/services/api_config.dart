import 'package:flutter/foundation.dart';

class ApiConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  // Optional override for non-web builds to force CloudFront origin.
  static const _cfOrigin = String.fromEnvironment('CLOUDFRONT_ORIGIN', defaultValue: '');
  // Force mock origin (overrides base) when defined.
  static const _mockOrigin = String.fromEnvironment('MOCK_API_ORIGIN', defaultValue: '');

  static String get _origin {
    // Highest priority: explicit mock origin (useful when running local mocks).
    if (_mockOrigin.isNotEmpty) {
      return _mockOrigin;
    }

    // For mobile/desktop, prefer a provided CloudFront origin if base URI is empty.
    if (!kIsWeb && _cfOrigin.isNotEmpty) {
      return _cfOrigin;
    }

    final origin = Uri.base.origin;
    if (origin.isEmpty || origin == 'null') {
      return _env == 'prod'
          ? 'https://8jzx9fqvwg.execute-api.us-east-1.amazonaws.com'
          : 'https://8jzx9fqvwg.execute-api.us-east-1.amazonaws.com';
    }
    return origin;
  }

  static String get baseUrl {
    final stage = _env == 'prod' ? '/prod' : '/dev';
    return '$_origin/api$stage';
  }
}

