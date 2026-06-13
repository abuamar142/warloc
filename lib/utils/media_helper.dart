import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MediaHelper {
  static Future<Directory> getMediaDirectory(int threadId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'media', threadId.toString()));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  static Future<File> getMediaFile(int threadId, String fileName) async {
    final mediaDir = await getMediaDirectory(threadId);
    return File(p.join(mediaDir.path, fileName));
  }

  static String getMediaTypeFromExtension(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'webp':
        // WebP in WhatsApp can be stickers or images. Typically WhatsApp stickers are exported as .webp.
        // Let's assume .webp are stickers (STK-xxx) and others are images.
        if (fileName.toUpperCase().contains('STK')) {
          return 'sticker';
        }
        return 'image';
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case '3gp':
        return 'video';
      case 'opus':
      case 'wav':
      case 'mp3':
      case 'm4a':
      case 'aac':
        return 'audio';
      default:
        return 'document';
    }
  }

  /// Extracts [zipPath] into [destinationDir] and returns the path to the main chat log (.txt)
  static Future<String?> extractZipAndFindChatLog(String zipPath, Directory destinationDir) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    String? chatLogPath;

    for (final file in archive) {
      final filename = file.name;
      
      // Clean filename from sub-directories in case archive has them
      final cleanFileName = p.basename(filename);
      if (cleanFileName.isEmpty) continue;

      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(p.join(destinationDir.path, cleanFileName));
        
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
        
        // Find the main chat log file: e.g. "WhatsApp Chat with xxx.txt" or "_chat.txt" (iOS)
        if (cleanFileName.toLowerCase().endsWith('.txt') && 
            !cleanFileName.startsWith('__MACOSX') &&
            !cleanFileName.startsWith('.')) {
          chatLogPath = outFile.path;
        }
      }
    }
    
    return chatLogPath;
  }
}
