# 📱 Material 3 Expressive 设计规范

> **适用对象**：personal-agent-app（Flutter / Android AI 助手）  
> **目标**：采用 Google 2025 年最新设计语言，让界面活泼、有表现力、注意力引导明确  
> **版本**：v2.0 (Material 3 Expressive) | 2026-06-25  
> **基础**：Material 3 Expressive（Android 16 / The Android Show 2025）

---

## 一、设计哲学（Expressive 核心）

### 1.1 四大支柱

| 支柱 | 说明 | 来源 |
|------|------|------|
| **色彩即是层级** | 用更明艳的色彩引导注意力，Surface Container 层级更丰富 | M3 Expressive 色彩指引 |
| **交互化作形变** | 打破固定圆角，用形状变化表达状态（如开关开启后变圆角矩形） | M3 Expressive 形状指引 |
| **弹簧驱动的系统** | 用 stiffness/damping/initial velocity 驱动动画，回弹自然 | Material Motion 2025 |
| **注意力战争** | 可变字体 + 色彩 + 容器分组，引导用户视线到关键操作 | M3 Expressive 排版指引 |

### 1.2 与基础 MD3 的本质差异

```
基础 MD3（2022-2024）: 克制、统一、系统感
M3 Expressive（2025+）: 活泼、有表现力、强调注意力引导

不是替代关系，是升级关系
M3 Expressive = M3 基础 + 更鲜明的色彩 + 形变动画 + 弹簧物理
```

### 1.3 情感曲线

```
用户打开 App → 感受到鲜活与个性（动态颜色 + 弹簧动画） → 操作获得即时形变反馈 → 注意力被引导到关键信息 → 产生"这很灵动"的愉悦感
```

---

## 二、视觉系统

### 2.1 色彩体系（Material 3 Expressive）

#### 核心变化：色彩即是层级

```
基础 MD3: 层级主要靠 elevation 阴影 + Surface Container 深浅
M3 Expressive: 层级主要靠 色彩明度/饱和度差异 + 玻璃模糊 + 容器分组

原则：用色彩引导视线，而不是仅靠阴影
```

#### 标准色板（Expressive 调优版）

```yaml
# Primary 更明艳，带有紫粉调
Primary:                #6750A4  (保留基线，但使用场景更广)
On Primary:             #FFFFFF
Primary Container:      #EADDFF
On Primary Container:   #21005D

# Secondary 更柔和
Secondary:              #625B71
On Secondary:           #FFFFFF
Secondary Container:    #E8DEF8
On Secondary Container: #1D192B

# Tertiary 更鲜明（Expressive 强调色）
Tertiary:               #7D5260 → 可调整为更鲜明的 #9A4EAE
On Tertiary:            #FFFFFF
Tertiary Container:     #FFD8E4
On Tertiary Container:  #31111D

# Error
Error:                  #B3261E
On Error:               #FFFFFF
Error Container:        #F9DEDC
On Error Container:     #410E0B

# Surface 层级更丰富（Expressive 重点）
Surface:                #FEF7FF
Surface Variant:        #E7E0EC
On Surface:             #1C1B1F
On Surface Variant:     #49454F
Outline:                #79747E

Surface Container Low:  #F3EDF7
Surface Container:      #ECE6F0
Surface Container High: #E6DFE9
Surface Container Highest: #E0D9E4

# Expressive 新增：高亮表面色（用于关键操作引导）
Surface Bright:         #FFFFFF  (比 Surface 更亮，用于 FAB、关键按钮)
Surface Dim:            #1C1B1F  (深色模式下的暗背景)
```

#### 语义化色彩规则（Expressive）

- **色彩引导注意力**：关键操作使用 `Tertiary` 或更高饱和度的颜色，而非仅依赖 Primary
- **AI 消息气泡**：使用 `Primary Container`（浅紫 #EADDFF），但**关键 AI 回复**可使用 `Tertiary Container`（浅粉 #FFD8E4）引导注意
- **用户消息气泡**：使用 `Primary`（深紫 #6750A4），但**发送成功**时可短暂变为 `Tertiary` 表达"完成"
- **工具调用状态**：
  - 进行中：`Secondary Container` + 脉冲动画
  - 成功：`Primary` + 勾选图标
  - 失败：`Error` + 震动反馈
