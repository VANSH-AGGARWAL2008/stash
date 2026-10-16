import 'dart:convert';

/// A single saved item in the inbox.
///
/// [type] is one of: 'note', 'link', 'image'.
/// Exactly one of [content], [url], or [imagePath] is populated,
/// depending on the type.
class Item {
  final String id;
  final String type;
  final String title;
  final String? content;   // for notes
  final String? url;      // for links
  final String? imagePath; // for images
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;

  const Item({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    this.url,
    this.imagePath,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  Item copyWith({
    String? type,
    String? title,
    String? content,
    String? url,
    String? imagePath,
    List<String>? tags,
    DateTime? updatedAt,
    bool? archived,
  }) {
    return Item(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      url: url ?? this.url,
      imagePath: imagePath ?? this.imagePath,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'url': url,
      'image_path': imagePath,
      'tags': jsonEncode(tags),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'archived': archived ? 1 : 0,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      content: map['content'] as String?,
      url: map['url'] as String?,
      imagePath: map['image_path'] as String?,
      tags: (jsonDecode(map['tags'] as String? ?? '[]') as List)
          .map((e) => e.toString())
          .toList(),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      archived: (map['archived'] as int) == 1,
    );
  }
}