class Tournament {
  final String tournamentId;
  final String? name;
  final String startTime;
  final String? region;
  final String? status;

  Tournament({
    required this.tournamentId,
    this.name,
    required this.startTime,
    this.region,
    this.status,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      tournamentId: json['tournamentId'] as String,
      name: json['name'] as String?,
      startTime: json['startTime'] as String,
      region: json['region'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      if (name != null) 'name': name,
      'startTime': startTime,
      if (region != null) 'region': region,
      if (status != null) 'status': status,
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

