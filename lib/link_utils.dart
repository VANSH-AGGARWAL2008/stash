import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Finds the first http/https link inside any text.
String? extractUrl(String text) {
  final match = RegExp(r'https?://[^\s]+').firstMatch(text);
  return match?.group(0);
}

/// Turns google.com/url?q=REAL_LINK into REAL_LINK.
String cleanUrl(String raw) {
  final url = raw.trim();
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (uri.host.contains('google.') && uri.path == '/url') {
    final target = uri.queryParameters['q'] ?? uri.queryParameters['url'];
    if (target != null && target.startsWith('http')) return target;
  }
  return url;
}

/// https://www.fotmob.com/match/123  ->  "Fotmob"
String titleFromUrl(String url) {
  final host = Uri.tryParse(cleanUrl(url))?.host ?? '';
  if (host.isEmpty) return 'Link';

  const known = {
    'youtu.be': 'YouTube',
    'youtube.com': 'YouTube',
    'x.com': 'X',
    'twitter.com': 'X',
    'instagram.com': 'Instagram',
    'reddit.com': 'Reddit',
    'github.com': 'GitHub',
  };

  final clean = host.replaceFirst(RegExp(r'^(www\d?|m|mobile)\.'), '');
  if (known.containsKey(clean)) return known[clean]!;

  final name = clean.split('.').first;
  return name.isEmpty ? 'Link' : name[0].toUpperCase() + name.substring(1);
}

/// Opens a link in the browser or the matching app.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(cleanUrl(url));
  final opened = uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link')),
    );
  }
}
