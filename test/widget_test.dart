import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('询问、搜索或创作任何内容'), findsOneWidget);
  });
}
