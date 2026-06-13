import 'package:flutter_test/flutter_test.dart';
import 'package:warloc/models/chat_thread.dart';

void main() {
  group('ChatThread Model Tests', () {
    test('Constructor creates instance with correct properties', () {
      final thread = ChatThread(
        id: 1,
        name: 'Group Chat',
        meName: 'Me',
      );

      expect(thread.id, 1);
      expect(thread.name, 'Group Chat');
      expect(thread.meName, 'Me');
    });

    test('toMap() converts object into map correctly', () {
      final thread = ChatThread(
        id: 5,
        name: 'Alice',
        meName: 'Me',
      );
      final map = thread.toMap();

      expect(map['id'], 5);
      expect(map['name'], 'Alice');
      expect(map['meName'], 'Me');

      final threadNoId = ChatThread(
        name: 'Bob',
        meName: 'Myself',
      );
      final mapNoId = threadNoId.toMap();
      expect(mapNoId.containsKey('id'), false);
    });

    test('fromMap() constructs instance from map correctly', () {
      final Map<String, dynamic> map = {
        'id': 12,
        'name': 'Family Group',
        'meName': 'Son',
      };
      final thread = ChatThread.fromMap(map);

      expect(thread.id, 12);
      expect(thread.name, 'Family Group');
      expect(thread.meName, 'Son');
    });

    test('copyWith() returns new instance with updated properties', () {
      final thread = ChatThread(
        id: 1,
        name: 'John',
        meName: 'Me',
      );

      final updatedThread = thread.copyWith(
        id: 42,
        name: 'John Doe',
      );

      // Verify updated properties
      expect(updatedThread.id, 42);
      expect(updatedThread.name, 'John Doe');

      // Verify unchanged properties are kept
      expect(updatedThread.meName, 'Me');
    });
  });
}
