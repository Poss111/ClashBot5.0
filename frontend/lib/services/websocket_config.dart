class WebSocketConfig {
  // Set APP_ENV=prod in release builds; defaults to dev for local runs.
  static const _env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static String get _origin {
    final base = Uri.base;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    if (base.hasAuthority && base.authority.isNotEmpty) {
      return '$scheme://${base.authority}';
    }
    // fallback to deployed gateway host
    return _env == 'prod'
        ? 'wss://4a40u0p883.execute-api.us-east-1.amazonaws.com'
        : 'wss://4a40u0p883.execute-api.us-east-1.amazonaws.com';
  }

  static String get baseUrl {
    final stage = _env == 'prod' ? '/prod' : '/dev';
    return '$_origin/events$stage';
  }
}

