class ApiConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const String _dev =
      'https://8jzx9fqvwg.execute-api.us-east-1.amazonaws.com/dev';
  static const String _prod =
      'https://8jzx9fqvwg.execute-api.us-east-1.amazonaws.com/prod';

  static String get baseUrl => _env == 'prod' ? _prod : _dev;
}