- **渐变使用**：Expressive 允许在关键 CTA 使用更明显的渐变（Primary → Tertiary）

### 2.2 字体规范（Expressive 可变字体）

#### 字体栈

```yaml
中文: "Noto Sans SC", "PingFang SC", sans-serif
英文: "Roboto", "Noto Sans SC", sans-serif
数字/代码: "Roboto Mono", "SF Mono", monospace
# Expressive 强调：优先使用系统可变字体
```

#### 字号层级（Material 3 Type Scale + Expressive 调优）

| 角色 | 字号 | 字重 | 使用场景 | Expressive 调整 |
|------|------|------|---------|----------------|
| Display Large | 57pt | Regular | 极少用 | 可配合渐变色彩做品牌展示 |
| Display Medium | 45pt | Regular | 欢迎页 | 允许更大字重对比 |
| Headline Large | 32pt | Regular | 页面标题 | - |
| Headline Medium | 28pt | Regular | 卡片大标题 | 可配合字宽变化 |
| Title Large | 22pt | Regular | AI 名称 | - |
| Title Medium | 16pt | Medium | 列表项标题 | **Expressive：允许 14pt-16pt 动态调整** |
| Title Small | 14pt | Medium | 子标题 | - |
| Body Large | 16pt | Regular | AI 回复 | - |
| Body Medium | 14pt | Regular | 正文默认 | **Expressive：强调字重变化而非字号** |
| Body Small | 12pt | Regular | 辅助说明 | - |
| Label Large | 14pt | Medium | 按钮文字 | - |
| Label Medium | 12pt | Medium | 标签 | - |
| Label Small | 11pt | Medium | 时间戳 | - |

**Expressive 铁律**：
- 强调信息通过**字重（100-900 可变）+ 色彩**表达，不是放大字号
- 中文可变字体目前缺失 100-400 字重，需回退处理
- AI 回复使用 `Body Large`（16pt），但关键结论可用 `Medium` 字重 + `Tertiary` 色引导

### 2.3 间距系统（Expressive）

```
基础单位: 8pt

Expressive 调整：更紧凑但有呼吸感
  4pt  (0.5x)   - 图标与文字
  8pt  (1x)     - 列表项内边距
  12pt (1.5x)   - 紧凑卡片
  16pt (2x)     - 卡片间距
  24pt (3x)     - 区域间距（Expressive 可减小到 20pt）
  32pt (4x)     - 页面级间隔（Expressive 可减小到 28pt）
```

**Expressive 特有规则**：
- 容器分组间距：同类元素内部 8pt，不同组之间 16pt（用间距区分组）
- 关键操作周围留白更大（12-16pt），引导注意力
- 不再严格依赖 8pt 网格，允许 4pt 微调

### 2.4 圆角与形变（Expressive 核心）

#### 标准圆角（保留 MD3 基础）

```
Extra Small:  4pt  - 小元素
Small:        8pt  - 小按钮
Medium:       12pt - 输入框、卡片
Large:        16pt - 对话框
Extra Large:  28pt - 底部导航栏
Full:         999pt - 圆形头像、FAB
```

#### Expressive 形变规则（核心创新）

```
原则：形状变化表达状态，打破固定圆角

开关/切换类组件：
  关闭状态：圆角矩形（8pt 圆角）
  开启状态：通过动画过渡到更圆润的形状（16pt 圆角）
  形变过程：弹簧动画，视觉上"弹"开

按钮状态：
  默认：20pt 圆角（标准）
  按下/激活：圆角变小（12pt），配合缩放动画
  反馈：InkWell 涟漪 + 轻微形变

消息气泡：
  入场：从 12pt 圆角"弹"到 16pt 圆角
  长按：圆角暂时变小，提示可操作

卡片：
  悬浮态：elevation 增加 + 圆角从 12pt 变为 16pt
  展开态：圆角从 16pt 变为 28pt（全屏展开时）
```

