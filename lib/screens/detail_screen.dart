import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../link_utils.dart';
import '../models/item.dart';
import '../models/item_images.dart';
import '../theme/app_theme.dart';
import '../widgets/item_card.dart';
import '../widgets/pressable.dart';
import 'create_edit_screen.dart';

class DetailScreen extends StatefulWidget {
  final String itemId;
  const DetailScreen({super.key, required this.itemId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _db = DatabaseHelper.instance;
  Item? _item;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await _db.getItem(widget.itemId);
    if (!mounted) return;
    setState(() => _item = item);
  }

  String _title(Item item) {
    if (item.title.isNotEmpty) return item.title;
    if (item.type == 'link' && item.url != null) return titleFromUrl(item.url!);
    if (item.type == 'image') {
      final n = item.imagePaths.length;
      return n > 1 ? '$n images' : 'Image';
    }
    return 'Note';
  }

  Future<void> _edit() async {
    final item = _item;
    if (item == null) return;
    await Navigator.push(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateEditScreen(existing: item),
      ),
    );
    _load();
  }

  Future<void> _toggleArchive() async {
    final item = _item;
    if (item == null) return;
    await _db.updateItem(
      item.copyWith(archived: !item.archived, updatedAt: DateTime.now()),
    );
    _load();
  }

  Future<void> _delete() async {
    final item = _item;
    if (item == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteItem(item.id);
    if (mounted) Navigator.pop(context);
  }

  void _showActions() {
    final item = _item;
    if (item == null) return;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _edit();
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleArchive();
            },
            child: Text(item.archived ? 'Restore' : 'Archive'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _delete();
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _openPhotos(List<String> photos, int start) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _PhotoViewer(photos: photos, start: start),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final item = _item;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: CupertinoNavigationBar(
        previousPageTitle: 'All Notes',
        backgroundColor: p.bg.withValues(alpha: 0.85),
        border: null,
        transitionBetweenRoutes: false,
        middle: item != null && item.archived ? const Text('Archived') : null,
        trailing: Pressable(
          scale: 0.85,
          onTap: _showActions,
          child: Icon(CupertinoIcons.ellipsis_circle, size: 25, color: p.text),
        ),
      ),
      body: item == null
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Text(
                  _title(item),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _infoRow(p, 'Created', _fmt(item.createdAt)),
                      Divider(height: 0.5, thickness: 0.5, color: p.separator),
                      _infoRow(p, 'Last Modified', _fmt(item.updatedAt)),
                      Divider(height: 0.5, thickness: 0.5, color: p.separator),
                      _infoRow(p, 'Type',
                          item.type[0].toUpperCase() + item.type.substring(1)),
                    ],
                  ),
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        item.tags.map((t) => TagPill(t, fontSize: 13)).toList(),
                  ),
                ],
                const SizedBox(height: 28),
                ..._body(p, item),
              ],
            ),
    );
  }

  String _fmt(DateTime d) => DateFormat('d MMM yyyy, HH:mm').format(d);

  Widget _infoRow(Palette p, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 15, color: p.secondary)),
          ],
        ),
      );

  List<Widget> _body(Palette p, Item item) {
    if (item.type == 'link' && item.url != null) {
      return [
        Pressable(
          onTap: () => openLink(context, item.url!),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: p.text,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(CupertinoIcons.link, color: p.bg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleFromUrl(item.url!),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cleanUrl(item.url!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.secondary),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.arrow_up_right, size: 18, color: p.secondary),
              ],
            ),
          ),
        ),
      ];
    }

    if (item.type == 'image') {
      final photos = item.imagePaths;
      if (photos.isEmpty) return [];
      if (photos.length == 1) {
        return [_photo(p, photos, 0, null)];
      }
      return [
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (int i = 0; i < photos.length; i++) _photo(p, photos, i, 1),
          ],
        ),
      ];
    }

    return [
      SelectableText(
        item.content ?? '',
        style: TextStyle(
          fontSize: 16,
          height: 1.65,
          color: p.text.withValues(alpha: 0.85),
        ),
      ),
    ];
  }

  Widget _photo(Palette p, List<String> photos, int i, double? square) {
    final image = Image.file(
      File(photos[i]),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        height: 160,
        color: p.card,
        alignment: Alignment.center,
        child: Icon(CupertinoIcons.photo, color: p.secondary),
      ),
    );
    return Pressable(
      onTap: () => _openPhotos(photos, i),
      child: Hero(
        tag: photos[i],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: square == null
              ? image
              : AspectRatio(aspectRatio: square, child: image),
        ),
      ),
    );
  }
}

/// Full-screen photo viewer: swipe between photos, pinch to zoom.
class _PhotoViewer extends StatelessWidget {
  final List<String> photos;
  final int start;
  const _PhotoViewer({required this.photos, required this.start});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: start),
            itemCount: photos.length,
            itemBuilder: (_, i) => Center(
              child: Hero(
                tag: photos[i],
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.file(File(photos[i])),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Pressable(
                scale: 0.85,
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.xmark,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
