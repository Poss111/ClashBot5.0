abstract class AppNotification {
  final String type;
  final String? message;
  final String? causedBy;
  final DateTime? timestamp;
  final Map<String, dynamic>? data;
  final Map<String, dynamic> raw;

  AppNotification({
    required this.type,
    this.message,
    this.causedBy,
    this.timestamp,
    this.data,
    required this.raw,
  });

  String get title;
  String get timestampLabel => timestamp?.toIso8601String() ?? raw['timestamp']?.toString() ?? '';

  static AppNotification fromMap(Map<String, dynamic> map) {
    final normalizedType = (map['type'] ?? 'event').toString();
    if (normalizedType.startsWith('auth.')) {
      return AuthNotification.fromMap(map);
    }
    if (normalizedType.startsWith('api.')) {
      return ApiNotification.fromMap(map);
    }
    return GeneralAnnouncementNotification.fromMap(map);
  }
}

class ApiNotification extends AppNotification {

  final String? endpoint;
  final String? url;
  final int? statusCode;

  ApiNotification({
    required super.type,
    super.message,
    this.endpoint,
    this.url,
    this.statusCode,
    super.causedBy,
    super.timestamp,
    super.data,
    required super.raw,
  });

  factory ApiNotification.fromMap(Map<String, dynamic> map) {
    final base = _parseCommon(map);
    return ApiNotification(
      type: base.type,
      message: base.message,
      endpoint: map['endpoint']?.toString(),
      url: map['url']?.toString(),
      statusCode: map['statusCode']?.toInt(),
      causedBy: base.causedBy,
      timestamp: base.timestamp,
      data: base.data,
      raw: base.raw,
    );
  }

  @override
  String get title => message ?? type;
}

class GeneralAnnouncementNotification extends AppNotification {
  final String? tournamentId;

  GeneralAnnouncementNotification({
    required super.type,
    super.message,
    this.tournamentId,
    super.causedBy,
    super.timestamp,
    super.data,
    required super.raw,
  });

  factory GeneralAnnouncementNotification.fromMap(Map<String, dynamic> map) {
    final base = _parseCommon(map);
    return GeneralAnnouncementNotification(
      type: base.type,
      message: base.message,
      tournamentId: map['tournamentId']?.toString(),
      causedBy: base.causedBy,
      timestamp: base.timestamp,
      data: base.data,
      raw: base.raw,
    );
  }

  @override
  String get title => message ?? type;
}

class AuthNotification extends AppNotification {
  final String? stage;
  final bool? interactive;
  final bool? hasIdToken;
  final bool? hasAccessToken;
  final String? googleUserEmail;
  final String? clientId;
  final String? serverId;
  final String? error;

  AuthNotification({
    required super.type,
    super.message,
    super.causedBy,
    super.timestamp,
    super.data,
    required super.raw,
    this.stage,
    this.interactive,
    this.hasIdToken,
    this.hasAccessToken,
    this.googleUserEmail,
    this.clientId,
    this.serverId,
    this.error,
  });

  factory AuthNotification.fromMap(Map<String, dynamic> map) {
    final base = _parseCommon(map);
    final data = base.data ?? <String, dynamic>{};
    String? _s(String key) => data[key]?.toString();
    bool? _b(String key) => data[key] is bool ? data[key] as bool : null;
    return AuthNotification(
      type: base.type,
      message: base.message,
      causedBy: base.causedBy,
      timestamp: base.timestamp,
      data: base.data,
      raw: base.raw,
      stage: _s('stage'),
      interactive: _b('interactive'),
      hasIdToken: _b('hasIdToken'),
      hasAccessToken: _b('hasAccessToken'),
      googleUserEmail: _s('googleUserEmail'),
      clientId: _s('clientId'),
      serverId: _s('serverId'),
      error: _s('error'),
    );
  }

  @override
  String get title => message ?? type;
}

// Internal helper to normalize common fields.
AppNotification _parseCommon(Map<String, dynamic> map) {
  DateTime? ts;
  final tsStr = map['timestamp']?.toString();
  if (tsStr != null) {
    try {
      ts = DateTime.parse(tsStr);
    } catch (_) {}
  }
  return _TempNotification(
    type: (map['type'] ?? 'event').toString(),
    message: map['message']?.toString(),
    causedBy: map['causedBy']?.toString(),
    timestamp: ts,
    data: map['data'] is Map<String, dynamic> ? (map['data'] as Map<String, dynamic>) : null,
    raw: map,
  );
}

// Private concrete used only for parsing.
class _TempNotification extends AppNotification {
  _TempNotification({
    required super.type,
    super.message,
    super.causedBy,
    super.timestamp,
    super.data,
    required super.raw,
  });

  @override
  String get title => type;
}

