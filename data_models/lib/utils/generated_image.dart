import 'dart:convert';

/// Builds a placeholder image locally as an SVG data URL, so default avatars
/// and cover images need no third-party image service. The same seed always
/// gives the same image.
String generatedImageUrl(String seed) {
  final hash = _stableHash(seed);
  final hue = hash % 360;
  final secondHue = (hue + 30 + (hash >> 9) % 90) % 360;
  final x2 = (hash >> 4) % 2;
  final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="512" '
      'height="512" viewBox="0 0 512 512">'
      '<defs><linearGradient id="g" x1="0" y1="0" x2="$x2" y2="1">'
      '<stop offset="0" stop-color="hsl($hue,60%,60%)"/>'
      '<stop offset="1" stop-color="hsl($secondHue,55%,38%)"/>'
      '</linearGradient></defs>'
      '<rect width="512" height="512" fill="url(#g)"/></svg>';
  return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
}

/// Images stored before default images were generated locally point at
/// picsum.photos. Returns the local replacement for such a URL, keeping its
/// seed, or the URL unchanged otherwise.
String replaceLegacyPlaceholderUrl(String url) {
  if (!url.contains('picsum.photos')) return url;
  final seed = RegExp(r'picsum\.photos/seed/([^/?]+)').firstMatch(url)?.group(1);
  return generatedImageUrl(seed ?? url);
}

/// Returns [url] if a mail client or link-preview crawler can load it, or an
/// empty string for generated data URLs and legacy picsum.photos URLs.
String externalImageUrl(String? url) {
  if (url == null ||
      url.startsWith('data:') ||
      url.contains('picsum.photos')) {
    return '';
  }
  return url;
}

// String.hashCode differs between the Dart VM and compiled JavaScript, so the
// seed is hashed by hand. Masking keeps the value exact in JavaScript numbers.
int _stableHash(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
