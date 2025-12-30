class ApiConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static String get _origin {
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

