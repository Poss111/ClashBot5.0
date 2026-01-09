import '../theme.dart';
import 'notification_item.dart';

enum NotificationSeverity { info, success, warning, error }

class NotificationDisplay {
  final String title;
  final String? subtitle;
  final List<String> details;
  final String? causedBy;
  final String? timestamp;
  final NotificationSeverity severity;

  NotificationDisplay({
    required this.title,
    this.subtitle,
    this.details = const [],
    this.severity = NotificationSeverity.info,
    this.causedBy,
    this.timestamp,
  });
}

// Should include implmentations of AppNotification subclasses.
typedef NotificationBuilder<T extends AppNotification> = NotificationDisplay Function(T notification);

enum NotificationType {
  apiCall,
  apiError,
  api,
  auth,
  tournamentRegistered,
  general,
}

class NotificationPresenter {
  static final Map<NotificationType, NotificationBuilder<AppNotification>> _builders = {
    NotificationType.apiCall: _buildApi,
    NotificationType.apiError: _buildApi,
    NotificationType.api: _buildApi,
    NotificationType.auth: _buildAuth,
    NotificationType.tournamentRegistered: _buildTournamentRegistered,
    NotificationType.general: _defaultBuilder,
  };

  static void registerBuilder<T extends AppNotification>(
    NotificationType type,
    NotificationBuilder<T> builder,
  ) {
    _builders[type] = (n) => builder(n as T);
  }

  static NotificationDisplay build(AppNotification notification) {
    final type = _resolveType(notification.type);
    final builder = _builders[type] ?? _defaultBuilder;
    return builder(notification);
  }

  static NotificationType _resolveType(String rawType) {
    final key = rawType.toLowerCase();
    if (key.startsWith('api.error')) return NotificationType.apiError;
    if (key.startsWith('api.call')) return NotificationType.apiCall;
    if (key.startsWith('api')) return NotificationType.api;
    if (key.startsWith('auth')) return NotificationType.auth;
    if (key.contains('tournament.registered')) return NotificationType.tournamentRegistered;
    return NotificationType.general;
  }

  static NotificationDisplay _buildApi(AppNotification n) {
    final api = n is ApiNotification ? n : ApiNotification.fromMap(n.raw);
    final lines = <String>[];
    if (api.endpoint != null) lines.add('Endpoint: ${api.endpoint}');
    if (api.url != null) lines.add('URL: ${api.url}');
    if (api.statusCode != null) lines.add('Status: ${api.statusCode}');
    if (api.causedBy != null) lines.add('Caused by: ${n.causedBy}');
    // Get a formatted timestamp string.
    var timestamp = n.timestamp;
    String? formattedTimestamp;
    if (timestamp != null) {
      formattedTimestamp = AppDateFormats.formatLong(timestamp.toLocal());
    }
    return NotificationDisplay(
      title: n.title,
      subtitle: n.message,
      details: lines,
      severity: api.statusCode != null && api.statusCode! >= 400
          ? NotificationSeverity.error
          : NotificationSeverity.success,
      timestamp: formattedTimestamp,
      causedBy: n.causedBy,
    );
  }

  static NotificationDisplay _buildAuth(AppNotification n) {
    final auth = n is AuthNotification ? n : AuthNotification.fromMap(n.raw);
    final lines = <String>[];
    if (auth.stage != null) lines.add('Stage: ${auth.stage}');
    if (auth.interactive != null) lines.add('Interactive: ${auth.interactive}');
    if (auth.googleUserEmail != null) lines.add('Google user: ${auth.googleUserEmail}');
    if (auth.error != null) lines.add('Error: ${auth.error}');

    String? formattedTimestamp;
    final ts = n.timestamp;
    if (ts != null) {
      formattedTimestamp = AppDateFormats.formatLong(ts.toLocal());
    }

    final isError = n.type.toLowerCase().contains('error');

    return NotificationDisplay(
      title: auth.title,
      subtitle: auth.message,
      details: lines,
      severity: isError ? NotificationSeverity.error : NotificationSeverity.info,
      timestamp: formattedTimestamp,
      causedBy: auth.causedBy,
    );
  }

  static NotificationDisplay _buildTournamentRegistered(AppNotification n) {
    final ga = n is GeneralAnnouncementNotification ? n : GeneralAnnouncementNotification.fromMap(n.raw);
    final lines = <String>[];
    var tournamentKey = ga.tournamentId;
    if (n.data != null) {
      if (n.data?['nameKeySecondary'] != null) tournamentKey = ga.data?['nameKeySecondary'];
      if (n.data?['registrationTime'] != null) {
        final local = DateTime.parse(n.data?['registrationTime']!).toLocal();
        final formatted = AppDateFormats.formatLong(local);
        lines.add('Registration time is on $formatted (${local.timeZoneName})');
      }
      if (n.data?['startTime'] != null) {
        final local = DateTime.parse(n.data?['startTime']!).toLocal();
        final formatted = AppDateFormats.formatLong(local);
        lines.add('Start time is on $formatted (${local.timeZoneName})');
      }
    }
    // Get a formatted timestamp string.
    var timestamp = n.timestamp;
    String? formattedTimestamp;
    if (timestamp != null) {
      formattedTimestamp = AppDateFormats.formatLong(timestamp.toLocal());
    }
    return NotificationDisplay(
      title: "A new tournament has been registered!",
      subtitle: "Tournament $tournamentKey has been registered.",
      details: lines,
      severity: NotificationSeverity.success,
      causedBy: n.causedBy,
      timestamp: formattedTimestamp,
    );
  }

  static NotificationDisplay _defaultBuilder(AppNotification n) {
    final lines = <String>[];

    var formattedTimestamp = AppDateFormats.formatLong(DateTime.now().toLocal());
    return NotificationDisplay(
      title: n.title,
      subtitle: n.message,
      details: lines,
      severity: NotificationSeverity.info,
      causedBy: n.causedBy,
      timestamp: formattedTimestamp,
    );
  }
}

