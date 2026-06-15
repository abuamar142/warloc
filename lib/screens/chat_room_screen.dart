import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/glass_container.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/database_helper.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../widgets/date_header.dart';
import '../widgets/message_bubble.dart';
import '../widgets/manage_senders_dialog.dart';
import '../theme/app_colors.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/user_avatar.dart';
import '../utils/date_formatter.dart';
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

  // Floating Date Overlay States
  String _floatingDate = '';
  bool _showFloatingDate = false;
  Timer? _floatingDateTimer;

  // Pagination states
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  static const int _limit = 100;
  int _messagesOffset = 0;
  bool _isLoadingNewer = false;

  // Cached state
  List<_ChatRoomItem> _groupedItems = [];
  String? _appDocDirPath;

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
    // Cache app directory path once — avoid repeated async calls
    getApplicationDocumentsDirectory().then((dir) {
      if (mounted) _appDocDirPath = dir.path;
    });
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchScrollController.removeListener(_searchScrollListener);
    _searchScrollController.dispose();
    _searchController.dispose();
    _floatingDateTimer?.cancel();
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
      // Trigger load newer when user scrolls near the bottom (which is 0 in reversed list)
      if (currentScroll <= 100 &&
          !_isLoadingNewer &&
          _messagesOffset > 0 &&
          !_isSearching) {
        _loadNewerMessages();
      }
      _updateFloatingDate();
    }
  }

  Future<void> _loadNewerMessages() async {
    if (_isLoadingNewer || _messagesOffset <= 0 || _allMessages.isEmpty) return;

    _isLoadingNewer = true;

    final db = DatabaseHelper.instance;
    final queryLimit = min(_limit, _messagesOffset);
    final newOffset = _messagesOffset - queryLimit;

    try {
      final newMessages = await db.getMessagesForThreadPaginated(
        _currentThread.id!,
        queryLimit,
        newOffset,
      );

      if (!mounted) return;

      final oldMaxScrollExtent = _scrollController.position.maxScrollExtent;
      final oldOffset = _scrollController.position.pixels;

      setState(() {
        _allMessages.addAll(newMessages);
        _filteredMessages = _allMessages;
        _messagesOffset = newOffset;
        _isLoadingNewer = false;
        _groupedItems = _buildGroupedItems();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          final newMaxScrollExtent = _scrollController.position.maxScrollExtent;
          final diff = newMaxScrollExtent - oldMaxScrollExtent;
          if (diff != 0) {
            _scrollController.jumpTo(oldOffset + diff);
          }
        }
        _updateFloatingDate();
      });
    } catch (_) {
      setState(() {
        _isLoadingNewer = false;
      });
    }
  }

  void _updateFloatingDate() {
    if (!mounted || _groupedItems.isEmpty || !_scrollController.hasClients) return;

    final scrollContext = _scrollController.position.context.notificationContext as Element?;
    if (scrollContext == null) return;

    int? topVisibleIndex;
    double minDistance = double.infinity;
    
    // Top offset of the viewport below the AppBar
    final double viewportTop = MediaQuery.of(context).padding.top + kToolbarHeight;

    void visitDescendants(Element element) {
      final renderObject = element.renderObject;
      if (renderObject is RenderIndexedSemantics) {
        final renderBox = renderObject as RenderBox;
        if (renderBox.hasSize) {
          final position = renderBox.localToGlobal(Offset.zero);
          final double y = position.dy;
          
          final double distance = (y - viewportTop).abs();
          if (distance < minDistance) {
            minDistance = distance;
            topVisibleIndex = renderObject.index;
          }
        }
      }
      element.visitChildren(visitDescendants);
    }

    visitDescendants(scrollContext);

    if (topVisibleIndex != null) {
      final actualIndex = _groupedItems.length - 1 - topVisibleIndex!;
      if (actualIndex >= 0 && actualIndex < _groupedItems.length) {
        final item = _groupedItems[actualIndex];
        
        String? dateText;
        if (item.isHeader) {
          dateText = item.dateHeader;
        } else if (item.message != null) {
          dateText = DateFormatter.formatDateHeader(item.message!.timestamp);
        }

        if (dateText != null) {
          if (dateText != _floatingDate) {
            setState(() {
              _floatingDate = dateText!;
              _showFloatingDate = true;
            });
          } else if (!_showFloatingDate) {
            setState(() {
              _showFloatingDate = true;
            });
          }

          _floatingDateTimer?.cancel();
          _floatingDateTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showFloatingDate = false;
              });
            }
          });
        }
      }
    }
  }

  Future<void> _showDatePickerAndJump() async {
    final db = DatabaseHelper.instance;
    final dbInstance = await db.database;
    final minMax = await dbInstance.rawQuery(
      'SELECT MIN(timestamp) as minTime, MAX(timestamp) as maxTime FROM messages WHERE threadId = ?',
      [_currentThread.id],
    );
    
    DateTime firstDate = DateTime.now().subtract(const Duration(days: 365 * 5));
    DateTime lastDate = DateTime.now();
    
    if (minMax.isNotEmpty) {
      final minTime = minMax.first['minTime'] as int?;
      final maxTime = minMax.first['maxTime'] as int?;
      if (minTime != null) firstDate = DateTime.fromMillisecondsSinceEpoch(minTime);
      if (maxTime != null) lastDate = DateTime.fromMillisecondsSinceEpoch(maxTime);
    }
    
    if (firstDate.isAfter(lastDate)) {
      firstDate = lastDate.subtract(const Duration(days: 1));
    }
    
    if (!mounted) return;
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (selectedDate == null) return;
    
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day).millisecondsSinceEpoch;
    
    final results = await dbInstance.query(
      'messages',
      where: 'threadId = ? AND timestamp >= ?',
      whereArgs: [_currentThread.id, startOfDay],
      orderBy: 'timestamp ASC',
      limit: 1,
    );
    
    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada pesan pada atau setelah tanggal tersebut.")),
        );
      }
      return;
    }
    
    final targetMsg = ChatMessage.fromMap(results.first);
    await _jumpToSearchResultMessage(targetMessageId: targetMsg.id!, timestamp: targetMsg.timestamp);
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

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: "Hapus Pesan",
        content: const Text(
          "Apakah Anda yakin ingin menghapus pesan ini secara permanen? Tindakan ini tidak dapat dibatalkan.",
        ),
        actions: [
          AppButton(
            label: "Batal",
            onPressed: () => Navigator.pop(context, false),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: "Hapus",
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && message.id != null) {
      // 1. Delete physical media file if exists
      if (message.hasMedia && message.mediaPath != null && _mediaDirPath != null) {
        try {
          final filePath = p.join(_mediaDirPath!, message.mediaPath!);
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint("Gagal menghapus file media: $e");
        }
      }

      // 2. Delete message from database
      await DatabaseHelper.instance.deleteMessage(message.id!);

      // 3. Reload list
      _loadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pesan berhasil dihapus")),
        );
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
    
    final mediaDirPath = _appDocDirPath != null
        ? p.join(_appDocDirPath!, 'media', _currentThread.id.toString())
        : p.join((await getApplicationDocumentsDirectory()).path, 'media', _currentThread.id.toString());

    setState(() {
      _allMessages = messages;
      _filteredMessages = messages;
      _mediaDirPath = mediaDirPath;
      _isLoading = false;
      _hasMoreMessages = messages.length == _limit;
      _groupedItems = _buildGroupedItems();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateFloatingDate();
      }
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
      _groupedItems = _buildGroupedItems();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateFloatingDate();
      }
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

    final mediaDirPath = _appDocDirPath != null
        ? p.join(_appDocDirPath!, 'media', _currentThread.id.toString())
        : p.join((await getApplicationDocumentsDirectory()).path, 'media', _currentThread.id.toString());

    final totalInDb = await db.getMessageCountForThread(_currentThread.id!);

    setState(() {
      _allMessages = messages;
      _filteredMessages = messages;
      _mediaDirPath = mediaDirPath;
      _isLoading = false;
      _hasMoreMessages = (_messagesOffset + _allMessages.length) < totalInDb;
      _groupedItems = _buildGroupedItems();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      setState(() {
        _highlightedMessageId = targetMessageId;
      });
      _updateFloatingDate();

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



  String _formatDateHeader(int timestamp) =>
      DateFormatter.formatDateHeader(timestamp);

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
    return const EmptyStateWidget(
      icon: Icons.search,
      title: "Cari Pesan",
      description: "Masukkan minimal 3 karakter untuk mencari pesan di obrolan ini.",
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
                  color: AppColors.primary,
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
    return const CustomLoadingIndicator();
  }

  Widget _buildSearchEmptyState() {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: "Tidak Ada Hasil",
      description: "Tidak ditemukan pesan yang cocok dengan \"${_searchController.text}\".",
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
                child: CustomLoadingIndicator(size: 24, strokeWidth: 2.5),
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
            UserAvatar(
              name: message.sender,
              radius: 20,
              isMe: isMe,
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
          backgroundColor: AppColors.highlightBackground,
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

  String _formatSearchResultTime(int timestamp) =>
      DateFormatter.formatSearchResultTime(timestamp);

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
  } Widget _buildWallpaper(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0B141A),
                    Color(0xFF14222D),
                    Color(0xFF0B141A),
                  ]
                : const [
                    Color(0xFFEDF2F7),
                    Color(0xFFE2E8F0),
                    Color(0xFFEDF2F7),
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Radial blur spot 1
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(isDark ? 0.08 : 0.05),
                ),
              ),
            ),
            // Radial blur spot 2
            Positioned(
              bottom: -60,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondary.withOpacity(isDark ? 0.08 : 0.05),
                ),
              ),
            ),
            // BackdropFilter blur layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget bodyContent;
    if (_isLoading) {
      bodyContent = const CustomLoadingIndicator();
    } else if (_isSearching) {
      bodyContent = _buildSearchView();
    } else {
      bodyContent = Stack(
        children: [
          // List and Bottom Bar
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  cacheExtent: 5000,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _groupedItems.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoadingMore && index == _groupedItems.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CustomLoadingIndicator(size: 24, strokeWidth: 2.5),
                          ),
                        ),
                      );
                    }

                    final item = _groupedItems[_groupedItems.length - 1 - index];
                    
                    if (item.isHeader) {
                      return GestureDetector(
                        onTap: _showDatePickerAndJump,
                        child: DateHeader(dateText: item.dateHeader!),
                      );
                    } else {
                      final isTarget = _highlightedMessageId == item.message!.id;
                      return MessageBubble(
                        key: isTarget ? _highlightedKey : null,
                        message: item.message!,
                        meName: _currentThread.meName,
                        mediaDirPath: _mediaDirPath,
                        isHighlighted: isTarget,
                        onLongPress: () => _deleteMessage(item.message!),
                      );
                    }
                  },
                ),
              ),
              // Bottom Read-Only Bar with Glassmorphic Design
              GlassContainer(
                borderRadius: BorderRadius.zero,
                blurX: 10.0,
                blurY: 10.0,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF2E3B46).withOpacity(0.3)
                        : Colors.grey[200]!.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        "Mode Baca Saja (Read-Only)",
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Floating Date Header with Glassmorphic Design
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showFloatingDate ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: _showDatePickerAndJump,
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(12),
                    blurX: 8,
                    blurY: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(
                      _floatingDate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Cari pesan...",
                  hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black45),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : InkWell(
                onTap: _showChatOptionsSheet,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: _currentThread.name,
                        radius: 18,
                        usePrimaryColor: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentThread.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              "Saya: ${_currentThread.meName}",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
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
              icon: const Icon(Icons.close),
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
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildWallpaper(context),
          bodyContent,
        ],
      ),
      floatingActionButton: _messagesOffset > 0
          ? FloatingActionButton.extended(
              onPressed: _loadMessages,
              backgroundColor: theme.colorScheme.primary,
              icon: Icon(Icons.arrow_downward, color: theme.colorScheme.onPrimary),
              label: Text("Pesan Terbaru", style: TextStyle(color: theme.colorScheme.onPrimary)),
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
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                name: _currentThread.name,
                radius: 32,
                usePrimaryColor: true,
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
                leading: Icon(Icons.people_outline, color: theme.colorScheme.primary),
                title: const Text("Detail & Penggabungan Kontak"),
                subtitle: const Text("Kelola pengirim pesan dan perbarui database"),
                onTap: () {
                  Navigator.pop(context);
                  _showManageSendersDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.calendar_month_outlined, color: theme.colorScheme.primary),
                title: const Text("Lompat ke Tanggal"),
                subtitle: const Text("Lompat langsung ke tanggal chat tertentu"),
                onTap: () {
                  Navigator.pop(context);
                  _showDatePickerAndJump();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: theme.colorScheme.primary),
                title: const Text("Media Obrolan"),
                subtitle: const Text("Lihat berkas gambar, video, audio, dan dokumen"),
                onTap: () {
                  Navigator.pop(context);
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
