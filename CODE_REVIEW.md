# DWeis 代码审查标准与流程

> 本项目的代码审查制度。面向所有贡献者，确保代码在 **正确性、安全性、可维护性、性能** 四个维度持续达标。

---

## 一、审查流程

```
提交 PR / commit
       │
       ▼
  ┌─────────────┐    不通过    ┌──────────────┐
  │ 自动门禁     │───────────▶│ 修复后重新提交  │
  │ (CI / 本地)  │             └──────────────┘
  └──────┬──────┘
         │ 通过
         ▼
  ┌─────────────┐
  │ 人工审查     │ ◀── 审查者按本文 checklist 逐项检查
  └──────┬──────┘
         │
    ┌────┴────┐
    ▼         ▼
  通过      修改建议
    │         │
    ▼         ▼
  合并     作者修复 → 重新审查
```

### 1.1 自动门禁（必须全部通过）

| 门禁 | 命令 | 标准 |
|------|------|------|
| 静态分析 | `flutter analyze` | **0 issue**（含 warning/info） |
| 单元测试 | `flutter test` | **0 failure**，全部通过 |
| 测试覆盖 | 新增/修改的功能**必须有测试** | 无测试的改动不予合入 |

> **纪律**：不满足以上任一条件，**绝不提交**。遗留 warning、info、deprecated API 等一律当场解决，不后延。

### 1.2 审查者职责

- **一审**（必选）：同组或相邻模块开发者，关注逻辑正确性
- **二审**（可选）：架构负责人，关注跨模块影响和架构一致性

### 1.3 审查粒度

- **≤ 200 行改动**：一次审查完成
- **200–500 行**：审查者可在 24h 内完成
- **> 500 行**：建议拆分为多个小 PR

---

## 二、通用审查清单

### 🔴 阻断项（必须修复，否则不得合入）

#### 安全

- [ ] 用户输入是否经过校验/转义？（SQL 注入、路径穿越）
- [ ] API Key / Token 是否硬编码？（必须走 `SecureStorage` 或环境变量）
- [ ] 文件操作是否限定了安全路径？（不可遍历到应用沙箱外）
- [ ] 敏感数据（token、用户对话）是否可能泄露到日志？（`debugPrint` / `LogService` 需脱敏）

#### 数据完整性

- [ ] 数据库操作是否有错误处理？写入失败是否可能导致数据不一致？
- [ ] 并发写入是否有锁保护？（`CachedRepository` 内部已有 `AsyncLock`，直接 SQL 操作需自行加锁）
- [ ] `ChangeNotifier.dispose()` 后是否还有 listener 调用？（会导致内存泄漏或崩溃）

#### 正确性

- [ ] 异步操作是否正确 `await`？是否有遗漏的 `unawaited` 导致静默失败？
- [ ] `try/catch` 是否覆盖了关键路径？catch 后是否至少 `debugPrint` 了错误信息？
- [ ] 流式 AI 响应的 SSE 解析是否能处理截断/异常数据？

### 🟡 建议项（应该修复）

#### 架构一致性

- [ ] 状态管理：新增状态是否走 `ChangeNotifier + ListenableBuilder` 而非整屏 `setState`？
- [ ] 依赖注入：是否通过 `getIt` 或构造函数注入获取服务？（禁止在业务代码中 `new Service()` 或调 `getIt<X>()` 裸用）
- [ ] 导航：所有页面跳转是否通过 `AppRouter` 静态方法？（禁止直接 `Navigator.push`）
- [ ] 设计令牌：间距/圆角/字号是否使用 `SpaceToken` / `RadiusToken` / `FontToken`？（禁止 magic number）

#### 命名与结构

- [ ] 文件命名是否与内容一致？新增文件是否放在正确的目录？
  - `controllers/` — 业务编排、ChangeNotifier 控制器
  - `services/` — 无 UI 的纯服务（AI、存储、TTS、MCP）
  - `models/` — 纯数据模型
  - `widgets/` — 可复用 UI 组件
  - `screens/` — 整页 Screen
  - `tools/` — Agent 工具实现
