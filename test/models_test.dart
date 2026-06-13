import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/models/note.dart';
import 'package:personal_agent_app/models/reminder.dart';
import 'package:personal_agent_app/models/memory_entry.dart';

void main() {
  group('ChatMessage', () {
    test('serialization roundtrip', () {
      final msg = ChatMessage(text: 'Hello', isUser: true);
      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);
      expect(restored.text, 'Hello');
      expect(restored.isUser, true);
    });

    test('empty text handling', () {
      final msg = ChatMessage(text: '', isUser: false);
      expect(msg.text, '');
      expect(msg.isUser, false);
    });
  });

  group('ChatSession', () {
    test('serialization roundtrip', () {
      final session = ChatSession(
        id: 'test-id',
        title: 'Test Session',
        messages: [
          ChatMessage(text: 'Hi', isUser: true),
          ChatMessage(text: 'Hello!', isUser: false),
        ],
        updatedAt: DateTime(2025, 1, 1),
      );
      final json = session.toJson();
      final restored = ChatSession.fromJson(json);
      expect(restored.id, 'test-id');
      expect(restored.title, 'Test Session');
      expect(restored.messages.length, 2);
    });
  });

  group('Note', () {
    test('serialization roundtrip', () {
      final note = Note(
        id: 'note-1',
        title: 'Test Note',
        content: 'Note content',
        summary: 'Summary',
      );
      final json = note.toJson();
      final restored = Note.fromJson(json);
      expect(restored.id, 'note-1');
      expect(restored.title, 'Test Note');
      expect(restored.content, 'Note content');
    });
  });

  group('Reminder', () {
    test('serialization roundtrip', () {
      final reminder = Reminder(
        id: 'rem-1',
        title: 'Test Reminder',
        description: 'Description',
        scheduledTime: DateTime(2025, 6, 15, 10, 0),
      );
      final json = reminder.toJson();
      final restored = Reminder.fromJson(json);
      expect(restored.id, 'rem-1');
      expect(restored.title, 'Test Reminder');
      expect(restored.isCompleted, false);
    });
  });

  group('MemoryEntry', () {
    test('serialization roundtrip with preference type', () {
      final entry = MemoryEntry(
        id: 'mem-1',
        content: 'User prefers dark mode',
        type: MemoryType.preference,
      );
      final json = entry.toJson();
      final restored = MemoryEntry.fromJson(json);
      expect(restored.id, 'mem-1');
      expect(restored.content, 'User prefers dark mode');
      expect(restored.type, MemoryType.preference);
    });

    test('serialization roundtrip with fact type', () {
      final entry = MemoryEntry(
        id: 'mem-2',
        content: 'User works at Xiaomi',
        type: MemoryType.fact,
      );
      final json = entry.toJson();
      final restored = MemoryEntry.fromJson(json);
      expect(restored.type, MemoryType.fact);
    });
  });
}
