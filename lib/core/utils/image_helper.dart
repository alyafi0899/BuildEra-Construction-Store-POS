import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageHelper {
  /// Picks an image, crops it (if supported), and returns the bytes
  static Future<Uint8List?> pickAndCropImage(BuildContext context, {Color? accentColor}) async {
    // 1. Pick Image using FilePicker (more stable on Windows/Desktop)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    
    if (result == null || result.files.isEmpty) return null;
    final pickedFile = result.files.first;

    // 2. Cropping (Only supported on Mobile and Web)
    // On Windows, we skip cropping to prevent the app from hanging
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path!,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Gambar Produk',
            toolbarColor: accentColor ?? Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Potong Gambar Produk',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        return await croppedFile.readAsBytes();
      }
    }

    // On Windows/Desktop or if user cancelled crop, return original picked bytes
    return pickedFile.bytes;
  }

  /// Compresses and resizes image to 512x512
  static Future<Uint8List> processImage(Uint8List bytes) async {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Resize to fit display (512px max dimension)
    img.Image resized = img.copyResize(
      image, 
      width: image.width > image.height ? 512 : null,
      height: image.height >= image.width ? 512 : null,
    );

    // Encode as JPG with 80% quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  /// Saves image to local Documents directory under user-specific folder
  static Future<String?> saveLocally(String uid, String productId, Uint8List bytes) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final userDir = Directory(path.join(docDir.path, 'KonstruksiPOS', uid, 'product_images'));
      
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
      }

      final fileName = '$productId.jpg';
      final file = File(path.join(userDir.path, fileName));
      
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
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