- [ ] 类名/方法名是否自解释？是否有不必要的缩写？

#### 性能

- [ ] 列表渲染是否使用了 `ListenableBuilder` 包裹单个 item？（禁止全量 `setState` 重绘整个列表）
- [ ] 图片/缩略图是否设置了 `cacheWidth` / `cacheHeight`？（防止 OOM）
- [ ] `BuildContext` 是否在异步间隙后被使用？（需检查 `mounted`）
- [ ] 是否有不必要的重复构建？（`const` 构造函数、`RepaintBoundary` 隔离）

### 💭 建议项（锦上添花）

- [ ] 新增的公开类/方法是否有 doc comment？
- [ ] 错误消息是否使用了 `ErrorHandler.humanizeError()` 做用户友好化？
- [ ] 复杂逻辑是否有行内注释解释"为什么"（而非"做什么"）？
- [ ] 是否存在可提取为共享工具/方法的重複代码？

---

## 三、专项审查清单

### 3.1 Services 层

```
重点关注：lib/services/
```

- [ ] 是否实现了清晰的接口/抽象？（便于 Fake → 测试）
- [ ] 是否为单例且通过 `getIt` 注册？
- [ ] 持久化操作是否走 `CachedRepository<T>` / `LocalDataSource<T>` 而非原始 SQL？
- [ ] 外部 API 调用是否有超时和重试策略？
- [ ] SSE 流是否使用 `SseParser` 统一解析？（禁止 OpenAI/Anthropic 各自手写）
- [ ] Token 用量是否调 `tokenTracker.record()`？

### 3.2 Tools 层

```
重点关注：lib/tools/
```

- [ ] 新工具是否继承 `AgentTool` 基类？
- [ ] `parameters` 是否定义了合法的 JSON Schema？
- [ ] `execute()` 是否处理了参数缺失/非法情况？
- [ ] 返回值是否经过 `ToolResultTruncator` 截断？
- [ ] 是否在 `PluginRegistry.provideTools()` 中注册？
- [ ] 是否受 `ToolExecutionLimits` 频率限制？
- [ ] 工具描述 `.txt` 文件修改后是否重新生成 `.g.dart`？（`dart run tool/generate_tool_descriptions.dart`）

### 3.3 Widgets / UI 层

```
重点关注：lib/widgets/、lib/screens/
```

- [ ] 是否使用了项目统一组件？
  - 通知 → `AppToast.show()`，**禁止**裸 `ScaffoldMessenger.showSnackBar`
  - 卡片 → `ElevatedCard`
  - 顶栏 → `AppTopBar`
- [ ] 动画是否使用 `AppAnimations` 中的标准持续时间/曲线？
- [ ] 颜色是否通过 `AgentColors.of(context)` 获取？（支持深色模式）
- [ ] 是否避免了整页 `setState`？（用 `ListenableBuilder` 包裹单个 `ChatBubble`）
- [ ] 长列表是否包裹了 `RepaintBoundary`？
- [ ] `BackdropFilter` sigma 是否 ≤ 12？（避免 GPU 过载）
- [ ] 设置页导航项是否都带了 `icon`？（同卡片内要么全带、要么全不带）

### 3.4 Controllers 层

```
重点关注：lib/controllers/
```

- [ ] `initState` 中的 `addListener` 是否在 `dispose` 中有对应的 `removeListener`？
- [ ] 是否有 `mounted` 检查？（异步回调中访问 `setState` / `context` 前）
- [ ] `ChatController` 的构造函数注入参数是否覆盖了测试所需的全部依赖？
- [ ] `MessageWindow` 的翻页逻辑是否正确处理了边界（`hasOlder` / `hasNewer`）？

---

## 四、测试要求

### 4.1 测试分类

| 类型 | 目录 | 适用范围 |
|------|------|----------|
| 单元测试 | `test/services/`、`test/controllers/`、`test/tools/` | 纯逻辑、算法、数据转换 |
| Widget 测试 | `test/widgets/`、`test/screens/` | UI 渲染、交互、状态变化 |
| Golden 测试 | `test/widgets/goldens/` | 关键 UI 组件的像素级回归测试 |

