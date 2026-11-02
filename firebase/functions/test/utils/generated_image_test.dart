import 'dart:convert';

import 'package:data_models/utils/generated_image.dart';
import 'package:test/test.dart';

void main() {
  group('generatedImageUrl', () {
    test('returns an SVG data URL', () {
      final url = generatedImageUrl('user-1');
      expect(url, startsWith('data:image/svg+xml;base64,'));
      final svg = utf8.decode(base64Decode(url.split(',').last));
      expect(svg, contains('<svg'));
    });

    test('is stable for a seed and differs between seeds', () {
      expect(generatedImageUrl('a'), generatedImageUrl('a'));
      expect(generatedImageUrl('a'), isNot(generatedImageUrl('b')));
    });
  });

  group('replaceLegacyPlaceholderUrl', () {
    test('maps picsum URLs to the generated image for their seed', () {
      expect(
        replaceLegacyPlaceholderUrl('https://picsum.photos/seed/abc/160'),
        generatedImageUrl('abc'),
      );
    });

    test('leaves other URLs unchanged', () {
      const url = 'https://lh3.googleusercontent.com/a/photo';
      expect(replaceLegacyPlaceholderUrl(url), url);
    });
  });

  group('externalImageUrl', () {
    test('drops data URLs, picsum URLs and null', () {
      expect(externalImageUrl(generatedImageUrl('x')), '');
      expect(externalImageUrl('https://picsum.photos/seed/x/512'), '');
      expect(externalImageUrl(null), '');
    });

    test('keeps other URLs', () {
      const url = 'https://example.org/logo.png';
      expect(externalImageUrl(url), url);
    });
  });
}
