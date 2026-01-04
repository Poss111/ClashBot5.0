class UserProfile {
  final String userId;
  final String? email;
  final String? displayName;
  final String? name;
  final String? picture;
  final String? role;

  UserProfile({
    required this.userId,
    this.email,
    this.displayName,
    this.name,
    this.picture,
    this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      role: json['role'] as String?,
    );
  }
}


