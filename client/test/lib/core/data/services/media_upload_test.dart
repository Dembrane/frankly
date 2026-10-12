import 'package:client/core/data/services/firebase_storage_media_uploader.dart';
import 'package:client/core/data/services/media_helper_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaHelperService.urlHasExtension', () {
    test('matches Cloudinary-style URLs', () {
      expect(
        MediaHelperService.urlHasExtension(
          'https://res.cloudinary.com/x/video/upload/v1/clip.mp4',
          'mp4',
        ),
        isTrue,
      );
    });

    test('ignores the query string of Firebase Storage download URLs', () {
      const url = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/'
          'media%2Fuid%2F1700000000000-abc.mp4?alt=media&token=123';
      expect(MediaHelperService.urlHasExtension(url, '.mp4'), isTrue);
      expect(MediaHelperService.urlHasExtension(url, 'webm'), isFalse);
    });

    test('is case-insensitive', () {
      expect(
        MediaHelperService.urlHasExtension('https://a.b/c/VIDEO.MP4', 'mp4'),
        isTrue,
      );
    });
  });

  group('FirebaseStorageMediaUploader', () {
    test('stores phone .mov videos as mp4', () {
      final extension = FirebaseStorageMediaUploader.storedExtensionFor('mov');
      expect(extension, 'mp4');
      expect(
          FirebaseStorageMediaUploader.contentTypeFor(extension), 'video/mp4');
    });

    test('maps image extensions to content types', () {
      expect(
        FirebaseStorageMediaUploader.contentTypeFor(
          FirebaseStorageMediaUploader.storedExtensionFor('jpeg'),
        ),
        'image/jpeg',
      );
      expect(FirebaseStorageMediaUploader.contentTypeFor('png'), 'image/png');
      expect(FirebaseStorageMediaUploader.contentTypeFor('webm'), 'video/webm');
    });
  });
}
