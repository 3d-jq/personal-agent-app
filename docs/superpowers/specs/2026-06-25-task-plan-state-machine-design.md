# Task Plan 完整状态机设计

日期：2026-06-25

## 目标

将 `task_plan` 从提示词驱动的计划记录器升级为可校验、可恢复、可测试的任务状态机。目标是解决以下问题：

- `TaskPlanTool` 内部没有全局串行锁，多个调用可能竞争 `_currentPlan` 和 `/scratch/plan.json`。
- 状态迁移过于自由，允许跳步、多个 `in_progress`、父子状态不一致。
- `verify` 失败只返回提示，不提供可执行恢复路径。
- 缺少依赖关系，无法表达“任务 B 必须等任务 A 完成”。
- 父子任务只做弱同步，没有强制校验。
- `verify=true` 成功后未持久化。

## 范围

本次只改 `task_plan` 的内部执行语义和数据结构，保持现有 UI 入口和 `TaskPlanEvent` 基本兼容。

不改：

- 聊天气泡展示结构。
- 任务面板的整体布局。
- `AIService` 的 tool call 协议格式。

## 架构

新增状态机类：

```text
lib/tools/task_plan_state_machine.dart
```

职责划分：

```text
TaskPlanTool
  ├─ 参数解析
  ├─ 加载 / 保存 / 加锁
  ├─ 调用 TaskPlanStateMachine
  └─ 格式化返回文本

TaskPlanStateMachine
  ├─ validateCreate(tasks)
  ├─ transition(taskId, targetStatus, note)
  ├─ advance()
  ├─ verify()
  ├─ syncParents()
  ├─ nextAction()
  └─ dependency / parent-child validation
```

`TaskPlanTool` 不再直接修改任务状态，所有状态变化都通过 `TaskPlanStateMachine`。

## 数据结构

扩展 `TaskNode`：

```dart
class TaskNode {
  final String id;
  final String title;
  final String? parentId;
  final List<String> dependsOn;
  TaskStatus status;
  String? note;
  String? blockedReason;
}
```

`dependsOn` 表示当前任务开始前必须完成的任务 ID。

序列化兼容旧数据：

- 旧 plan 没有 `dependsOn` 时默认 `[]`。
- 旧 plan 没有 `blockedReason` 时默认 `null`。

## 创建校验

`create` 阶段必须校验：

1. 任务 ID 唯一。
2. `parent` 指向的任务必须存在。
3. `dependsOn` 指向的任务必须存在。
4. 父子关系不能形成环。
5. 依赖关系不能形成环。
6. 依赖不能指向自身。
7. 至少有一个叶子任务。

创建后自动选择第一个可执行叶子任务设为 `in_progress`：

可执行条件：

- 是叶子任务；
- 状态是 `pending`；
- 所有依赖均为 `done`；
- 父任务未 `failed` / `blocked`。

如果没有可执行叶子任务，创建失败并返回阻塞原因。

## 状态迁移规则

状态集合不变：

```dart
pending / inProgress / done / failed / blocked
```

允许迁移：

| From | To | 条件 |
|---|---|---|
| pending | inProgress | 依赖完成，父任务可执行，当前无其他 in_progress 叶子任务 |
| pending | blocked | 可直接阻塞，需 note/blockedReason |
| inProgress | done | 若有子任务，所有子任务必须 done |
| inProgress | failed | 可失败，需 note |
| inProgress | blocked | 可阻塞，需 note/blockedReason |
| blocked | inProgress | 阻塞原因已解决，依赖完成 |
| blocked | failed | 可失败 |
| failed | failed | 幂等 |
| done | done | 幂等 |

拒绝迁移：

- `done` / `failed` 回退到其他状态。
- 父任务在子任务未全部完成时直接 `done`。
- 有未完成依赖时进入 `in_progress`。
- 同时存在多个 `in_progress` 叶子任务。

## 父子同步

任务状态变化后递归同步父任务：

- 子任务任一 `failed` → 父任务 `failed`。
- 子任务任一 `blocked` → 父任务 `blocked`。
- 子任务任一 `inProgress` → 父任务 `inProgress`。
- 所有子任务 `done` → 父任务 `done`。
- 否则父任务保持 `pending`。

同步必须递归到祖先任务。

## advance 规则

`advance()` 行为：

1. 找当前唯一 `in_progress` 叶子任务。
2. 将其设为 `done`。
3. 同步父任务。
4. 找下一个可执行 pending 叶子任务。
5. 如存在，将其设为 `in_progress`。
6. 如不存在但仍有未完成任务，返回阻塞说明和建议。
7. 如全部完成/失败，提示调用 `verify`。

## verify 行为

`verify()` 不直接修复状态，但必须返回可执行恢复路径。

校验通过条件：

- 所有叶子任务都是 `done` 或 `failed`。
- 所有父任务状态与子任务一致。
- 没有 `in_progress` 任务。
- 没有未解释的 `blocked` 任务。

成功：

- 设置 `verified=true`。
- 持久化 `/scratch/plan.json`。
- 返回“可以输出最终答案”。

失败：

- 设置 `verified=false`。
- 持久化。
- 返回：
  - 未完成任务列表；
  - 阻塞任务及原因；
  - 未满足依赖；
  - 推荐下一步操作，例如：
    - `update(task_id, in_progress)`
    - `advance()`
    - `update(task_id, failed, note)`

## 串行锁

在 `TaskPlanTool.execute()` 外层增加静态队列锁：

```dart
static Future<void> _queue = Future.value();
```

所有操作通过队列串行执行，保护：

- `_currentPlan`
- `lastStatusText`
- `/scratch/plan.json`

AIService 里的“同一轮 task_plan 串行”保留，但不作为唯一保障。

## 工具调用限制预警

保留 `ToolRegistry` 的硬限制，同时增加提前预警：

- 当同一工具调用次数达到 `maxConsecutiveCalls - 2` 时，返回 warning 文本。
- 超过上限时仍阻止执行。

这项改动在 `ToolRegistry` 内完成，和 `task_plan` 状态机独立。

## UI 兼容

`TaskPlanEvent` 目前只传：

```dart
id, title, done, inProgress
```

本次保持兼容，不强制 UI 显示 `blockedReason` / `dependsOn`。

后续可选扩展：

- `TaskPlanItem.failed`
- `TaskPlanItem.blocked`
- `TaskPlanItem.blockedReason`

## 测试建议

新增单元测试覆盖：

1. create 校验 parent 不存在。
2. create 校验 dependsOn 不存在。
3. create 校验依赖环。
4. pending → inProgress 成功。
5. 有未完成依赖时 pending → inProgress 被拒绝。
6. 多个 inProgress 被拒绝。
7. 子任务未完成时父任务 done 被拒绝。
8. 子任务 done 后父任务递归同步。
9. advance 自动推进到下一个可执行任务。
10. verify 失败返回下一步建议。
11. verify 成功持久化 verified=true。
12. 旧 plan JSON 反序列化兼容。

## 风险

- 状态机变严格后，模型以前的非法 update 会被拒绝，短期内可能需要更明确的工具返回文案。
- `dependsOn` 加入后，模型创建计划时可能忘记填写依赖；状态机应允许无依赖计划继续正常工作。
- 串行锁实现要避免死锁，所有异常都必须被捕获并释放队列。

## 成功标准

- `task_plan` 任意非法状态迁移都给出明确错误和下一步建议。
- 不会出现多个 leaf task 同时 `in_progress`。
- 子任务与父任务状态始终一致。
- `verify` 成功后重启仍保持 `verified=true`。
- 旧计划文件仍可加载。