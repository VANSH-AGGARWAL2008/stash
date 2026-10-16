import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../link_utils.dart';
import '../models/item.dart';
import '../models/item_images.dart';
import '../theme/app_theme.dart';
import '../widgets/image_order_editor.dart';
import '../widgets/pressable.dart';

class CreateEditScreen extends StatefulWidget {
  final Item? existing;
  final String? initialType;     // 'note', 'link' or 'image'
  final String? initialTitle;
  final String? initialContent;
  final String? initialUrl;
  final List<String>? initialImages;

  const CreateEditScreen({
    super.key,
    this.existing,
    this.initialType,
    this.initialTitle,
    this.initialContent,
    this.initialUrl,
    this.initialImages,
  });

  @override
  State<CreateEditScreen> createState() => _CreateEditScreenState();
}


class _CreateEditScreenState extends State<CreateEditScreen> {
  final _db = DatabaseHelper.instance;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _urlController = TextEditingController();
  final _tagController = TextEditingController();
  final _picker = ImagePicker();

  String _type = 'note';
  List<String> _imagePaths = [];
  final List<String> _tags = [];
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

    @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _type = item.type;
      _titleController.text = item.title;
      _contentController.text = item.content ?? '';
      _urlController.text = item.url ?? '';
      _imagePaths = item.imagePaths;
      _tags.addAll(item.tags);
    } else {
      // Pre-filled from a share
      _type = widget.initialType ?? 'note';
      _titleController.text = widget.initialTitle ?? '';
      _contentController.text = widget.initialContent ?? '';
      _urlController.text = widget.initialUrl ?? '';
      _imagePaths = [...?widget.initialImages];
    }
  }


  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _urlController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ---------- Images ----------

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'images'));
    await imagesDir.create(recursive: true);

    final newPaths = <String>[];
    for (final x in picked) {
      final ext = p.extension(x.path);
      final saved = File(p.join(imagesDir.path, '${const Uuid().v4()}$ext'));
      await File(x.path).copy(saved.path);
      newPaths.add(saved.path);
    }
    if (!mounted) return;
    setState(() => _imagePaths = [..._imagePaths, ...newPaths]);
  }

  // ---------- Tags ----------

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    if (tag.length > 30) {
      _showError('Tags can be up to 30 characters.');
      return;
    }
    if (!_tags.contains(tag)) {
      HapticFeedback.selectionClick();
      setState(() => _tags.add(tag));
    }
    _tagController.clear();
  }

  // ---------- Save ----------

  Future<void> _save() async {
    var title = _titleController.text.trim();
    String? content;
    String? url;

    if (_type == 'note') {
      content = _contentController.text.trim();
      if (title.isEmpty && content.isEmpty) {
        _showError('Add a title or some content.');
        return;
      }
      if (title.isEmpty) {
        final firstLine = content.split('\n').first;
        title = firstLine.length > 40
            ? '${firstLine.substring(0, 40)}…'
            : firstLine;
      }
    } else if (_type == 'link') {
      url = _urlController.text.trim();
      if (url.isEmpty) {
        _showError('Enter a URL.');
        return;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      url = cleanUrl(url);
      final host = Uri.tryParse(url)?.host ?? '';
      if (!host.contains('.') || url.contains(' ')) {
        _showError('Enter a valid URL, like example.com');
        return;
      }
      if (title.isEmpty) title = titleFromUrl(url);
    } else if (_type == 'image') {
      if (_imagePaths.isEmpty) {
        _showError('Pick at least one image.');
        return;
      }
      if (title.isEmpty) {
        title = _imagePaths.length == 1
            ? 'Image'
            : '${_imagePaths.length} images';
      }
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final item = Item(
      id: widget.existing?.id ?? const Uuid().v4(),
      type: _type,
      title: title,
      content: content,
      url: url,
      imagePath: _type == 'image' ? encodeImagePaths(_imagePaths) : null,
      tags: List.from(_tags),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
      archived: widget.existing?.archived ?? false,
    );

    if (_isEditing) {
      await _db.updateItem(item);
    } else {
      await _db.insertItem(item);
    }

    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Can’t save yet'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: CupertinoNavigationBar(
        backgroundColor: pal.bg.withValues(alpha: 0.85),
        border: null,
        automaticallyImplyLeading: false,
        transitionBetweenRoutes: false,
        leading: Pressable(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('Cancel',
                style: TextStyle(fontSize: 17, color: pal.text)),
          ),
        ),
        middle: Text(_isEditing ? 'Edit' : 'New'),
        trailing: _saving
            ? const CupertinoActivityIndicator()
            : Pressable(
                onTap: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: pal.text,
                    ),
                  ),
                ),
              ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // Note / Link / Image switch
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _type,
                backgroundColor: pal.fill,
                thumbColor: pal.thumb,
                children: {
                  'note': _segment(CupertinoIcons.doc_text, 'Note', pal),
                  'link': _segment(CupertinoIcons.link, 'Link', pal),
                  'image': _segment(CupertinoIcons.photo, 'Image', pal),
                },
                onValueChanged: (v) {
                  if (v == null) return;
                  HapticFeedback.selectionClick();
                  setState(() => _type = v);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Title + content / URL
            _section(pal, [
              _field(
                controller: _titleController,
                hint: _type == 'link' ? 'Title (optional)' : 'Title',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
                maxLength: 100,
                pal: pal,
              ),
              if (_type == 'note') ...[
                Divider(height: 0.5, thickness: 0.5, color: pal.separator),
                _field(
                  controller: _contentController,
                  hint: 'Start writing…',
                  minLines: 8,
                  maxLines: null,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  pal: pal,
                ),
              ],
              if (_type == 'link') ...[
                Divider(height: 0.5, thickness: 0.5, color: pal.separator),
                _field(
                  controller: _urlController,
                  hint: 'https://example.com',
                  keyboard: TextInputType.url,
                  pal: pal,
                ),
              ],
            ]),

            // Photos
            if (_type == 'image') ...[
              const SizedBox(height: 20),
              _imageArea(pal),
            ],

            // Tags
            const SizedBox(height: 28),
            _header('TAGS', pal),
            _section(pal, [
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _tagController,
                      hint: 'Add a tag',
                      onSubmitted: (_) => _addTag(),
                      pal: pal,
                    ),
                  ),
                  Pressable(
                    scale: 0.85,
                    onTap: _addTag,
                    child: Icon(CupertinoIcons.add_circled_solid,
                        size: 26, color: pal.text),
                  ),
                ],
              ),
            ]),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map((t) => Pressable(
                          onTap: () => setState(() => _tags.remove(t)),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                            decoration: BoxDecoration(
                              color: pal.card,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(width: 6),
                                Icon(CupertinoIcons.xmark_circle_fill,
                                    size: 16, color: pal.secondary),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(IconData icon, String label, Palette pal) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: pal.text),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pal.text)),
          ],
        ),
      );

  Widget _header(String text, Palette pal) => Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, letterSpacing: 0.6, color: pal.secondary)),
      );

  Widget _section(Palette pal, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: children),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required Palette pal,
    TextStyle? style,
    int? maxLength,
    int? minLines,
    int? maxLines = 1,
    TextInputType? keyboard,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      style: style ?? const TextStyle(fontSize: 16),
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboard,
      onSubmitted: onSubmitted,
      inputFormatters: maxLength == null
          ? null
          : [LengthLimitingTextInputFormatter(maxLength)],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.secondary),
        border: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _imageArea(Palette pal) {
    if (_imagePaths.isEmpty) {
      return Pressable(
        onTap: _pickImages,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.photo_on_rectangle,
                  size: 34, color: pal.secondary),
              const SizedBox(height: 10),
              const Text('Add photos',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_imagePaths.length > 1) _header('DRAG ≡ TO REORDER', pal),
        ImageOrderEditor(
          paths: _imagePaths,
          onChanged: (list) => setState(() => _imagePaths = list),
        ),
        const SizedBox(height: 4),
        Pressable(
          onTap: _pickImages,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(CupertinoIcons.add_circled, size: 20, color: pal.text),
                const SizedBox(width: 8),
                const Text('Add more photos',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
