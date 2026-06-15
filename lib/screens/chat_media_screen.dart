import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/full_screen_gallery_viewer.dart';

class ChatMediaScreen extends StatefulWidget {
  final ChatThread thread;
  final String mediaDirPath;

  const ChatMediaScreen({
    super.key,
    required this.thread,
    required this.mediaDirPath,
  });

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  bool _isLoading = true;
  List<ChatMessage> _mediaMessages = [];
  Map<String, List<ChatMessage>> _groupedMedia = {}; // Key: "Bulan Tahun", Value: list of messages
  List<String> _sortedMonths = [];

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final db = DatabaseHelper.instance;
      final messages = await db.getMediaMessagesForThread(widget.thread.id!);
      
      final List<ChatMessage> filteredMessages = [];
      final Set<String> seenMediaPaths = {};

      for (final msg in messages) {
        if (msg.mediaPath == null || msg.mediaPath!.isEmpty) continue;
        if (!seenMediaPaths.contains(msg.mediaPath)) {
          seenMediaPaths.add(msg.mediaPath!);
          filteredMessages.add(msg);
        }
      }

      // Group by Indonesian Month Year
      final Map<String, List<ChatMessage>> groups = {};
      final List<String> monthsOrder = [];

      for (final msg in filteredMessages) {
        final key = DateFormatter.formatMonthYear(msg.timestamp);
        if (!groups.containsKey(key)) {
          groups[key] = [];
          monthsOrder.add(key); // Preserves descending chronological order
        }
        groups[key]!.add(msg);
      }

      setState(() {
        _mediaMessages = filteredMessages;
        _groupedMedia = groups;
        _sortedMonths = monthsOrder;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat media: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _openLightbox(ChatMessage msg) {
    if (msg.mediaPath == null) return;

    final index = _mediaMessages.indexOf(msg);
    if (index == -1) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGalleryViewer(
          mediaMessages: _mediaMessages,
          initialIndex: index,
          mediaDirPath: widget.mediaDirPath,
        ),
      ),
    );
  }

  Widget _buildMediaItem(ChatMessage msg) {
    final fileName = msg.mediaPath!;
    final absolutePath = p.join(widget.mediaDirPath, fileName);
    final file = File(absolutePath);
    final isExists = file.existsSync();

    if (msg.mediaType == 'image' || msg.mediaType == 'sticker') {
      return GestureDetector(
        onTap: () => _openLightbox(msg),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: isExists
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                  )
                : const Center(
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                  ),
          ),
        ),
      );
    } else if (msg.mediaType == 'video') {
      return GestureDetector(
        onTap: () => _openLightbox(msg),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (isExists)
                Opacity(
                  opacity: 0.6,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                  ),
                ),
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (msg.mediaType == 'audio') {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.audioBubbleBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.primaryTransparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, color: AppColors.primary, size: 28),
            const SizedBox(height: 4),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ],
        ),
      );
    } else {
      // Document / files
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.red[400], size: 28),
            const SizedBox(height: 4),
            Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          "Media, Dokumen & Audio",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 1,
      ),
      body: _isLoading
          ? const CustomLoadingIndicator()
          : _mediaMessages.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.perm_media_outlined,
                  title: "Tidak ada berkas media",
                  description: "Foto, video, audio, dan dokumen akan muncul di sini.",
                )
              : CustomScrollView(
                  slivers: [
                    for (final monthKey in _sortedMonths) ...[
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            monthKey,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, gridIndex) {
                              final msg = (_groupedMedia[monthKey] ?? [])[gridIndex];
                              return _buildMediaItem(msg);
                            },
                            childCount: (_groupedMedia[monthKey] ?? []).length,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 16),
                    ),
                  ],
                ),
    );
  }
}
