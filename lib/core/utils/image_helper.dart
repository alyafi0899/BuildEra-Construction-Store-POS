import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/app_theme.dart';

class ImageHelper {
  /// Picks an image, crops it (if supported), and returns the bytes
  static Future<Uint8List?> pickAndCropImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    final pickedFile = result.files.first;

    final supportsNativeCropper = !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        pickedFile.path != null;
    if (supportsNativeCropper) {
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path!,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Potong Gambar',
              toolbarColor: AppTheme.accent,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Potong Gambar',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          return await croppedFile.readAsBytes();
        }
      } catch (e) {
        debugPrint('Image crop failed; using the selected image instead: $e');
      }
    }

    if (pickedFile.bytes != null) return pickedFile.bytes;
    if (pickedFile.path != null && !kIsWeb) {
      return File(pickedFile.path!).readAsBytes();
    }
    return null;
  }

  /// Compresses and resizes image to a safe max dimension for local brand asset usage.
  static Future<Uint8List> processImage(Uint8List bytes,
      {int maxDimension = 1200, int quality = 88}) async {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final maxSide = image.width > image.height ? image.width : image.height;
    if (maxSide <= maxDimension) {
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    final resized = img.copyResize(
      image,
      width: image.width >= image.height ? maxDimension : null,
      height: image.height > image.width ? maxDimension : null,
    );

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// Saves image to local Storage directory under user-specific folder
  static Future<String?> saveLocally(
      String uid, String fileName, Uint8List bytes,
      {String subFolder = 'product_images'}) async {
    try {
      final baseDir = await getApplicationSupportDirectory();
      final userPath = subFolder == 'brand_assets'
          ? path.join(
              baseDir.path, 'BuildEra_Offline', uid, 'databases', subFolder)
          : path.join(baseDir.path, 'BuildEra_Offline', uid, subFolder);
      final userDir = Directory(userPath);

      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
      }

      final file = File(path.join(userDir.path, fileName));

      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  /// Resolves a stored path that might be from a different platform or legacy version
  static Future<String?> resolveLocalPath(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return null;

    try {
      // 1. Check if the path is already valid for the current platform
      if (await File(storedPath).exists()) return storedPath;

      // 2. Resolve based on markers (New & Legacy support)
      final markers = ['BuildEra_Offline', 'KonstruksiPOS'];

      for (final marker in markers) {
        if (storedPath.contains(marker)) {
          final index = storedPath.indexOf(marker);
          String relative = storedPath.substring(index);

          relative = relative
              .replaceAll('\\', path.separator)
              .replaceAll('/', path.separator);

          // Check in Support Dir (New)
          final supportDir = await getApplicationSupportDirectory();
          final supportCandidates = [path.join(supportDir.path, relative)];
          if (relative.contains('${path.separator}brand_assets')) {
            supportCandidates.add(
              path.join(
                  supportDir.path,
                  relative.replaceFirst(
                    '${path.separator}brand_assets',
                    '${path.separator}databases${path.separator}brand_assets',
                  )),
            );
          }
          for (final candidate in supportCandidates) {
            if (await File(candidate).exists()) return candidate;
          }

          // Check in Documents Dir (Legacy)
          final docDir = await getApplicationDocumentsDirectory();
          final documentCandidates = [path.join(docDir.path, relative)];
          if (relative.contains('${path.separator}brand_assets')) {
            documentCandidates.add(
              path.join(
                  docDir.path,
                  relative.replaceFirst(
                    '${path.separator}brand_assets',
                    '${path.separator}databases${path.separator}brand_assets',
                  )),
            );
          }
          for (final candidate in documentCandidates) {
            if (await File(candidate).exists()) return candidate;
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving local path: $e');
    }

    return null;
  }

  /// Deletes local image file
  static Future<void> deleteLocal(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting local image: $e');
    }
  }
}
