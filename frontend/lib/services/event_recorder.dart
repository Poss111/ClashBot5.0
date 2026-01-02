class EventRecorder {
  static void Function(Map<String, dynamic>)? _handler;

  static void register(void Function(Map<String, dynamic>) handler) {
    _handler = handler;
  }

  static void record({
    required String type,
    String? message,
    int? statusCode,
    String? endpoint,
    String? url,
    Map<String, dynamic>? data,
    Object? requestBody,
    String? responseBody,
  }) {
    final event = <String, dynamic>{
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      if (message != null) 'message': message,
      if (statusCode != null) 'statusCode': statusCode,
      if (endpoint != null) 'endpoint': endpoint,
      if (url != null) 'url': url,
      if (data != null) 'data': data,
      if (requestBody != null) 'requestBody': requestBody,
      if (responseBody != null) 'responseBody': responseBody,
    };
    _handler?.call(event);
  }
}

