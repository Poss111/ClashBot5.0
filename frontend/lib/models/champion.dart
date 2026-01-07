class Champion {
  final String id;
  final String key;
  final String name;
  final String title;
  final List<String> tags;
  final String imageFull;

  Champion({
    required this.id,
    required this.key,
    required this.name,
    required this.title,
    required this.tags,
    required this.imageFull,
  });

  factory Champion.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    return Champion(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tags: tags,
      imageFull: (json['image'] as Map<String, dynamic>?)?['full']?.toString() ?? '',
    );
  }
}