### 4.2 测试写法规范

```dart
// ✅ 正确：setUp 中重置 DI
setUp(() async {
  await resetDependencies();
  configureDependencies();
});

tearDown(() async {
  await resetDependencies();
});

// ✅ 正确：用 Fake 替换真实服务
final fakeStorage = FakeChatStorage();
getIt.unregister<ChatStorage>();
getIt.registerSingleton<ChatStorage>(fakeStorage);
```

- [ ] 每个测试文件的 `setUp` / `tearDown` 是否重置了 DI？
- [ ] Fake/Mock 类是否放在 `test/fakes/` 下？
- [ ] 是否测试了**边界情况**（空数据、错误状态、极值输入）？
- [ ] 修改工具描述后是否重新生成了 `.g.dart` 并验证相关测试仍通过？

### 4.3 禁止行为

- ❌ 全局可变状态在测试间泄漏（如 `TaskPlanTool._currentPlan` static 字段）
- ❌ 测试依赖执行顺序
- ❌ 硬编码 sleep/wait 替代 proper `await` 或 `pumpAndSettle`

---

## 五、Performance 性能红线

以下模式在审查中视为 🟡 级（应修复）：

1. **全量 setState** — 用 `ListenableBuilder(listenable: msg)` 包裹单个气泡
2. **无 cacheWidth/Height 的图片** — 缩略图必须加尺寸约束
3. **每次 build 新建 `MarkdownStyleSheet`** — 已在 `inline_content.dart` 中哈希缓存，勿回退
4. **prototypeItem 在高度不一致的列表** — 聊天气泡差异大，**禁止使用**
5. **PageRouteBuilder 替代 CupertinoPageRoute** — 会丢失系统返回动画和圆角遮罩
6. **FAB 实时 BackdropFilter** — 运行中 GPU 开销大，已改实心底+boxShadow，勿回退

---

## 六、审查评论规范

### 评论格式

```markdown
🔴 **Security: SQL 注入风险**
`lib/services/chat_storage.dart:142` — 用户输入直接拼入 SQL。

**Why:** 攻击者可注入恶意 SQL 语句。

**Suggestion:**
- 改用参数化查询：`db.query('SELECT * FROM sessions WHERE id = ?', [id])`
```

### 优先级标记

| 标记 | 含义 | 是否阻塞合入 |
|------|------|:---:|
| 🔴 | 阻断：安全/崩溃/数据丢失 | 是 |
| 🟡 | 建议：架构/性能/可维护性 | 否，但需记录 |
| 💭 | 建议：微优化/文档/命名 | 否 |

### 审查礼仪

- **对事不对人**：评论针对代码，不针对作者
- **解释原因**：不只说"改一下"，要说"建议改 X，因为 Y"
- **给出方案**：提供具体的替代写法或代码片段
- **称赞好的实现**：发现巧妙的设计时，明确表达认可

---

## 七、与现有工具的集成

| 工具 | 用途 | 配置位置 |
|------|------|----------|
| `flutter analyze` | 静态分析 | `analysis_options.yaml` |
| `flutter test` | 测试运行 | `test/` 目录 |
| Gitee（本地） | 版本管理 | `.git/config` |

> **注意**：当前项目使用本地 Git（Gitee 远程 token 已注销），**不擅自 push**。版本管理纯本地操作。

---

## 八、审查决策树

```
收到改动
    │
    ├─ 新增文件？         → 检查目录归属是否正确
    ├─ 修改 Services？    → 检查接口/Fake/测试
    ├─ 修改 Tools？       → 检查 AgentTool 契约/注册/描述生成
    ├─ 修改 Widgets？     → 检查设计令牌/AppToast/动画/性能
    ├─ 修改 Controllers？ → 检查生命周期/DI/嵌套 setState
    ├─ 修改 Models？      → 检查序列化/ChangeNotifier 生命周期
    └─ 修改测试？         → 检查 setUp/tearDown DI 重置
```

---

*最后更新：2026-07-13*
*维护者：DWeis 团队*
