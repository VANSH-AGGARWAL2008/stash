import 'dart:convert';
import 'item.dart';

extension ItemImages on Item {
  /// All photos of this item, in order.
  List<String> get imagePaths {
    final raw = imagePath;
    if (raw == null || raw.isEmpty) return [];
    if (raw.startsWith('[')) {
      return List<String>.from(jsonDecode(raw));
    }
    return [raw]; // old items with a single photo
  }
}

/// Turns a list of photo paths into the value stored in imagePath.
String? encodeImagePaths(List<String> paths) {
  if (paths.isEmpty) return null;
  if (paths.length == 1) return paths.first;
  return jsonEncode(paths);
}
