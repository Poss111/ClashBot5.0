class UserProfile {
  final String userId;
  final String? email;
  final String? displayName;
  final String? name;
  final String? picture;
  final String? role;
  final String? mainRole;
  final String? offRole;
  final Map<String, List<String>>? favoriteChampions;

  UserProfile({
    required this.userId,
    this.email,
    this.displayName,
    this.name,
    this.picture,
    this.role,
    this.mainRole,
    this.offRole,
    this.favoriteChampions,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      role: json['role'] as String?,
      mainRole: json['mainRole'] as String?,
      offRole: json['offRole'] as String?,
      favoriteChampions: (json['favoriteChampions'] as Map<String, dynamic>?)?.map(
        (k, v) {
          final list = v is List ? v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() : <String>[];
          return MapEntry(k, list);
        },
      ),
    );
  }
}


