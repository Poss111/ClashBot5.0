class DraftSide {
  final List<String> firstRoundBans;
  final List<String> secondRoundBans;
  final List<String> firstRoundPicks;
  final List<String> secondRoundPicks;

  const DraftSide({
    required this.firstRoundBans,
    required this.secondRoundBans,
    required this.firstRoundPicks,
    required this.secondRoundPicks,
  });

  factory DraftSide.empty() {
    return const DraftSide(
      firstRoundBans: ['', '', ''],
      secondRoundBans: ['', ''],
      firstRoundPicks: ['', '', ''],
      secondRoundPicks: ['', ''],
    );
  }

  DraftSide copyWith({
    List<String>? firstRoundBans,
    List<String>? secondRoundBans,
    List<String>? firstRoundPicks,
    List<String>? secondRoundPicks,
  }) {
    return DraftSide(
      firstRoundBans: firstRoundBans ?? this.firstRoundBans,
      secondRoundBans: secondRoundBans ?? this.secondRoundBans,
      firstRoundPicks: firstRoundPicks ?? this.firstRoundPicks,
      secondRoundPicks: secondRoundPicks ?? this.secondRoundPicks,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstRoundBans': firstRoundBans,
        'secondRoundBans': secondRoundBans,
        'firstRoundPicks': firstRoundPicks,
        'secondRoundPicks': secondRoundPicks,
      };

  factory DraftSide.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DraftSide.empty();
    List<String> _list(dynamic value, int expectedLength) {
      final items = (value as List<dynamic>? ?? []).map((e) => e?.toString() ?? '').toList();
      if (items.length < expectedLength) {
        return [...items, ...List.filled(expectedLength - items.length, '')];
      }
      if (items.length > expectedLength) {
        return items.take(expectedLength).toList();
      }
      return items;
    }

    return DraftSide(
      firstRoundBans: _list(json['firstRoundBans'], 3),
      secondRoundBans: _list(json['secondRoundBans'], 2),
      firstRoundPicks: _list(json['firstRoundPicks'], 3),
      secondRoundPicks: _list(json['secondRoundPicks'], 2),
    );
  }
}

class DraftProposal {
  final String tournamentId;
  final String teamId;
  final DraftSide ourSide;
  final DraftSide enemySide;
  final String? notes;
  final String? updatedBy;
  final String? updatedAt;

  const DraftProposal({
    required this.tournamentId,
    required this.teamId,
    required this.ourSide,
    required this.enemySide,
    this.notes,
    this.updatedBy,
    this.updatedAt,
  });

  factory DraftProposal.empty({required String tournamentId, required String teamId}) {
    return DraftProposal(
      tournamentId: tournamentId,
      teamId: teamId,
      ourSide: DraftSide.empty(),
      enemySide: DraftSide.empty(),
      notes: '',
      updatedBy: null,
      updatedAt: null,
    );
  }

  DraftProposal copyWith({
    DraftSide? ourSide,
    DraftSide? enemySide,
    String? notes,
    String? updatedBy,
    String? updatedAt,
  }) {
    return DraftProposal(
      tournamentId: tournamentId,
      teamId: teamId,
      ourSide: ourSide ?? this.ourSide,
      enemySide: enemySide ?? this.enemySide,
      notes: notes ?? this.notes,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'teamId': teamId,
        'ourSide': ourSide.toJson(),
        'enemySide': enemySide.toJson(),
        if (notes != null) 'notes': notes,
        if (updatedBy != null) 'updatedBy': updatedBy,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  factory DraftProposal.fromJson(Map<String, dynamic> json) {
    final tournamentId = json['tournamentId']?.toString() ?? '';
    final teamId = json['teamId']?.toString() ?? '';
    return DraftProposal(
      tournamentId: tournamentId,
      teamId: teamId,
      ourSide: DraftSide.fromJson(json['ourSide'] as Map<String, dynamic>?),
      enemySide: DraftSide.fromJson(json['enemySide'] as Map<String, dynamic>?),
      notes: json['notes'] as String?,
      updatedBy: json['updatedBy'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

