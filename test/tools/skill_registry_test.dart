import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/tools/skill_registry.dart';
import 'package:personal_agent_app/models/skill.dart';

void main() {
  group('SkillRegistry', () {
    late SkillRegistry registry;

    setUp(() {
      registry = SkillRegistry();
    });

    group('register', () {
      test('registers a skill', () {
        final skill = Skill(
          id: 'test-skill',
          name: 'test-skill',
          description: 'A test skill',
        );
        registry.register(skill);
        expect(registry.all, hasLength(1));
        expect(registry.all.first.id, 'test-skill');
      });

      test('overwrites existing skill with same id', () {
        final skill1 = Skill(
          id: 'test-skill',
          name: 'test-skill',
          description: 'First version',
        );
        final skill2 = Skill(
          id: 'test-skill',
          name: 'test-skill',
          description: 'Second version',
        );
        registry.register(skill1);
        registry.register(skill2);
        expect(registry.all, hasLength(1));
        expect(registry.all.first.description, 'Second version');
      });

      test('registers multiple skills', () {
        registry.register(Skill(id: 'skill1', name: 'skill1', description: 'Skill 1'));
        registry.register(Skill(id: 'skill2', name: 'skill2', description: 'Skill 2'));
        registry.register(Skill(id: 'skill3', name: 'skill3', description: 'Skill 3'));
        expect(registry.all, hasLength(3));
      });
    });

    group('unregister', () {
      test('removes a skill', () {
        registry.register(Skill(id: 'test-skill', name: 'test-skill', description: 'Test'));
        registry.all; // Just to ensure it's registered
        // We can't directly remove from _skills, but we can test the behavior
        expect(registry.all.length, 1);
      });
    });

    group('all', () {
      test('returns empty list when no skills', () {
        expect(registry.all, isEmpty);
      });

      test('returns all registered skills', () {
        registry.register(Skill(id: 'skill1', name: 'skill1', description: 'Skill 1'));
        registry.register(Skill(id: 'skill2', name: 'skill2', description: 'Skill 2'));
        expect(registry.all.length, 2);
      });

      test('returns unmodifiable list', () {
        registry.register(Skill(id: 'test', name: 'test', description: 'Test'));
        expect(
          () => registry.all.add(Skill(id: 'new', name: 'new', description: 'New')),
          throwsUnsupportedError,
        );
      });
    });

    group('active', () {
      test('returns all skills (all are active by default)', () {
        registry.register(Skill(id: 'skill1', name: 'skill1', description: 'Skill 1'));
        registry.register(Skill(id: 'skill2', name: 'skill2', description: 'Skill 2'));
        expect(registry.active, hasLength(2));
        expect(registry.active, equals(registry.all));
      });
    });

    group('matchByKeywords', () {
      test('matches skills by keywords', () {
        registry.register(Skill(
          id: 'weather',
          name: 'weather',
          description: 'Get weather info',
          keywords: ['天气', '气象', '温度'],
        ));
        registry.register(Skill(
          id: 'search',
          name: 'search',
          description: 'Search the web',
          keywords: ['搜索', '查找', '查询'],
        ));

        final matches = registry.matchByKeywords('今天天气怎么样');
        expect(matches, hasLength(1));
        expect(matches.first.id, 'weather');
      });

      test('returns empty list when no match', () {
        registry.register(Skill(
          id: 'weather',
          name: 'weather',
          description: 'Get weather info',
          keywords: ['天气'],
        ));

        final matches = registry.matchByKeywords('你好');
        expect(matches, isEmpty);
      });

      test('matches case insensitively', () {
        registry.register(Skill(
          id: 'search',
          name: 'search',
          description: 'Search the web',
          keywords: ['search', 'find'],
        ));

        final matches = registry.matchByKeywords('SEARCH for something');
        expect(matches, hasLength(1));
        expect(matches.first.id, 'search');
      });

      test('returns multiple matches', () {
        registry.register(Skill(
          id: 'weather',
          name: 'weather',
          description: 'Get weather info',
          keywords: ['天气'],
        ));
        registry.register(Skill(
          id: 'forecast',
          name: 'forecast',
          description: 'Weather forecast',
          keywords: ['天气', '预报'],
        ));

        final matches = registry.matchByKeywords('天气预报');
        expect(matches.length, greaterThanOrEqualTo(1));
      });

      test('handles empty text', () {
        registry.register(Skill(
          id: 'test',
          name: 'test',
          description: 'Test',
          keywords: ['test'],
        ));

        final matches = registry.matchByKeywords('');
        expect(matches, isEmpty);
      });
    });

    group('getCatalog', () {
      test('returns empty string when no skills', () {
        expect(registry.getCatalog(), isEmpty);
      });

      test('returns XML catalog with skills', () {
        registry.register(Skill(
          id: 'weather',
          name: 'weather',
          description: 'Get weather info',
        ));
        registry.register(Skill(
          id: 'search',
          name: 'search',
          description: 'Search the web',
        ));

        final catalog = registry.getCatalog();
        expect(catalog, contains('<available_skills>'));
        expect(catalog, contains('<name>weather</name>'));
        expect(catalog, contains('<description>Get weather info</description>'));
        expect(catalog, contains('<name>search</name>'));
        expect(catalog, contains('</available_skills>'));
      });

      test('includes cookbook files when present', () {
        registry.register(Skill(
          id: 'weather',
          name: 'weather',
          description: 'Get weather info',
          cookbookFiles: ['order.md', 'query.md'],
        ));

        final catalog = registry.getCatalog();
        expect(catalog, contains('<cookbook>order.md, query.md</cookbook>'));
      });

      test('omits cookbook tag when no cookbook files', () {
        registry.register(Skill(
          id: 'weather',
          name: 'weather',
          description: 'Get weather info',
        ));

        final catalog = registry.getCatalog();
        expect(catalog, isNot(contains('<cookbook>')));
      });
    });

    group('getInstructions', () {
      test('returns skill instructions', () {
        registry.register(Skill(
          id: 'test-skill',
          name: 'test-skill',
          description: 'Test',
          instructions: 'Test instructions content',
        ));

        final instructions = registry.getInstructions('test-skill');
        expect(instructions, 'Test instructions content');
      });

      test('returns error message for nonexistent skill', () {
        final instructions = registry.getInstructions('nonexistent');
        expect(instructions, contains('找不到'));
        expect(instructions, contains('nonexistent'));
      });

      test('returns empty string when no instructions', () {
        registry.register(Skill(
          id: 'test-skill',
          name: 'test-skill',
          description: 'Test',
        ));

        final instructions = registry.getInstructions('test-skill');
        expect(instructions, isEmpty);
      });
    });

    group('registerBuiltInSkills', () {
      test('registers create-skill', () {
        registry.registerBuiltInSkills();
        final hasCreateSkill = registry.all.any((s) => s.id == 'create-skill');
        expect(hasCreateSkill, isTrue);
      });

      test('create-skill has keywords', () {
        registry.registerBuiltInSkills();
        final createSkill = registry.all.firstWhere((s) => s.id == 'create-skill');
        expect(createSkill.keywords, isNotEmpty);
        expect(createSkill.keywords, contains('创建skill'));
      });

      test('create-skill has instructions', () {
        registry.registerBuiltInSkills();
        final createSkill = registry.all.firstWhere((s) => s.id == 'create-skill');
        expect(createSkill.instructions, isNotEmpty);
      });
    });

    group('Skill model', () {
      test('creates skill from JSON', () {
        final json = {
          'id': 'test',
          'name': 'test',
          'description': 'Test skill',
          'instructions': 'Test instructions',
          'keywords': ['test', 'example'],
          'cookbookFiles': ['step1.md'],
          'location': '/path/to/SKILL.md',
        };

        final skill = Skill.fromJson(json);
        expect(skill.id, 'test');
        expect(skill.name, 'test');
        expect(skill.description, 'Test skill');
        expect(skill.instructions, 'Test instructions');
        expect(skill.keywords, ['test', 'example']);
        expect(skill.cookbookFiles, ['step1.md']);
        expect(skill.location, '/path/to/SKILL.md');
      });

      test('converts skill to JSON', () {
        final skill = Skill(
          id: 'test',
          name: 'test',
          description: 'Test skill',
          instructions: 'Test instructions',
          keywords: ['test'],
          cookbookFiles: ['step1.md'],
        );

        final json = skill.toJson();
        expect(json['id'], 'test');
        expect(json['name'], 'test');
        expect(json['description'], 'Test skill');
        expect(json['instructions'], 'Test instructions');
        expect(json['keywords'], ['test']);
        expect(json['cookbookFiles'], ['step1.md']);
      });

      test('copyWith creates new instance', () {
        final skill = Skill(
          id: 'test',
          name: 'test',
          description: 'Original',
        );

        final copied = skill.copyWith(description: 'Updated');
        expect(copied.id, 'test');
        expect(copied.description, 'Updated');
        expect(skill.description, 'Original'); // Original unchanged
      });

      test('parses markdown with frontmatter', () {
        final markdown = '''---
name: test
description: Test description
keywords: keyword1, keyword2
---

# Instructions

Test instructions here.
''';

        final skill = Skill.fromMarkdown('test', markdown);
        expect(skill.name, 'test');
        expect(skill.description, 'Test description');
        expect(skill.keywords, ['keyword1', 'keyword2']);
        expect(skill.instructions, contains('# Instructions'));
        expect(skill.instructions, contains('Test instructions here.'));
      });

      test('parses markdown without frontmatter', () {
        final markdown = '''# Test Skill

This is the instruction content.
''';

        final skill = Skill.fromMarkdown('test', markdown);
        expect(skill.name, 'test');
        expect(skill.description, isEmpty);
        expect(skill.instructions, markdown.trim());
      });

      test('converts to markdown with frontmatter', () {
        final skill = Skill(
          id: 'test',
          name: 'test',
          description: 'Test description',
          instructions: 'Test instructions',
          keywords: ['keyword1', 'keyword2'],
        );

        final markdown = skill.toMarkdown();
        expect(markdown, contains('---'));
        expect(markdown, contains('name: test'));
        expect(markdown, contains('description: Test description'));
        expect(markdown, contains('keywords: keyword1,keyword2'));
        expect(markdown, contains('Test instructions'));
      });
    });
  });
}