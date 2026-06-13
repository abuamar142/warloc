class ChatMessage {
  final int? id;
  final int threadId;
  final int timestamp; // Milliseconds since epoch
  final String sender;
  final String content;
  final int isSystem; // 1 = true, 0 = false
  final String? mediaPath; // Path relative to media folder (filename)
  final String? mediaType; // 'image', 'video', 'audio', 'sticker', 'document'

  ChatMessage({
    this.id,
    required this.threadId,
    required this.timestamp,
    required this.sender,
    required this.content,
    required this.isSystem,
    this.mediaPath,
    this.mediaType,
  });

  bool get isSystemMessage => isSystem == 1;
  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'threadId': threadId,
      'timestamp': timestamp,
      'sender': sender,
      'content': content,
      'isSystem': isSystem,
      'mediaPath': mediaPath,
      'mediaType': mediaType,
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
      mediaPath: map['mediaPath'] as String?,
      mediaType: map['mediaType'] as String?,
    );
  }

  ChatMessage copyWith({
    int? id,
    int? threadId,
    int? timestamp,
    String? sender,
    String? content,
    int? isSystem,
    String? mediaPath,
    String? mediaType,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      timestamp: timestamp ?? this.timestamp,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      isSystem: isSystem ?? this.isSystem,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
    );
  }
}
