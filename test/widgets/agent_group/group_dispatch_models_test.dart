import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_agent_app/models/agent.dart';
import 'package:personal_agent_app/widgets/agent_group/group_dispatch_models.dart';

void main() {
  group('SerialLock 串行锁', () {
    test('并发 run 必须串行执行：后者在前一个完成后才开始', () async {
      final lock = SerialLock();
      final order = <int>[];
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      final f1 = lock.run(() async {
        order.add(1);
        await c1.future;
        order.add(2);
      });
      final f2 = lock.run(() async {
        order.add(3);
        await c2.future;
        order.add(4);
      });

      // 让微任务队列空转一轮：f1 已开始并挂起在 c1，f2 还在排队未启动
      await Future.delayed(Duration.zero);
      expect(order, [1]);

      c1.complete();
      await Future.delayed(Duration.zero);
      // f1 完成后 f2 才启动
      expect(order, [1, 2, 3]);

      c2.complete();
      await Future.wait([f1, f2]);
      expect(order, [1, 2, 3, 4]);
    });

    test('异常不会破坏后续任务（错误被隔离，链继续）', () async {
      final lock = SerialLock();
      final results = <String>[];
      final fErr = lock.run(() async => throw StateError('boom'));
      final fOk = lock.run(() async => results.add('ok'));

      // 第一个抛错不应阻止第二个执行
      expect(fErr, throwsA(isA<StateError>()));
      await fOk;
      expect(results, ['ok']);
    });
  });

  group('DispatchRecord', () {
    test('记录派发的 agent 与简报', () {
      final rec = DispatchRecord('子Bot', '写一首诗');
      expect(rec.agentName, '子Bot');
      expect(rec.brief, '写一首诗');
    });
  });

  group('ChildRun', () {
    test('持有 agent 与可取消的 abort', () {
      final agent = Agent(id: 'child', name: '子Bot', role: '测试助手');
      final abort = Completer<void>();
      final run = ChildRun(agent: agent, abort: abort);
      expect(run.agent, agent);
      expect(run.abort, abort);
    });
  });
}
