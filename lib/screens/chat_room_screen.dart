import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../widgets/date_header.dart';
import '../widgets/message_bubble.dart';
import '../widgets/manage_senders_dialog.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatThread thread;

  const ChatRoomScreen({super.key, required this.thread});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late ChatThread _currentThread;
  List<ChatMessage> _allMessages = [];
  List<ChatMessage> _filteredMessages = [];
  String? _mediaDirPath;
  bool _isLoading = true;
  bool _isSearching = false;

  // Pagination states
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  static const int _limit = 100;

  @override
  void initState() {
    super.initState();
    _currentThread = widget.thread;
    _scrollController.addListener(_scrollListener);
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // Trigger load more when user scrolls near the top (which is maxScrollExtent in reversed list)
      if (maxScroll - currentScroll <= 100 &&
          !_isLoadingMore &&
          _hasMoreMessages &&
          !_isSearching) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _hasMoreMessages = true;
    });
    final db = DatabaseHelper.instance;
    final messages = await db.getMessagesForThreadPaginated(_currentThread.id!, _limit, 0);
    
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDirPath = p.join(appDir.path, 'media', _currentThread.id.toString());
    
    setState(() {
      _allMessages = messages;
      _filteredMessages = messages;
      _mediaDirPath = mediaDirPath;
      _isLoading = false;
      _hasMoreMessages = messages.length == _limit;
    });
  }

  Future<void> _loadMoreMessages() async {
    setState(() => _isLoadingMore = true);

    final db = DatabaseHelper.instance;

    final newMessages = await db.getMessagesForThreadPaginated(
      _currentThread.id!,
      _limit,
      _allMessages.length,
    );

    if (newMessages.length < _limit) {
      _hasMoreMessages = false;
    }

    setState(() {
      _allMessages.insertAll(0, newMessages);
      _filteredMessages = _allMessages;
      _isLoadingMore = false;
    });
  }

  void _filterMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMessages = _allMessages;
      });
      return;
    }

    setState(() {
      _filteredMessages = _allMessages.where((msg) {
        return msg.content.toLowerCase().contains(query.toLowerCase()) ||
               msg.sender.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }



  String _formatDateHeader(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Hari ini';
    } else if (messageDate == yesterday) {
      return 'Kemarin';
    } else {
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }
  }

  List<_ChatRoomItem> _buildGroupedItems() {
    final List<_ChatRoomItem> items = [];
    String lastDate = '';

    for (final msg in _filteredMessages) {
      final dateStr = _formatDateHeader(msg.timestamp);
      if (dateStr != lastDate) {
        items.add(_ChatRoomItem(dateHeader: dateStr));
        lastDate = dateStr;
      }
      items.add(_ChatRoomItem(message: msg));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _buildGroupedItems();

    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2), // WhatsApp chat wallpaper color
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Cari pesan...",
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: _filterMessages,
              )
            : InkWell(
                onTap: _showManageSendersDialog,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Text(
                          _currentThread.name.isNotEmpty 
                              ? _currentThread.name.substring(0, 1).toUpperCase()
                              : 'W',
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentThread.name,
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Colors.white
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Saya: ${_currentThread.meName}",
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredMessages = _allMessages;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groupedItems.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingMore && index == groupedItems.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF008069),
                              ),
                            ),
                          ),
                        );
                      }

                      final item = groupedItems[groupedItems.length - 1 - index];
                      
                      if (item.isHeader) {
                        return DateHeader(dateText: item.dateHeader!);
                      } else {
                        return MessageBubble(
                          message: item.message!,
                          meName: _currentThread.meName,
                          mediaDirPath: _mediaDirPath,
                        );
                      }
                    },
                  ),
                ),
                // Footer (For read-only state notification)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        "Mode Baca Saja (Read-Only)",
                        style: TextStyle(
                          color: Colors.grey[600], 
                          fontSize: 12,
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }


  void _showManageSendersDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManageSendersDialog(
        thread: _currentThread,
        onSuccess: _refreshThreadDetails,
      ),
    );
  }

  Future<void> _refreshThreadDetails() async {
    final db = DatabaseHelper.instance;
    final updated = await db.getThread(_currentThread.id!);
    if (updated != null && mounted) {
      setState(() {
        _currentThread = updated;
      });
      _loadMessages();
    }
  }
}

class _ChatRoomItem {
  final String? dateHeader;
  final ChatMessage? message;

  _ChatRoomItem({this.dateHeader, this.message});

  bool get isHeader => dateHeader != null;
}
