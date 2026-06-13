import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:warloc/utils/media_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaHelper Tests', () {
    late Directory tempDocsDir;

    setUp(() async {
      // Create a temporary directory to act as the Application Documents Directory
      tempDocsDir = await Directory.systemTemp.createTemp('warloc_media_test');

      // Mock PathProvider MethodChannel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return tempDocsDir.path;
          }
          return null;
        },
      );
    });

    tearDown(() async {
      if (await tempDocsDir.exists()) {
        await tempDocsDir.delete(recursive: true);
      }
    });

    test('getMediaTypeFromExtension maps file extensions correctly', () {
      // Images
      expect(MediaHelper.getMediaTypeFromExtension('photo.jpg'), 'image');
      expect(MediaHelper.getMediaTypeFromExtension('photo.JPEG'), 'image');
      expect(MediaHelper.getMediaTypeFromExtension('photo.png'), 'image');
      expect(MediaHelper.getMediaTypeFromExtension('photo.gif'), 'image');

      // Stickers (webp with STK in filename)
      expect(MediaHelper.getMediaTypeFromExtension('STK-20260611-WA0003.webp'), 'sticker');
      expect(MediaHelper.getMediaTypeFromExtension('photo.webp'), 'image'); // WebP without STK is image

      // Videos
      expect(MediaHelper.getMediaTypeFromExtension('video.mp4'), 'video');
      expect(MediaHelper.getMediaTypeFromExtension('video.MKV'), 'video');
      expect(MediaHelper.getMediaTypeFromExtension('video.mov'), 'video');

      // Audios
      expect(MediaHelper.getMediaTypeFromExtension('audio.opus'), 'audio');
      expect(MediaHelper.getMediaTypeFromExtension('voice.mp3'), 'audio');
      expect(MediaHelper.getMediaTypeFromExtension('voice.m4a'), 'audio');

      // Other documents
      expect(MediaHelper.getMediaTypeFromExtension('report.pdf'), 'document');
      expect(MediaHelper.getMediaTypeFromExtension('archive.zip'), 'document');
    });

    test('getMediaDirectory creates and returns thread-specific media folder', () async {
      final threadId = 123;
      final mediaDir = await MediaHelper.getMediaDirectory(threadId);

      expect(await mediaDir.exists(), true);
      expect(p.basename(mediaDir.path), threadId.toString());
      expect(p.basename(p.dirname(mediaDir.path)), 'media');
    });

    test('getMediaFile returns correct file reference', () async {
      final threadId = 456;
      final fileName = 'test_image.jpg';
      final file = await MediaHelper.getMediaFile(threadId, fileName);

      expect(p.basename(file.path), fileName);
      expect(p.basename(p.dirname(file.path)), threadId.toString());
    });

    test('extractZipAndFindChatLog extracts files and finds .txt chat log', () async {
      final zipFile = File(p.join(tempDocsDir.path, 'test_backup.zip'));
      final destDir = Directory(p.join(tempDocsDir.path, 'extracted'));
      await destDir.create(recursive: true);

      // Create a dummy zip archive
      final archive = Archive()
        ..addFile(ArchiveFile('chat_log.txt', 11, utf8.encode('Hello World')))
        ..addFile(ArchiveFile('photo.jpg', 5, [1, 2, 3, 4, 5]));

      final zipBytes = ZipEncoder().encode(archive);
      await zipFile.writeAsBytes(zipBytes);

      final chatLogPath = await MediaHelper.extractZipAndFindChatLog(zipFile.path, destDir);

      expect(chatLogPath, isNotNull);
      expect(p.basename(chatLogPath!), 'chat_log.txt');
      expect(await File(chatLogPath).readAsString(), 'Hello World');

      final photoFile = File(p.join(destDir.path, 'photo.jpg'));
      expect(await photoFile.exists(), true);
    });
  });
}
