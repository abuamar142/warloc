import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import 'common/empty_state_widget.dart';
import 'common/loading_indicator.dart';
import 'common/user_avatar.dart';

/// Search UI extracted from ChatRoomScreen (S6).
///
/// Owns search query state, paginated results, and persistent search history
/// (via [DatabaseHelper] — replaces the former in-memory static list).
/// The parent [ChatRoomScreen] keeps only the mode flag [_isSearching] and
/// the jump-to-message navigation; this widget handles everything else.
class ChatSearchView extends StatefulWidget {
  final int threadId;
  final String meName;
  final TextEditingController searchController;
  final Future<void> Function(ChatMessage message) onResultTap;

  const ChatSearchView({
    super.key,
    required this.threadId,
    required this.meName,
    required this.searchController,
    required this.onResultTap,
  });

  @override
  State<ChatSearchView> createState() => _ChatSearchViewState();
}

class _ChatSearchViewState extends State<ChatSearchView> {
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _results = [];
  bool _isSearchingDb = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  List<String> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    widget.searchController.addListener(_onQueryChanged);
    _loadHistory();
    // If the controller already has a query (e.g. restored), search immediately.
    final initial = widget.searchController.text.trim();
    if (initial.length >= 3) {
      // Defer to after first frame so setState is safe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _performSearch(initial, isInitial: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onQueryChanged);
      widget.searchController.addListener(_onQueryChanged);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onQueryChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await DatabaseHelper.instance.getSearchHistory();
      if (!mounted) return;
      setState(() {
        _history = h;
        _historyLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat riwayat pencarian: $e');
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _onQueryChanged() {
    final q = widget.searchController.text.trim();
    if (q.length < 3) {
      setState(() {
        _results = [];
        _isSearchingDb = false;
        _hasMore = false;
      });
      return;
    }
    _performSearch(q, isInitial: true);
  }

  Future<void> _performSearch(String query, {required bool isInitial}) async {
    if (isInitial) {
      setState(() {
        _isSearchingDb = true;
        _offset = 0;
        _results = [];
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final db = DatabaseHelper.instance;
      final res = await db.searchMessagesPaginated(
        threadId: widget.threadId,
        query: query,
        limit: _limit,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        if (isInitial) {
          _results = res;
          _isSearchingDb = false;
        } else {
          _results.addAll(res);
          _isLoadingMore = false;
        }
        _hasMore = res.length == _limit;
        _offset += res.length;
      });
    } catch (e) {
      debugPrint('Gagal mencari pesan: $e');
      if (!mounted) return;
      setState(() {
        _isSearchingDb = false;
        _isLoadingMore = false;
      });
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.position.pixels;
    if (max - cur <= 100 && !_isLoadingMore && _hasMore) {
      final q = widget.searchController.text.trim();
      if (q.length >= 3) _performSearch(q, isInitial: false);
    }
  }

  void _applyQuery(String query) {
    widget.searchController.text = query;
    widget.searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    // Listener will trigger search.
  }

  Future<void> _removeHistory(String q) async {
    try {
      await DatabaseHelper.instance.removeSearchHistory(q);
    } catch (e) {
      debugPrint('Gagal menghapus riwayat: $e');
    }
    if (!mounted) return;
    setState(() => _history.remove(q));
  }

  Future<void> _clearHistory() async {
    try {
      await DatabaseHelper.instance.clearSearchHistory();
    } catch (e) {
      debugPrint('Gagal menghapus semua riwayat: $e');
    }
    if (!mounted) return;
    setState(() => _history.clear());
  }

  Future<void> _onTileTap(ChatMessage message) async {
    final q = widget.searchController.text.trim();
    if (q.isNotEmpty) {
      try {
        await DatabaseHelper.instance.addSearchHistory(q);
      } catch (e) {
        debugPrint('Gagal menyimpan riwayat: $e');
      }
    }
    // Defer navigation to parent; history already persisted.
    await widget.onResultTap(message);
  }

  String _formatSearchResultTime(int timestamp) =>
      DateFormatter.formatSearchResultTime(timestamp);

  Widget _buildHighlightedText(String text, String query) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final highlightBg =
        isDark ? AppColors.highlightBackgroundDark : AppColors.highlightBackground;
    if (query.isEmpty) return Text(text, style: TextStyle(color: onSurface, fontSize: 14));

    final List<TextSpan> spans = [];
    final lt = text.toLowerCase();
    final lq = query.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lt.indexOf(lq, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: highlightBg,
          color: onSurface,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }
    return RichText(
      text: TextSpan(style: TextStyle(color: onSurface, fontSize: 14), children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildHistoryEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.search,
      title: "Cari Pesan",
      description: "Masukkan minimal 3 karakter untuk mencari pesan di obrolan ini.",
    );
  }

  Widget _buildHistoryList() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Pencarian Terbaru",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: Text(
                  "Hapus Semua",
                  style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final q = _history[index];
              return ListTile(
                leading: Icon(Icons.history, color: onSurface.withValues(alpha: 0.5)),
                title: Text(q),
                trailing: IconButton(
                  icon: Icon(Icons.clear, size: 18, color: onSurface.withValues(alpha: 0.5)),
                  onPressed: () => _removeHistory(q),
                ),
                onTap: () => _applyQuery(q),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(ChatMessage message) {
    final query = widget.searchController.text.trim();
    final timeStr = _formatSearchResultTime(message.timestamp);
    final isMe = message.sender == widget.meName;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _onTileTap(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(name: message.sender, radius: 20, isMe: isMe),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

  Widget _buildSearchResultsList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _results.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == _results.length) {
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
        return _buildSearchResultTile(_results[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchController.text.trim();
    final bg = Theme.of(context).colorScheme.surface;

    if (query.length < 3) {
      if (_historyLoading) {
        return Container(color: bg, child: const CustomLoadingIndicator());
      }
      return Container(
        color: bg,
        child: _history.isEmpty ? _buildHistoryEmptyState() : _buildHistoryList(),
      );
    }
    if (_isSearchingDb) {
      return Container(color: bg, child: const CustomLoadingIndicator());
    }
    if (_results.isEmpty) {
      return Container(
        color: bg,
        child: EmptyStateWidget(
          icon: Icons.search_off,
          title: "Tidak Ada Hasil",
          description: "Tidak ditemukan pesan yang cocok dengan \"$query\".",
        ),
      );
    }
    return Container(color: bg, child: _buildSearchResultsList());
  }
}
