class ChatMessage {
  final int? id;
  final int threadId;
  final int timestamp; // Milliseconds since epoch
  final String sender;
  final String content;
  final int isSystem; // 1 = true, 0 = false

  ChatMessage({
    this.id,
    required this.threadId,
    required this.timestamp,
    required this.sender,
    required this.content,
    required this.isSystem,
  });

  bool get isSystemMessage => isSystem == 1;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'threadId': threadId,
      'timestamp': timestamp,
      'sender': sender,
      'content': content,
      'isSystem': isSystem,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      threadId: map['threadId'] as int,
      timestamp: map['timestamp'] as int,
      sender: map['sender'] as String,
      content: map['content'] as String,
      isSystem: map['isSystem'] as int,
    );
  }

  ChatMessage copyWith({
    int? id,
    int? threadId,
    int? timestamp,
    String? sender,
    String? content,
    int? isSystem,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      timestamp: timestamp ?? this.timestamp,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}
