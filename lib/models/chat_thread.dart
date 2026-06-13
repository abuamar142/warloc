class ChatThread {
  final int? id;
  final String name;
  final String meName;

  ChatThread({
    this.id,
    required this.name,
    required this.meName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'meName': meName,
    };
  }

  factory ChatThread.fromMap(Map<String, dynamic> map) {
    return ChatThread(
      id: map['id'] as int?,
      name: map['name'] as String,
      meName: map['meName'] as String,
    );
  }

  ChatThread copyWith({
    int? id,
    String? name,
    String? meName,
  }) {
    return ChatThread(
      id: id ?? this.id,
      name: name ?? this.name,
      meName: meName ?? this.meName,
    );
  }
}
