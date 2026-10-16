import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'main.dart';
import 'screens/create_edit_screen.dart';

/// Increases every time a shared item is saved, so screens can refresh.
final ValueNotifier<int> sharedItemsChanged = ValueNotifier(0);

const _maxTextLength = 10000;
const _maxImages = 10;
const _maxImageBytes = 25 * 1024 * 1024; // 25 MB
const _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'];

final _urlRegex = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

class ShareHandler extends StatefulWidget {
  final Widget child;
  const ShareHandler({super.key, required this.child});

  @override
  State<ShareHandler> createState() => _ShareHandlerState();
}

class _ShareHandlerState extends State<ShareHandler> {
  StreamSubscription? _subscription;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    // App already open
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _safeHandle,
      onError: (_) => _toast('Couldn’t read what was shared.'),
    );

    // App opened by the share – wait for the first frame so navigation works
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeHandle(files);
        ReceiveSharingIntent.instance.reset();
      });
    }).catchError((_) => _toast('Couldn’t read what was shared.'));
  }

  /// Never lets a bad share crash the app.
  Future<void> _safeHandle(List<SharedMediaFile> files) async {
    if (_busy) return; // ignore a second share while one is being handled
    _busy = true;
    try {
      await _handle(files);
    } catch (e) {
      debugPrint('Share failed: $e');
      _toast('Something went wrong with that share.');
    } finally {
      _busy = false;
    }
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final texts = <String>[];
    final images = <String>[];
    var skipped = 0;

    for (final f in files) {
      switch (f.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          final t = f.path.trim();
          if (t.isNotEmpty) texts.add(t);
          break;
        case SharedMediaType.image:
          if (images.length >= _maxImages) {
            skipped++;
            break;
          }
          final copied = await _copyImage(f.path);
          copied == null ? skipped++ : images.add(copied);
          break;
        default: // video, files, anything else
          skipped++;
      }
    }

    if (texts.isEmpty && images.isEmpty) {
      _toast(skipped > 0
          ? 'Stash can only save text, links and images.'
          : 'Nothing to save – the shared content was empty.');
      return;
    }
    if (skipped > 0) {
      _toast('$skipped item(s) couldn’t be added and were skipped.');
    }

    if (images.isNotEmpty) {
      await _openEditor(CreateEditScreen(
        initialType: 'image',
        initialImages: images,
        initialTitle: texts.isNotEmpty ? _shorten(texts.first, 100) : null,
      ));
      return;
    }

    var text = texts.join('\n');
    if (text.length > _maxTextLength) {
      text = text.substring(0, _maxTextLength);
      _toast('Text was very long, so it was shortened.');
    }

    // Chrome often shares "Article title https://link" – pull the link out
    final match = _urlRegex.firstMatch(text);
    final url = match?.group(0);
    final uri = url == null ? null : Uri.tryParse(url);

    if (uri != null && uri.host.contains('.')) {
      final rest = text.replaceFirst(url!, '').trim();
      await _openEditor(CreateEditScreen(
        initialType: 'link',
        initialUrl: url,
        initialTitle: rest.isEmpty ? null : _shorten(rest, 100),
      ));
    } else {
      await _openEditor(CreateEditScreen(
        initialType: 'note',
        initialContent: text,
      ));
    }
  }

  /// Copies a shared image into app storage. Returns null if it's unusable.
  Future<String?> _copyImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final lower = path.toLowerCase();
      if (!_imageExtensions.any(lower.endsWith)) return null;

      final size = await file.length();
      if (size == 0 || size > _maxImageBytes) return null;

      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/images');
      await imagesDir.create(recursive: true);
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_${path.split('/').last}';
      return (await file.copy('${imagesDir.path}/$name')).path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEditor(Widget screen) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final saved = await nav.push<bool>(
      CupertinoPageRoute(fullscreenDialog: true, builder: (_) => screen),
    );
    if (saved == true) {
      sharedItemsChanged.value++;
      _toast('Saved to Stash');
    }
  }

  String _shorten(String s, int max) {
    final line = s.split('\n').first.trim();
    return line.length > max ? line.substring(0, max) : line;
  }

  void _toast(String message) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