#### 阴影/高度（Expressive 调整）

```
基础 MD3 Elevation 保留，但 Expressive 更依赖色彩区分层级

Level 0:      0dp   - 默认（Surface Container）
Level 1:      1dp   - 悬浮卡片（Expressive：可配合色彩微调）
Level 2:      3dp   - 弹窗
Level 3:      6dp   - 对话框
Level 4:      8dp   - 底部抽屉
Level 5:      12dp  - 全屏弹窗

Expressive 新增：
- 玻璃模糊辅助层级（而非纯阴影）
- 关键组件使用 Surface Bright（更亮）表达"在前"
- 深色模式下 elevation 阴影更亮（与浅色模式相反）
```

---

## 三、组件规范（Expressive）

### 3.1 消息列表（Expressive 风格）

```
AI 消息：
┌─────────────────────────────────────┐
│ [AI 头像]                            │
│ ┌─────────────────────────────────┐  │
│ │ AI 消息内容                       │  │
│ │ 圆角 16pt（Medium）              │  │
│ │ 背景：Primary Container           │  │
│ │ 内边距：12pt 16pt                │  │
│ │ 文字：On Primary Container        │  │
│ │ 行高：1.5                        │  │
│ │ 最大宽度：80%                    │  │
│ └─────────────────────────────────┘  │
└─────────────────────────────────────┘

用户消息：
┌─────────────────────────────────────┐
│                            [用户头像] │
│ ┌─────────────────────────────────┐  │
│ │ 用户消息内容                       │  │
│ │ 圆角 16pt（Medium）              │  │
│ │ 背景：Primary                    │  │
│ │ 文字：白色                        │  │
│ │ 入场动画：弹簧形变（12pt→16pt）  │  │
│ └─────────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Expressive 特有规则**：
- 消息入场使用**弹簧动画**：从 12pt 圆角"弹"到 16pt，持续 300ms，expressive 曲线
- 关键 AI 回复（如结论、警告）使用 `Tertiary Container` 背景 + 左侧 3pt `Tertiary` 指示条
- 发送中状态：消息占位使用 `Surface Container High` + Shimmer，形状保持 16pt
- **不做**：左侧彩色指示条（那是 Apple 风格），Expressive 用色彩和形状引导

### 3.2 工具调用展示（Expressive 风格）

```
进行中：
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │ 🌤️ 正在查询天气...              │ │ ← Assist Chip + 脉冲动画
│ │ [=========>     ] 60%           │ │ ← 可选：线性进度指示
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

完成：
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │ ✅ 北京 26°C，晴                  │ │ ← Assist Chip + 勾选
│ │ 湿度 45% | 风速 12km/h          │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

失败：
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │ ❌ 天气查询失败                   │ │ ← Error 色 + 震动反馈
│ │ 请检查网络后重试 [重试]           │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Expressive 特有规则**：
- 使用 MD3 `AssistChip`，但**进行中状态使用脉冲动画**（不是静态加载圈）
- 完成时 Chip **形变反馈**：从 `FilterChip`（有边框）变为 `AssistChip`（无边框），圆角从 8pt 变为 20pt
- 失败时使用 `Error` 色 + `HapticFeedback.heavyImpact` + 3 秒后自动淡出
- **禁止 Toast/SnackBar**，全部内联展示

### 3.3 任务规划（Task Plan）可视化（Expressive）

```
┌─────────────────────────────────────┐
│ 📋 任务规划                           │
│ ┌─────────────────────────────────┐  │
│ │ ┌─ ✓ 分析需求                   ─┐│  ← completed：Checkbox 勾选 + 文字 Tertiary 色
│ │ └───────────────────────────────┘│  │
│ │ ┌─ ○ 搜索信息                   ─┐│  ← pending：Checkbox 未勾选
│ │ └───────────────────────────────┘│  │
│ │ ┌─ ⟳ 生成报告（进行中）         ─┐│  ← in_progress：indeterminate + 脉冲边框
│ │ └───────────────────────────────┘│  │
│ └─────────────────────────────────┘  │
└─────────────────────────────────────┘

Expressive 增强：
- 整体卡片使用 Surface Container High
- 进行中项：边框使用 Primary 色 + 脉冲动画（不是静态进度条）
- 完成项：文字颜色 On Surface Variant，勾选图标 Tertiary 色
- 失败项：文字 Error 色 + 下方展示错误原因 + onTap 重试
- 进度指示：顶部线性进度条，颜色 Primary → Tertiary 渐变
```

