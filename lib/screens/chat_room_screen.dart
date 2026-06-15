import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  int? _anchorMessageId;
  final GlobalKey _anchorKey = GlobalKey();

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

    double? originalY;
    if (_anchorKey.currentContext != null) {
      final box = _anchorKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        originalY = box.localToGlobal(Offset.zero).dy;
      }
    }

    setState(() {
      _isLoadingNewer = true;
      _anchorMessageId = _allMessages.last.id;
    });

    final db = DatabaseHelper.instance;
    final queryLimit = min(_limit, _messagesOffset);
    final newOffset = _messagesOffset - queryLimit;

    try {
      final newMessages = await db.getMessagesForThreadPaginated(
        _currentThread.id!,
        queryLimit,
        newOffset,
      );

      setState(() {
        _allMessages.addAll(newMessages);
        _filteredMessages = _allMessages;
        _messagesOffset = newOffset;
        _isLoadingNewer = false;
        _groupedItems = _buildGroupedItems();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (originalY != null && _anchorKey.currentContext != null) {
          final box = _anchorKey.currentContext!.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final newY = box.localToGlobal(Offset.zero).dy;
            final diff = newY - originalY;
            if (diff != 0 && _scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.offset + diff);
            }
          }
        }
        setState(() {
          _anchorMessageId = null;
        });
        _updateFloatingDate();
      });
    } catch (_) {
      setState(() {
        _isLoadingNewer = false;
        _anchorMessageId = null;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
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
          ? const CustomLoadingIndicator()
          : _isSearching
              ? _buildSearchView()
              : Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            cacheExtent: 5000,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _groupedItems.length + (_isLoadingMore ? 1 : 0) + (_isLoadingNewer ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingNewer && index == 0) {
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

                              final actualItemCount = _groupedItems.length + (_isLoadingMore ? 1 : 0) + (_isLoadingNewer ? 1 : 0);
                              if (_isLoadingMore && index == actualItemCount - 1) {
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

                              final itemIndex = _groupedItems.length - 1 - (index - (_isLoadingNewer ? 1 : 0));
                              final item = _groupedItems[itemIndex];
                              
                              if (item.isHeader) {
                                return GestureDetector(
                                  onTap: _showDatePickerAndJump,
                                  child: DateHeader(dateText: item.dateHeader!),
                                );
                              } else {
                                final isTarget = _highlightedMessageId == item.message!.id;
                                final isAnchor = item.message != null &&
                                    (item.message!.id == _anchorMessageId ||
                                     (_anchorMessageId == null && _allMessages.isNotEmpty && item.message!.id == _allMessages.last.id));
                                return MessageBubble(
                                  key: isAnchor
                                      ? _anchorKey
                                      : (isTarget ? _highlightedKey : null),
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xE0DFE9E7),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _floatingDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _messagesOffset > 0
          ? FloatingActionButton.extended(
              onPressed: _loadMessages,
              backgroundColor: AppColors.primary,
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
              backgroundColor: AppColors.primary,
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
              leading: const Icon(Icons.people_outline, color: AppColors.primary),
              title: const Text("Detail & Penggabungan Kontak"),
              subtitle: const Text("Kelola pengirim pesan dan perbarui database"),
              onTap: () {
                Navigator.pop(context); // Close sheet
                _showManageSendersDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
              title: const Text("Lompat ke Tanggal"),
              subtitle: const Text("Lompat langsung ke tanggal chat tertentu"),
              onTap: () {
                Navigator.pop(context); // Close sheet
                _showDatePickerAndJump();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
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
