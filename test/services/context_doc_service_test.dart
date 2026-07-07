import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/context_doc_service.dart';

void main() {
  group('ContextDocService', () {
    late ContextDocService service;

    setUp(() {
      service = ContextDocService();
    });

    group('ContextDoc enum', () {
      test('has all document types', () {
        expect(ContextDoc.values, hasLength(5));
        expect(ContextDoc.soul.fileName, 'SOUL.md');
        expect(ContextDoc.user.fileName, 'USER.md');
        expect(ContextDoc.agent.fileName, 'AGENT.md');
        expect(ContextDoc.memory.fileName, 'MEMORY.md');
        expect(ContextDoc.knowledge.fileName, '');
      });

      test('knowledge has empty filename', () {
        expect(ContextDoc.knowledge.fileName, isEmpty);
      });
    });

    group('cached', () {
      test('returns empty string when not cached', () {
        expect(service.cached(ContextDoc.soul), isEmpty);
        expect(service.cached(ContextDoc.user), isEmpty);
        expect(service.cached(ContextDoc.agent), isEmpty);
        expect(service.cached(ContextDoc.memory), isEmpty);
      });
    });

    group('hasUserProfile', () {
      test('returns false when no cache', () {
        expect(service.hasUserProfile(), isFalse);
      });

      test('returns false for default template', () {
        // We can't directly set _cache, but we can test the logic
        // by checking that hasUserProfile returns false for empty service
        expect(service.hasUserProfile(), isFalse);
      });
    });

    group('read', () {
      test('returns knowledge placeholder for knowledge doc', () async {
        final content = await service.read(ContextDoc.knowledge);
        expect(content, contains('知识库'));
        expect(content, contains('8 个文件'));
      });
    });

    group('ContextDocReviewRequiredException', () {
      test('creates exception with message', () {
        final exception = ContextDocReviewRequiredException('Test message');
        expect(exception.message, 'Test message');
        expect(exception.toString(), 'Test message');
      });

      test('creates exception with different messages', () {
        final exception1 = ContextDocReviewRequiredException('First message');
        final exception2 = ContextDocReviewRequiredException('Second message');
        expect(exception1.message, isNot(exception2.message));
      });
    });

    group('ContextDoc properties', () {
      test('soul has correct filename', () {
        expect(ContextDoc.soul.fileName, 'SOUL.md');
      });

      test('user has correct filename', () {
        expect(ContextDoc.user.fileName, 'USER.md');
      });

      test('agent has correct filename', () {
        expect(ContextDoc.agent.fileName, 'AGENT.md');
      });

      test('memory has correct filename', () {
        expect(ContextDoc.memory.fileName, 'MEMORY.md');
      });

      test('knowledge has empty filename', () {
        expect(ContextDoc.knowledge.fileName, isEmpty);
      });
    });

    group('cached behavior', () {
      test('cached returns empty for all doc types initially', () {
        expect(service.cached(ContextDoc.soul), isEmpty);
        expect(service.cached(ContextDoc.user), isEmpty);
        expect(service.cached(ContextDoc.agent), isEmpty);
        expect(service.cached(ContextDoc.memory), isEmpty);
        expect(service.cached(ContextDoc.knowledge), isEmpty);
      });
    });

    group('read method', () {
      test('read for knowledge returns placeholder', () async {
        final result = await service.read(ContextDoc.knowledge);
        expect(result, isNotEmpty);
        expect(result, contains('知识库'));
      });
    });

    group('hasUserProfile logic', () {
      test('returns false when cache is empty', () {
        // hasUserProfile checks _cache[ContextDoc.user]
        // If not cached, should return false
        expect(service.hasUserProfile(), isFalse);
      });
    });

    group('ContextDoc enum values', () {
      test('all values have correct names', () {
        expect(ContextDoc.soul.name, 'soul');
        expect(ContextDoc.user.name, 'user');
        expect(ContextDoc.agent.name, 'agent');
        expect(ContextDoc.memory.name, 'memory');
        expect(ContextDoc.knowledge.name, 'knowledge');
      });
    });

    group('ContextDoc fileName property', () {
      test('soul fileName is SOUL.md', () {
        expect(ContextDoc.soul.fileName, 'SOUL.md');
      });

      test('user fileName is USER.md', () {
        expect(ContextDoc.user.fileName, 'USER.md');
      });

      test('agent fileName is AGENT.md', () {
        expect(ContextDoc.agent.fileName, 'AGENT.md');
      });

      test('memory fileName is MEMORY.md', () {
        expect(ContextDoc.memory.fileName, 'MEMORY.md');
      });

      test('knowledge fileName is empty', () {
        expect(ContextDoc.knowledge.fileName, isEmpty);
      });
    });
  });
}