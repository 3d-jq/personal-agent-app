import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/app.dart';
import 'package:personal_agent_app/core/service_locator.dart';
import 'package:personal_agent_app/widgets/ai_settings_sheet.dart';

void main() {
  tearDown(() async => await resetDependencies());

  testWidgets('App loads successfully', (WidgetTester tester) async {
    configureDependencies();
    // 预选一个厂商，避免 App 初始化时触发保存文件（测试环境无 path_provider）
    getIt<AISettings>().selectedVendorId = 'Agnes-2.0-Flash';

    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('给 DWeis 发消息'), findsOneWidget);
  });
}
