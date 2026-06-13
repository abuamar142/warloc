import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../widgets/date_header.dart';
import '../widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatThread thread;

  const ChatRoomScreen({Key? key, required this.thread}) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<ChatMessage> _allMessages = [];
  List<ChatMessage> _filteredMessages = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final messages = await db.getMessagesForThread(widget.thread.id!);
    
    setState(() {
      _allMessages = messages;
      _filteredMessages = messages;
      _isLoading = false;
    });

    // Scroll to bottom after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
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
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Text(
                      widget.thread.name.isNotEmpty 
                          ? widget.thread.name.substring(0, 1).toUpperCase()
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
                          widget.thread.name,
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Saya: ${widget.thread.meName}",
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: groupedItems.length,
                    itemBuilder: (context, index) {
                      final item = groupedItems[index];
                      
                      if (item.isHeader) {
                        return DateHeader(dateText: item.dateHeader!);
                      } else {
                        return MessageBubble(
                          message: item.message!,
                          meName: widget.thread.meName,
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


}

class _ChatRoomItem {
  final String? dateHeader;
  final ChatMessage? message;

  _ChatRoomItem({this.dateHeader, this.message});

  bool get isHeader => dateHeader != null;
}
