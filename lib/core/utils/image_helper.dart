import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageHelper {
  /// Compresses and resizes image to max 512px and 70% quality
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    // Decode image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Resize if too large (max 512px width/height)
    if (image.width > 512 || image.height > 512) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: 512);
      } else {
        image = img.copyResize(image, height: 512);
      }
    }

    // Encode to JPG with 70% quality
    return Uint8List.fromList(img.encodeJpg(image, quality: 70));
  }

  /// Saves image to local storage for offline use/fast loading
  static Future<String?> saveLocally(String id, Uint8List bytes) async {
    if (kIsWeb) return null; // Web doesn't use file paths like this
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/products/$id.jpg';
      
      // Ensure directory exists
      final folder = Directory('${dir.path}/products');
      if (!await folder.exists()) await folder.create(recursive: true);
      
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    } catch (e) {
      return null;
    }
  }

  /// Checks if local image exists
  static Future<File?> getLocalFile(String? path) async {
    if (path == null || kIsWeb) return null;
    final file = File(path);
    if (await file.exists()) return file;
    return null;
  }
}
