import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/services/mcp_client.dart';

void main() {
  group('McpTool', () {
    test('creates tool with required fields', () {
      final tool = McpTool(
        name: 'test-tool',
        description: 'A test tool',
        inputSchema: {'type': 'object'},
      );

      expect(tool.name, 'test-tool');
      expect(tool.description, 'A test tool');
    });

    test('creates from JSON', () {
      final json = {
        'name': 'test-tool',
        'description': 'A test tool',
        'inputSchema': {'type': 'object'},
      };

      final tool = McpTool.fromJson(json);
      expect(tool.name, 'test-tool');
      expect(tool.description, 'A test tool');
    });

    test('handles missing description', () {
      final json = {
        'name': 'test-tool',
      };

      final tool = McpTool.fromJson(json);
      expect(tool.name, 'test-tool');
      expect(tool.description, '');
    });
  });

  group('McpResource', () {
    test('creates resource with required fields', () {
      final resource = McpResource(
        uri: 'file:///test',
        name: 'Test Resource',
      );

      expect(resource.uri, 'file:///test');
      expect(resource.name, 'Test Resource');
    });

    test('creates from JSON', () {
      final json = {
        'uri': 'file:///test',
        'name': 'Test Resource',
        'description': 'A test resource',
        'mimeType': 'text/plain',
      };

      final resource = McpResource.fromJson(json);
      expect(resource.uri, 'file:///test');
      expect(resource.name, 'Test Resource');
      expect(resource.description, 'A test resource');
      expect(resource.mimeType, 'text/plain');
    });
  });

  group('McpClient', () {
    test('creates client with server URL', () {
      final client = McpClient(serverUrl: 'http://localhost:3000');
      expect(client.serverUrl, 'http://localhost:3000');
    });

    test('starts with empty tools list', () {
      final client = McpClient(serverUrl: 'http://localhost:3000');
      expect(client.tools, isEmpty);
    });

    test('tools list is unmodifiable', () {
      final client = McpClient(serverUrl: 'http://localhost:3000');
      expect(() => client.tools.add(McpTool(
        name: 'test',
        description: '',
        inputSchema: {},
      )), throwsUnsupportedError);
    });
  });
}