**Expressive 特有规则**：
- 每项任务是一个**独立容器**（Card），不是 ListTile
- 状态切换时使用**弹簧动画**：Checkbox 状态变化 + 圆角形变
- 进度条使用 `LinearProgressIndicator`，颜色 `Primary`，背景 `Surface Container`

### 3.4 输入框（Expressive 风格）

```
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │ 输入消息...                     📎│ │  ← Filled TextField + 玻璃模糊
│ └─────────────────────────────────┘ │
│  [发送]                              │  ← Filled Tonal Button
└─────────────────────────────────────┘

Expressive 调整：
- 背景使用 Surface Container Highest + 轻微玻璃模糊（iOS 风格但在 MD3 框架内）
- 圆角 20pt（标准）
- 聚焦态：底部边框变 Tertiary 色（不是 Primary），宽度 3pt
- 发送按钮有内容时：FilledButton，圆角 20pt
- 发送按钮按下时：圆角短暂变为 12pt（形变反馈）
```

### 3.5 按钮系统（Expressive）

```
类型                样式                         使用场景
Filled Button      填充 Primary 色              发送、确认
Filled Tonal       填充 Primary Container       次要操作
Outlined Button    边框 Outline 色              取消
Text Button        纯文字                       删除、编辑
Elevated Button    带 elevation + 圆角形变      重要主操作

FAB (Floating Action Button)
  圆形 56pt，Primary 色，带 elevation 6dp
  用于主要创建操作
  Expressive：长按时圆角从 28pt 变为 16pt（形变）
```

**Expressive 特有规则**：
- 按钮高度：40pt（MD3 标准）
- 点击反馈：`InkWell` + `HapticFeedback.lightImpact` + **轻微缩放（0.95x）**
- 主次按钮并排：主操作在右
- FAB：使用 `FloatingActionButton.extended` 时，文字与图标间距 8pt

### 3.6 玻璃模糊与容器（Expressive 新增）

```
Expressive 允许在以下场景使用玻璃模糊（MD3 基础版不鼓励）：

1. 底部输入栏：Surface Container Highest + 20% 透明度 + 模糊
2. 悬浮卡片：Surface Bright + 10% 透明度 + 模糊
3. 对话框背景：Dim 遮罩 + 15% 透明度

Flutter 实现：
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  child: Container(
    color: colorScheme.surfaceContainerHighest.withOpacity(0.8),
  ),
)
```

**Expressive 规则**：
- 模糊仅用于层级区分，不做装饰性滥用
- 深色模式下模糊强度减半（sigmaX: 5）
- 性能敏感场景（列表滚动）禁用模糊

---

## 四、交互与动效（Expressive 核心）

### 4.1 动画原则（Material Motion Expressive）

```
原则 1：动画表达层级与空间关系
原则 2：元素从哪里来，回哪里去
原则 3：弹簧驱动，回弹自然
原则 4：形状变化表达状态（形变动画）
原则 5：尊重系统设置（减少动态效果时禁用）
```

### 4.2 标准动画参数（Expressive）

#### 弹簧动画 Token

```
Material 3 Expressive 提供两套预配置弹簧：

Standard（标准）：
  适用于：页面转场、列表项动画、常规状态切换
  刚度：中等 | 阻尼：中等 | 初始速度：中等
  效果：平滑、自然、不夸张

Expressive（表现力）：
  适用于：按钮反馈、开关切换、消息入场、FAB 展开
  刚度：较高 | 阻尼：较低 | 初始速度：较高
  效果：明显回弹、活泼、有弹性
```

#### 具体场景参数

