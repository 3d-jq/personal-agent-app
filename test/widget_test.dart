import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/app.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/widgets/ai_settings_sheet.dart';

void main() {
  tearDown(() {
    resetDependencies();
  });

  testWidgets('App loads successfully', (WidgetTester tester) async {
    // 预选一个厂商，避免 App 初始化时触发保存文件（测试环境无 path_provider）
    AISettings().selectedVendorId = 'Agnes-2.0-Flash';
    configureDependencies();

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('询问、搜索或创作任何内容'), findsOneWidget);
  });
}
