import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/chat_message.dart';
import 'package:personal_agent_app/models/chat_session.dart';
import 'package:personal_agent_app/models/note.dart';
import 'package:personal_agent_app/models/reminder.dart';

void main() {
  group('ChatMessage', () {
    test('text and isUser are preserved through ChatSession roundtrip', () {
      // ChatMessage is a runtime ChangeNotifier (no direct toJson/fromJson);
      // serialization happens inside ChatSession. Verify it survives a roundtrip.
      final session = ChatSession(
        id: 's1',
        title: 'T',
        messages: [
          ChatMessage(text: 'Hello', isUser: true),
          ChatMessage(text: 'Hi!', isUser: false),
        ],
        updatedAt: DateTime(2025, 1, 1),
      );
      final restored = ChatSession.fromJson(session.toJson());
      expect(restored.messages.length, 2);
      expect(restored.messages[0].text, 'Hello');
      expect(restored.messages[0].isUser, true);
      expect(restored.messages[1].text, 'Hi!');
      expect(restored.messages[1].isUser, false);
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
      );
      final json = note.toJson();
      final restored = Note.fromJson(json);
      expect(restored.id, 'note-1');
      expect(restored.title, 'Test Note');
      expect(restored.content, 'Note content');
    });

    test('summary is derived from content', () {
      final note = Note(
        id: 'note-2',
        title: 'T',
        content: '这是一段正文内容',
      );
      expect(note.summary, contains('正文'));
    });
  });

  group('Reminder', () {
    test('serialization roundtrip', () {
      final reminder = Reminder(
        id: 'rem-1',
        title: 'Test Reminder',
        message: 'Description',
        scheduledTime: DateTime(2025, 6, 15, 10, 0),
      );
      final json = reminder.toJson();
      final restored = Reminder.fromJson(json);
      expect(restored.id, 'rem-1');
      expect(restored.title, 'Test Reminder');
      expect(restored.message, 'Description');
      expect(restored.isCompleted, false);
    });
  });

}