| 场景 | 时长 | 曲线/弹簧 | 说明 |
|------|------|-----------|------|
| 按钮点击反馈 | 150ms | Expressive 弹簧 | 轻微缩放 + 形变 |
| 消息气泡入场 | 350ms | Expressive 弹簧 | 圆角从 12pt 弹到 16pt |
| 页面切换 | 300ms | Standard 弹簧 | MD3 标准转场 |
| FAB 展开/收起 | 250ms | Expressive 弹簧 | Container Transform + 形变 |
| Sheet 弹出 | 400ms | Expressive 弹簧 | 从底部滑入 + 回弹 |
| 任务状态切换 | 200ms | Expressive 弹簧 | Checkbox + 圆角形变 |
| Chip 加载动画 | 1200ms | linear | 无限循环脉冲 |
| 骨架屏闪烁 | 1500ms | linear | 无限循环 |
| 开关切换 | 300ms | Expressive 弹簧 | 形状从矩形变圆角矩形 |
| 滑动删除 | 400ms | Expressive 弹簧 | 阻尼粘滞 + 分离振动 + 回弹 |

**Expressive 转场模式**：
- `Container Transform`：FAB 展开为全屏页面（Expressive 弹簧）
- `Shared Axis`：页面间前后导航（Z 轴，Standard 弹簧）
- `Fade Through`：同级页面切换（底部导航，Standard 弹簧）
- `Fade`：模态弹窗、Tooltip

### 4.3 触觉反馈（Expressive 强化）

```
场景                      反馈类型              时机
消息发送成功              light                发送完成瞬间
任务状态切换              medium               状态锁定瞬间
按钮点击                  light                按下时
开关切换                  medium               切换完成时
操作确认（保存/删除）     heavy                确认瞬间
错误/警告                 notificationError    错误触发时
长按菜单                  light                长按触发时
滑动操作                  medium               达到阈值时
FAB 点击                  medium               点击时
滑动删除通知              heavy                分离临界点时
```

**Expressive 规则**：
- 每个有意义的动画都应有触觉反馈配合
- 振动触发时机：松手、按下、状态锁定、终点触达
- 错误反馈使用 `notificationError`（平台原生），不是自定义震动

### 4.4 骨架屏（Expressive Shimmer）

```
┌─────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░                  │  ← Shimmer 效果
│ ░░░░░░░░                            │
│ ░░░░░░░░░░░░░░░░░░                  │
└─────────────────────────────────────┘

Expressive 调整：
- 骨架屏背景色：Surface Container Highest
- Shimmer 高光：Tertiary 色的 10% 透明度（不是 Primary）
- 脉冲周期：1.5s，线性循环
- 工具调用返回后立即替换，不超过 3s 无响应
```

---

## 五、深色模式（Expressive）

### 5.1 Expressive 动态深色

```
浅色模式:
  Surface:         #FEF7FF
  Surface Variant: #E7E0EC
  Primary:         #6750A4
  On Surface:      #1C1B1F

深色模式:
  Surface:         #141218
  Surface Variant: #49454F
  Primary:         #D0BCFF  (更亮，Expressive 强调)
  On Surface:      #E6E1E5
  Surface Bright:  #2B2930  (Expressive 新增，用于关键元素)
  Surface Dim:     #0C0B0E  (Expressive 新增，用于背景)
```

### 5.2 Expressive 特有规则

- 动态颜色在深色模式下**自动调整亮度**，不需要手动计算
- 深色模式下 elevation 阴影使用 **更亮** 的颜色（与浅色模式相反）
- 深色模式下 `Surface Bright` 用于 FAB、关键按钮，使其"浮"在暗背景上
- 玻璃模糊在深色模式下更明显（sigmaX: 5 → 可调整为 8）
- 所有颜色必须来自 `ColorScheme`，禁止硬编码

---

## 六、无障碍（Expressive）

### 6.1 Expressive 必做清单

- [ ] 所有可交互元素 ≥ 48 × 48pt（MD3 标准）
- [ ] 颜色对比度 ≥ 4.5:1（WCAG AA），Expressive 色彩更鲜艳但必须保证对比度
- [ ] 支持系统字体缩放（动态字号）
- [ ] 所有图标配有 `Semantics` 标签
- [ ] AI 回复支持系统读屏
- [ ] Focus 指示器可见（Primary 色，宽度 2pt）
- [ ] **减少动态效果用户**：禁用弹簧动画，回退到标准缓动

