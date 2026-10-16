import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../database/database_helper.dart';
import '../models/item_images.dart';
import '../share_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'package:archive/archive_io.dart';


class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _db = DatabaseHelper.instance;
  bool _working = false;

  // ---------- Export ----------
    Future<void> _export() async {
    setState(() => _working = true);
    try {
      final items = await _db.getAllItems();
      final imageFiles = <String>[];

      final data = items.map((i) {
        final photos = i.imagePaths;
        for (final path in photos) {
          if (File(path).existsSync()) imageFiles.add(path);
        }
        return {
          'id': i.id,
          'type': i.type,
          'title': i.title,
          'content': i.content,
          'url': i.url,
          'images': photos.map((p) => 'images/${p.split('/').last}').toList(),
          'tags': i.tags,
          'archived': i.archived,
          'createdAt': i.createdAt.toIso8601String(),
          'updatedAt': i.updatedAt.toIso8601String(),
        };
      }).toList();

      final json = const JsonEncoder.withIndent('  ').convert({
        'app': 'Stash',
        'exportedAt': DateTime.now().toIso8601String(),
        'itemCount': items.length,
        'items': data,
      });

      final dir = await getTemporaryDirectory();
      final jsonFile = File('${dir.path}/stash_export.json');
      await jsonFile.writeAsString(json);

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final zipPath = '${dir.path}/stash_export_$stamp.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(jsonFile, 'stash_export.json');
      for (final path in imageFiles) {
        await encoder.addFile(File(path), 'images/${path.split('/').last}');
      }
      await encoder.close();

      await SharePlus.instance.share(ShareParams(
        files: [XFile(zipPath, mimeType: 'application/zip')],
        subject: 'My Stash export (${items.length} items)',
      ));
    } catch (e) {
      debugPrint('Export failed: $e');
      _alert('Export failed', 'Please try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }



  // ---------- Delete everything ----------
  Future<void> _confirmDelete() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Delete your account and all data?'),
        content: const Text(
            'Every note, link, image and setting will be permanently removed '
            'from this phone. Export first if you want a copy.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _working = true);
    try {
      // 1. Database rows
      final items = await _db.getAllItems();
      for (final item in items) {
        await _db.deleteItem(item.id);
      }
      // 2. All stored image files (saved + shared)
      final docs = await getApplicationDocumentsDirectory();
      for (final entity in docs.listSync()) {
        if (entity is File && !entity.path.endsWith('.db')) {
          await entity.delete();
        } else if (entity is Directory && entity.path.endsWith('images')) {
          await entity.delete(recursive: true);
        }
      }
      // 3. Settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await setThemeMode(ThemeMode.system);
      // 4. Temp export files
      final tmp = await getTemporaryDirectory();
      if (await tmp.exists()) {
        for (final e in tmp.listSync()) {
          try { await e.delete(recursive: true); } catch (_) {}
        }
      }

      sharedItemsChanged.value++;
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await _alert('All data deleted', 'Stash is now empty.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _alert('Delete failed', 'Some data could not be removed. Please try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _alert(String title, String msg) => showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: CupertinoNavigationBar(
        previousPageTitle: 'Stash',
        middle: const Text('Your Data'),
        backgroundColor: p.bg.withValues(alpha: 0.85),
        border: null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _button(p, CupertinoIcons.square_arrow_up, 'Export my data',
              'JSON file plus all your images', _export, false),
          const SizedBox(height: 12),
                    _button(p, CupertinoIcons.trash, 'Delete account & all data',
              'Erase every item, image and setting', _confirmDelete, true),

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: p.card, borderRadius: BorderRadius.circular(18)),
            child: Text(
              'What happens to your data\n\n'
                            '• Stash has no online account. Your account is the data stored '
              'in the app on this phone, so deleting it deletes your account.\n\n'
              '• Stash stores everything only on this phone. Nothing is sent '
              'to any server.\n\n'
              '• Export creates a readable JSON file with all your items and '
              'attaches your images. You choose where to send it.\n\n'
              '• Delete removes every item from the database, deletes all '
              'saved images, and resets your settings. This cannot be undone '
              'and there is no backup copy.\n\n'
              '• Uninstalling the app also removes all of its data.',
              style: TextStyle(fontSize: 14, height: 1.5, color: p.secondary),
            ),
          ),
          if (_working) ...[
            const SizedBox(height: 24),
            const CupertinoActivityIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _button(Palette p, IconData icon, String title, String sub,
      VoidCallback onTap, bool danger) {
    final colour = danger ? p.danger : p.text;
    return Pressable(
      onTap: _working ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: p.card, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(icon, color: colour),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: colour)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(fontSize: 13, color: p.secondary)),
            ]),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: p.secondary),
        ]),
      ),
    );
  }
}
