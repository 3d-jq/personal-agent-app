import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/core/agent_colors.dart';
import 'package:personal_agent_app/widgets/common_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: [AgentColors.light()]),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('AppTopBar 渲染 leading 返回箭头图标', (tester) async {
    await tester.pumpWidget(_wrap(AppTopBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () {},
      ),
      title: '测试群',
      actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
      ],
    )));

    // 返回箭头图标必须存在于 widget 树
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    // 标题必须存在
    expect(find.text('测试群'), findsOneWidget);
    // 右侧编辑按钮必须存在
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('AppTopBar 长标题时返回箭头仍不被遮挡（findsOneWidget）', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 360,
      height: 600,
      child: Material(
        child: AppTopBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {},
          ),
          title: '这是一个非常非常非常非常非常非常非常非常长的群名称用于测试',
          actions: [
            IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
          ],
        ),
      ),
    )));

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });
}