### 6.2 Expressive Focus 与交互

```
Expressive 要求：
- 所有可聚焦元素必须有可见的 Focus Indicator
- Focus 环使用 Primary 色，宽度 2pt
- 焦点顺序符合视觉顺序
- 弹簧动画在"减少动态效果"开启时禁用
- 形变动画在"减少动态效果"开启时禁用
```

---

## 七、性能与稳定性

### 7.1 流畅度底线

```
60fps 是底线，不是目标
列表滚动必须保持 60fps（使用 ListView.builder）
AI 流式输出时禁止阻塞 UI 线程（必须 isolate 或 compute）
图片懒加载（CachedNetworkImage）
超出视口 200px 开始预加载
玻璃模糊仅在必要时使用，避免在列表项中滥用
```

### 7.2 加载状态规范（Expressive）

```
场景                      展示方式
网络请求 < 300ms          不展示 loading
网络请求 300ms - 2s       Shimmer 骨架屏（Tertiary 色高光）
网络请求 > 2s            Shimmer + "正在处理中..." 文字
工具调用                 内联 Assist Chip + 脉冲动画
长时间生成（> 10s）      线性进度条 + 预计剩余时间 + 弹簧动画
```

### 7.3 错误恢复（Expressive）

```
错误类型          用户看到                          操作                   反馈
网络中断          "网络似乎不太稳定" + 重试按钮      自动重试 1 次          heavy
工具调用失败      "遇到点问题：xxx" + 重试按钮       不阻断流程            notificationError
AI 生成失败       Shimmer 占位 + "内容加载失败" + 重试 保持上下文            medium
未知错误          "出错了，请稍后再试"              日志上报               heavy

Expressive 特有：错误提示使用 MaterialBanner + 弹簧入场动画
```

---

## 八、内容策略（AI 对话专用，Expressive）

### 8.1 AI 回复的语气

```
✅ 简洁、具体、可操作
❌ 冗长铺垫、"当然可以"、"很高兴为您服务"
✅ 直接给出答案，必要时附说明
❌ 反问用户"您需要我帮您吗？"

Expressive 增强：
- 关键结论使用 Title Medium + Tertiary 色，让用户一眼看到
- 分步骤回复时，每步使用 Checkbox + 圆角容器，增强可扫描性
```

### 8.2 消息长度

```
普通对话：1-3 屏可读完（约 300 字以内）
长回复：分段 + 摘要开头（摘要使用 Title Medium 字重）
代码输出：附带运行说明
列表/步骤：每步 1 行，不超过 7 步
```

### 8.3 工具调用的用户感知

```
不要显示原始 JSON/参数
只展示：正在做什么 + 结果摘要

Expressive 增强：
- 工具调用状态变化使用弹簧动画 + 触觉反馈
- 成功时 Chip 形变（FilterChip → AssistChip）
- 失败时 Chip 抖动动画 + 重试按钮弹出
```

---

## 九、Flutter 实现检查清单（Expressive）

### 9.1 主题系统（Material 3 Expressive）

```dart
// 必须使用 ThemeData + ColorScheme，启用 MD3
MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  ),
)
```

### 9.2 弹簧动画实现

```dart
// 使用 SpringSimulation 实现 Expressive 弹簧
class ExpressiveSpring {
  static SpringSimulation get spring => SpringSimulation(
    SpringDescription(
      mass: 1.0,
      stiffness: 300.0,      // 较高刚度
      damping: 15.0,         // 较低阻尼（回弹明显）
    ),
    0.0,
    1.0,
    0.0,
  );

  static SpringSimulation get standard => SpringSimulation(
    SpringDescription(
      mass: 1.0,
      stiffness: 200.0,      // 中等刚度
      damping: 25.0,         // 中等阻尼
    ),
    0.0,
    1.0,
    0.0,
  );
}

// 使用方式
AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 300),
)..animateWith(ExpressiveSpring.spring);
```

