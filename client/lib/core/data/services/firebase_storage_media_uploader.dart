import 'dart:math';

import 'package:client/core/utils/visible_exception.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Lets a signed-in user pick an image or video and uploads it to the app's
/// Firebase Storage bucket (FIREBASE_STORAGE_BUCKET). Used instead of
/// Cloudinary when MEDIA_UPLOAD_PROVIDER is `firebase`, so uploaded media stays
/// in the same Google Cloud project, and region, as the rest of the app data.
///
/// Files are stored under `media/{uid}/` and returned as download URLs, which
/// anyone with the link can read, like Cloudinary's public URLs.
class FirebaseStorageMediaUploader {
  static const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  /// Phone .mov files are usually H.264, which browsers play as mp4. They are
  /// stored with an .mp4 name and type, as Cloudinary did when it transcoded.
  static const videoExtensions = ['mp4', 'webm', 'mov'];

  /// Keep in sync with firebase/storage.rules.
  static const maxImageBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 500 * 1024 * 1024;

  final FirebaseStorage? _storage;
  final FirebaseAuth? _auth;

  FirebaseStorageMediaUploader({FirebaseStorage? storage, FirebaseAuth? auth})
      : _storage = storage,
        _auth = auth;

  /// Returns the download URL, or null when the user cancels the picker.
  Future<String?> pickAndUpload({
    required bool allowImages,
    required bool allowVideos,
  }) async {
    final allowedExtensions = [
      if (allowImages) ...imageExtensions,
      if (allowVideos) ...videoExtensions,
    ];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final extension = (file.extension ?? '').toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw VisibleException('This file type is not supported.');
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw VisibleException('The selected file could not be read.');
    }

    final isVideo = videoExtensions.contains(extension);
    if (isVideo && bytes.length > maxVideoBytes) {
      throw VisibleException('Videos can be at most 500 MB.');
    }
    if (!isVideo && bytes.length > maxImageBytes) {
      throw VisibleException('Images can be at most 10 MB.');
    }

    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null || user.isAnonymous) {
      throw VisibleException('Sign in to upload images and videos.');
    }

    final storedExtension = storedExtensionFor(extension);
    final ref = (_storage ?? FirebaseStorage.instance)
        .ref('media/${user.uid}/${_uniqueFileName(storedExtension)}');
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentTypeFor(storedExtension),
        cacheControl: 'public, max-age=31536000',
      ),
    );
    return ref.getDownloadURL();
  }

  static String storedExtensionFor(String extension) {
    switch (extension) {
      case 'mov':
        return 'mp4';
      case 'jpeg':
        return 'jpg';
      default:
        return extension;
    }
  }

  static String contentTypeFor(String storedExtension) {
    switch (storedExtension) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'jpg':
        return 'image/jpeg';
      default:
        return 'image/$storedExtension';
    }
  }

  static String _uniqueFileName(String extension) {
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${DateTime.now().millisecondsSinceEpoch}-$suffix.$extension';
  }
}
