import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../widgets/date_header.dart';
import '../widgets/message_bubble.dart';
import '../widgets/manage_senders_dialog.dart';
import 'chat_media_screen.dart';

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
  int _messagesOffset = 0;

  // Search states
  static final List<String> _searchHistory = [];
  final ScrollController _searchScrollController = ScrollController();
  List<ChatMessage> _searchResults = [];
  bool _isSearchingDb = false;
  bool _isLoadingMoreSearch = false;
  bool _hasMoreSearchResults = true;
  int _searchOffset = 0;
  static const int _searchLimit = 20;
  int? _highlightedMessageId;
  final GlobalKey _highlightedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentThread = widget.thread;
    _scrollController.addListener(_scrollListener);
    _searchScrollController.addListener(_searchScrollListener);
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchScrollController.removeListener(_searchScrollListener);
    _searchScrollController.dispose();
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

  void _searchScrollListener() {
    if (_searchScrollController.hasClients) {
      final maxScroll = _searchScrollController.position.maxScrollExtent;
      final currentScroll = _searchScrollController.position.pixels;
      // Trigger load more when user scrolls near the bottom of search results
      if (maxScroll - currentScroll <= 100 &&
          !_isLoadingMoreSearch &&
          _hasMoreSearchResults &&
          _isSearching) {
        final query = _searchController.text.trim();
        if (query.length >= 3) {
          _performSearch(query, isInitial: false);
        }
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _hasMoreMessages = true;
      _messagesOffset = 0;
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
      _messagesOffset + _allMessages.length,
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

  Future<void> _jumpToSearchResultMessage({required int targetMessageId, required int timestamp}) async {
    setState(() {
      _isLoading = true;
    });

    final db = DatabaseHelper.instance;
    final countNewer = await db.getMessageIndexInThread(
      _currentThread.id!,
      targetMessageId,
      timestamp,
    );

    _messagesOffset = max(0, countNewer - 50);

    final messages = await db.getMessagesForThreadPaginated(
      _currentThread.id!,
      100,
      _messagesOffset,
    );

    final appDir = await getApplicationDocumentsDirectory();
    final mediaDirPath = p.join(appDir.path, 'media', _currentThread.id.toString());

    final totalInDb = await db.getMessageCountForThread(_currentThread.id!);

    setState(() {
      _allMessages = messages;
      _filteredMessages = messages;
      _mediaDirPath = mediaDirPath;
      _isLoading = false;
      _hasMoreMessages = (_messagesOffset + _allMessages.length) < totalInDb;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      setState(() {
        _highlightedMessageId = targetMessageId;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_highlightedKey.currentContext != null) {
          if (_scrollController.hasClients) {
            _scrollController.removeListener(_scrollListener);
            Scrollable.ensureVisible(
              _highlightedKey.currentContext!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
            ).then((_) {
              if (mounted) {
                _scrollController.removeListener(_scrollListener);
                _scrollController.addListener(_scrollListener);
              }
            });
          }
        } else {
          if (_scrollController.hasClients) {
            _scrollController.removeListener(_scrollListener);
            _scrollController.addListener(_scrollListener);
          }
        }

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              if (_highlightedMessageId == targetMessageId) {
                _highlightedMessageId = null;
              }
            });
          }
        });
      });
    });
  }

  void _onSearchChanged(String query) {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _isSearchingDb = false;
        _hasMoreSearchResults = false;
      });
      return;
    }
    _performSearch(query.trim(), isInitial: true);
  }

  Future<void> _performSearch(String query, {bool isInitial = false}) async {
    if (isInitial) {
      setState(() {
        _isSearchingDb = true;
        _searchOffset = 0;
        _searchResults = [];
        _hasMoreSearchResults = true;
      });
    } else {
      if (_isLoadingMoreSearch || !_hasMoreSearchResults) return;
      setState(() {
        _isLoadingMoreSearch = true;
      });
    }

    try {
      final db = DatabaseHelper.instance;
      final results = await db.searchMessagesPaginated(
        threadId: _currentThread.id!,
        query: query,
        limit: _searchLimit,
        offset: _searchOffset,
      );

      setState(() {
        if (isInitial) {
          _searchResults = results;
          _isSearchingDb = false;
        } else {
          _searchResults.addAll(results);
          _isLoadingMoreSearch = false;
        }
        _hasMoreSearchResults = results.length == _searchLimit;
        _searchOffset += results.length;
      });
    } catch (e) {
      setState(() {
        _isSearchingDb = false;
        _isLoadingMoreSearch = false;
      });
    }
  }

  void _applySearchQuery(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _onSearchChanged(query);
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

  Widget _buildHistoryEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey.withAlpha(76),
          ),
          const SizedBox(height: 16),
          const Text(
            "Cari Pesan",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "Masukkan minimal 3 karakter untuk mencari pesan di obrolan ini.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Pencarian Terbaru",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF008069),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchHistory.clear();
                  });
                },
                child: const Text(
                  "Hapus Semua",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchHistory.removeAt(index);
                    });
                  },
                ),
                onTap: () => _applySearchQuery(query),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF008069)),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.withAlpha(76),
          ),
          const SizedBox(height: 16),
          const Text(
            "Tidak Ada Hasil",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "Tidak ditemukan pesan yang cocok dengan \"${_searchController.text}\".",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      controller: _searchScrollController,
      itemCount: _searchResults.length + (_isLoadingMoreSearch ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMoreSearch && index == _searchResults.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
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

        final message = _searchResults[index];
        return _buildSearchResultTile(message);
      },
    );
  }

  Widget _buildSearchResultTile(ChatMessage message) {
    final query = _searchController.text.trim();
    final timeStr = _formatSearchResultTime(message.timestamp);
    final isMe = message.sender == _currentThread.meName;

    return InkWell(
      onTap: () async {
        if (query.isNotEmpty) {
          setState(() {
            _searchHistory.remove(query);
            _searchHistory.insert(0, query);
            if (_searchHistory.length > 20) {
              _searchHistory.removeLast();
            }
          });
        }

        setState(() {
          _isSearching = false;
        });

        await _jumpToSearchResultMessage(targetMessageId: message.id!, timestamp: message.timestamp);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isMe ? const Color(0xFFDCF8C6) : const Color(0xFFE0E0E0),
              child: Text(
                message.sender.isNotEmpty ? message.sender.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(
                  color: isMe ? const Color(0xFF075E54) : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMe ? 'Saya' : message.sender,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildHighlightedText(message.content, query),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text, style: const TextStyle(color: Colors.black87, fontSize: 14));

    final List<TextSpan> spans = [];
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFF9C4),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatSearchResultTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    if (date == today) {
      return 'Hari ini $timeStr';
    } else if (date == yesterday) {
      return 'Kemarin $timeStr';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} $timeStr';
    }
  }

  Widget _buildSearchView() {
    final query = _searchController.text.trim();
    if (query.length < 3) {
      return Container(
        color: Colors.white,
        child: _searchHistory.isEmpty ? _buildHistoryEmptyState() : _buildHistoryList(),
      );
    }

    if (_isSearchingDb) {
      return Container(
        color: Colors.white,
        child: _buildSearchLoadingState(),
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
        color: Colors.white,
        child: _buildSearchEmptyState(),
      );
    }

    return Container(
      color: Colors.white,
      child: _buildSearchResultsList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _buildGroupedItems();

    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _filteredMessages = _allMessages;
              });
            } else {
              Navigator.pop(context);
            }
          },
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
                onChanged: _onSearchChanged,
              )
            : InkWell(
                onTap: _showChatOptionsSheet,
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
                if (_searchController.text.isNotEmpty) {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _isSearchingDb = false;
                  });
                } else {
                  setState(() {
                    _isSearching = false;
                    _filteredMessages = _allMessages;
                  });
                }
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
          : _isSearching
              ? _buildSearchView()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        cacheExtent: 5000,
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
                            final isTarget = _highlightedMessageId == item.message!.id;
                            return MessageBubble(
                              key: isTarget ? _highlightedKey : null,
                              message: item.message!,
                              meName: _currentThread.meName,
                              mediaDirPath: _mediaDirPath,
                              isHighlighted: isTarget,
                            );
                          }
                        },
                      ),
                    ),
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
      floatingActionButton: _messagesOffset > 0
          ? FloatingActionButton.extended(
              onPressed: _loadMessages,
              backgroundColor: const Color(0xFF008069),
              icon: const Icon(Icons.arrow_downward, color: Colors.white),
              label: const Text("Pesan Terbaru", style: TextStyle(color: Colors.white)),
            )
          : null,
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

  void _showChatOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF008069),
              child: Text(
                _currentThread.name.isNotEmpty
                    ? _currentThread.name.substring(0, 1).toUpperCase()
                    : 'W',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentThread.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              "Saya: ${_currentThread.meName}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.people_outline, color: Color(0xFF008069)),
              title: const Text("Detail & Penggabungan Kontak"),
              subtitle: const Text("Kelola pengirim pesan dan perbarui database"),
              onTap: () {
                Navigator.pop(context); // Close sheet
                _showManageSendersDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF008069)),
              title: const Text("Media Obrolan"),
              subtitle: const Text("Lihat berkas gambar, video, audio, dan dokumen"),
              onTap: () {
                Navigator.pop(context); // Close sheet
                if (_mediaDirPath != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatMediaScreen(
                        thread: _currentThread,
                        mediaDirPath: _mediaDirPath!,
                      ),
                    ),
                  ).then((_) => _refreshThreadDetails());
                }
              },
            ),
          ],
        ),
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
