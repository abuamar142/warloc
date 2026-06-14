class ParsedMessageTemp {
  final DateTime timestamp;
  final String sender;
  final String content;
  final bool isSystem;
  final String? mediaPath;
  final String? mediaType;

  ParsedMessageTemp({
    required this.timestamp,
    required this.sender,
    required this.content,
    required this.isSystem,
    this.mediaPath,
    this.mediaType,
  });

  @override
  String toString() {
    return '[$timestamp] $sender: $content';
  }
}

class ParsedChatResult {
  final List<ParsedMessageTemp> messages;
  final List<String> uniqueSenders;

  ParsedChatResult({
    required this.messages,
    required this.uniqueSenders,
  });
}
