import 'dart:io';
import 'package:flutter/material.dart';

/// Shows photos in a list. Long-press and drag to change the order.
class ImageOrderEditor extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<List<String>> onChanged;

  const ImageOrderEditor({
    super.key,
    required this.paths,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (oldIndex, newIndex) {
        final list = [...paths];
        list.insert(newIndex, list.removeAt(oldIndex));
        onChanged(list);
      },

      children: [
        for (int i = 0; i < paths.length; i++)
          Card(
            key: ValueKey(paths[i]),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(paths[i]),
                    width: 56, height: 56, fit: BoxFit.cover),
              ),
              title: Text('Photo ${i + 1}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => onChanged([...paths]..removeAt(i)),
                  ),
                  const Icon(Icons.drag_handle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