### 9.3 形变动画实现

```dart
// 消息气泡入场形变动画
class MessageBubbleAnimation extends StatefulWidget {
  @override
  _MessageBubbleAnimationState createState() => _MessageBubbleAnimationState();
}

class _MessageBubbleAnimationState extends State<MessageBubbleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: ExpressiveSpring.spring),
    );
    
    _radiusAnimation = Tween<double>(begin: 12.0, end: 16.0).animate(
      CurvedAnimation(parent: _controller, curve: ExpressiveSpring.spring),
    );
    
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radiusAnimation.value),
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: const Text("AI 消息"),
      ),
    );
  }
}
```

### 9.4 组件检查清单

- [ ] `useMaterial3: true` 已开启
- [ ] `ColorScheme.fromSeed` 已配置动态取色
- [ ] 所有 `Card` 使用 `CardTheme`
- [ ] 所有 `TextField` 使用 MD3 `filled` 风格
- [ ] 所有 `Button` 使用 MD3 类型
- [ ] `ListView` 使用 `physics: const BouncingScrollPhysics()`
- [ ] `FAB` 仅在主页面使用
- [ ] 错误提示使用 `MaterialBanner`
- [ ] `BottomNavigationBar` 使用 `NavigationBar`（MD3 版本）
- [ ] **弹簧动画**：按钮、消息入场、状态切换使用 Expressive 弹簧
- [ ] **形变动画**：圆角变化配合弹簧动画
- [ ] **触觉反馈**：关键操作配合 `HapticFeedback`
- [ ] **玻璃模糊**：仅在输入栏、悬浮卡片使用 `BackdropFilter`

---

## 十、扩展规则

### 11.1 新增工具时的 UI 规范

当新增任何工具调用时，必须配套：
1. 状态展示：使用 MD3 `AssistChip` + 脉冲动画
2. 结果展示：使用 `Card` 或 `ListTile`
3. 错误状态：使用 `AssistChip` + 错误色 + `onTap` 重试 + 震动反馈

### 11.2 多 Agent 协调模式下的 UI

当 Manager 模式启用时：
- 当前发言者名称显示在消息顶部，使用 `Label Medium`
- 多个 Agent 的消息用 **头像** 区分
- 切换 Agent 时使用 `Fade Through` 转场 + Standard 弹簧

### 11.3 未来适配

```
Material You 进化：
- 取色范围扩展到用户照片、相册
- 动态形状（用户偏好圆角/直角时自动调整）
- 动态字体（用户字体大小偏好自动适配）

Android 16+：
- 边缘到 edge 显示适配
- Predictive Back 手势动画
- 浮动工具窗口（桌面模式）

Expressive 进化：
- 更丰富的弹簧 token
- AI 生成界面专用组件
- 多设备协同动效
```

---

## 十一、迁移指南（从基础 MD3 到 Expressive）

### 12.1 快速检查清单

- [ ] 色彩：检查是否使用更鲜明的 Tertiary 色引导关键操作
- [ ] 形状：检查关键组件是否有形变动画（圆角变化）
- [ ] 动画：将标准 `CurvedAnimation` 替换为 `SpringSimulation`
- [ ] 反馈：为关键操作添加 `HapticFeedback`
- [ ] 容器：检查是否使用容器分组 + 玻璃模糊
- [ ] 字体：检查是否使用字重变化构建层级

### 12.2 优先级建议

```
第一阶段（1-2 天）：
- 启用弹簧动画（按钮、消息入场）
- 添加触觉反馈
- 关键操作使用 Tertiary 色

第二阶段（3-5 天）：
- 实现形变动画（圆角变化）
- 添加玻璃模糊到输入栏
- 任务规划卡片化

第三阶段（1 周）：
- 可变字体优化
- 完整容器分组系统
- 性能优化（模糊、动画）
```

---

> **文档维护规则**：本文件由 AI 助手维护，任何设计决策变更必须更新此文档。禁止在代码中硬编码设计值而不更新本文档。  
> **参考来源**：Material Design 3 Expressive 官方文档、The Android Show 2025、Android 16 系统界面分析
