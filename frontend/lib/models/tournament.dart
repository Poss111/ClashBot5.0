class Tournament {
  final String tournamentId;
  final String? name;
  final String? nameKeySecondary;
  final String? nameKey;
  final String startTime;
  final String? registrationTime;
  final String? region;
  final String? status;
  final int? themeId;
  final List<dynamic>? schedule;

  Tournament({
    required this.tournamentId,
    this.name,
    this.nameKeySecondary,
    this.nameKey,
    required this.startTime,
    this.registrationTime,
    this.region,
    this.status,
    this.themeId,
    this.schedule,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      tournamentId: json['tournamentId'] as String,
      name: json['name'] as String?,
      nameKeySecondary: json['nameKeySecondary'] as String?,
      nameKey: json['nameKey'] as String?,
      startTime: json['startTime'] as String,
      registrationTime: json['registrationTime'] as String?,
      region: json['region'] as String?,
      status: json['status'] as String?,
      themeId: json['themeId'] as int?,
      schedule: json['schedule'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      if (name != null) 'name': name,
      if (nameKeySecondary != null) 'nameKeySecondary': nameKeySecondary,
      if (nameKey != null) 'nameKey': nameKey,
      'startTime': startTime,
      if (registrationTime != null) 'registrationTime': registrationTime,
      if (region != null) 'region': region,
      if (status != null) 'status': status,
      if (themeId != null) 'themeId': themeId,
      if (schedule != null) 'schedule': schedule,
    };
  }
}

class RegistrationPayload {
  final String playerId;
  final List<String>? preferredRoles;
  final String? availability;
  final String? teamId;

  RegistrationPayload({
    required this.playerId,
    this.preferredRoles,
    this.availability,
    this.teamId,
  });

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      if (preferredRoles != null) 'preferredRoles': preferredRoles,
      if (availability != null) 'availability': availability,
      if (teamId != null) 'teamId': teamId,
    };
  }
}

