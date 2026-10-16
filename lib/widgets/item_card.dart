import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../link_utils.dart';
import '../models/item.dart';
import '../models/item_images.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  String get _title {
    if (item.title.isNotEmpty) return item.title;
    if (item.type == 'link' && item.url != null) return titleFromUrl(item.url!);
    if (item.type == 'image') {
      final n = item.imagePaths.length;
      return n > 1 ? '$n images' : 'Image';
    }
    return 'Note';
  }

  IconData get _icon {
    switch (item.type) {
      case 'link':
        return CupertinoIcons.link;
      case 'image':
        return CupertinoIcons.photo;
      default:
        return CupertinoIcons.doc_text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final photos = item.imagePaths;

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: p.isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('d MMM').format(item.createdAt).toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                    color: p.secondary,
                  ),
                ),
                const Spacer(),
                Icon(_icon, size: 14, color: p.secondary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                height: 1.25,
                decoration: item.archived ? TextDecoration.lineThrough : null,
              ),
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...item.tags.take(2).map((t) => TagPill(t)),
                  if (item.tags.length > 2)
                    TagPill('+${item.tags.length - 2}'),
                ],
              ),
            ],
            ..._preview(p, photos),
          ],
        ),
      ),
    );
  }

  List<Widget> _preview(Palette p, List<String> photos) {
    if (item.type == 'image' && photos.isNotEmpty) {
      return [
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Image.file(
                  File(photos.first),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 500,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: p.chip,
                    alignment: Alignment.center,
                    child: Icon(CupertinoIcons.photo, color: p.secondary),
                  ),
                ),
              ),
              if (photos.length > 1)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '+${photos.length - 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ];
    }

    if (item.type == 'link' && item.url != null) {
      return [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: p.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.globe, size: 13, color: p.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  Uri.tryParse(cleanUrl(item.url!))?.host ?? item.url!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: p.secondary),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final content = item.content ?? '';
    if (content.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      Text(
        content,
        maxLines: 7,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: p.text.withValues(alpha: 0.6),
        ),
      ),
    ];
  }
}

/// Small rounded tag, used on cards and the detail screen.
class TagPill extends StatelessWidget {
  final String label;
  final double fontSize;
  const TagPill(this.label, {super.key, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.8, vertical: fontSize * 0.35),
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.separator, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: p.secondary,
        ),
      ),
    );
  }
}
