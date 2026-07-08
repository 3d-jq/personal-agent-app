# DWeis UI 重设计系统规范 v2（苹果原生极简 · 浅色/暗色双模）

> 设计师：像素君（UI Designer）｜日期：2026-07-08
> 目标：消除"简陋感"——建立统一设计语言，达到大厂原生 App 质感。
> 设计语言：**Apple Human Interface Guidelines**，克制、留白、毛玻璃、细腻分隔线、克制动效。
> 约束：AI 气泡（大模型回答）显示保持现状不变。

---

## 1. 设计原则

1. **一致性优先**：所有尺度来自令牌（design_tokens），禁止散落 magic number。
2. **深度靠阴影，不靠边框**：用极淡阴影（shadowSm/Md/Lg）制造"浮起感"，0.5px 分隔线仅用于列表内分隔。
3. **留白即节奏**：4pt 栅格（4/8/12/16/20/24/32/40/48/64）统一呼吸感。
4. **克制动效**：按压微缩放/高亮、页面转场 250ms，不喧宾夺主。
5. **双模同源**：浅色/暗色共用同一套语义 token，仅色值切换，结构不变。

---

## 2. 色彩系统（语义 token）

### 浅色 Light
| 语义 | token | 值 | 用途 |
|---|---|---|---|
| 页面底 | `background` | `#FAFAFA` | 所有主界面、顶栏、底栏 |
| 卡片/浮层 | `surface` | `#FFFFFF` | 卡片、对话框、弹窗、输入框 |
| 次级区/分组 | `surfaceSecondary` / `bgSubtle` | `#F2F2F7` | 列表分组块、输入框底、导航选中底 |
| 品牌蓝 | `primary` | `#007AFF` | 主按钮、选中态、链接 |
| 品牌悬停 | `primaryHover` | `#0056CC` | 按压/悬停 |
| 品牌淡底 | `brandSoft` | `#E6F1FB` | 高亮chip、选中背景 |
| 文字主 | `textPrimary` | `#1C1C1E` | 标题、正文 |
| 文字次 | `textSecondary` | `rgba(60,60,67,.6)` | 副标题、说明 |
| 文字三 | `textTertiary` | `rgba(60,60,67,.3)` | 角标、占位 |
| 文字禁 | `textDisabled` | `rgba(60,60,67,.2)` | 禁用态 |
| 文字在品牌上 | `onPrimary` | `#FFFFFF` | 主按钮文字 |
| 分隔线 | `divider` | `rgba(60,60,67,.2)` | 0.5px 发丝线 |
| 按压填充 | `fillTertiary` | `rgba(60,60,67,.08)` | 列表项按压高亮 |
| 成功 | `success` | `#34C759` | 状态 |
| 警告 | `warning` | `#FF9500` | 状态 |
| 错误 | `error` | `#FF3B30` | 删除/停止 |

### 暗色 Dark
| 语义 | token | 值 |
|---|---|---|
| 页面底 | `background` | `#000000` |
| 卡片/浮层 | `surface` | `#1C1C1E` |
| 次级区 | `surfaceSecondary` | `#2C2C2E` |
| 品牌蓝 | `primary` | `#0A84FF` |
| 品牌悬停 | `primaryHover` | `#409CFF` |
| 文字主 | `textPrimary` | `#F2F2F7` |
| 文字次 | `textSecondary` | `rgba(235,235,245,.6)` |
| 文字三 | `textTertiary` | `rgba(235,235,245,.4)` |
| 分隔线 | `divider` | `rgba(235,235,245,.2)` |
| 按压填充 | `fillTertiary` | `rgba(235,235,245,.12)` |

### 阴影/层级（替代全 0.5px 边框）
| token | 浅色 | 暗色 | 用途 |
|---|---|---|---|
| `shadowSm` | `0 1px 2px rgba(0,0,0,.04)` + `0 1px 1px .03` | `0 1px 2px rgba(0,0,0,.5)` | 卡片、输入栏 |
| `shadowMd` | `0 4px 12px .06` + `0 1px 3px .04` | `0 8px 24px .6` | 弹窗、浮层 |
| `shadowLg` | `0 12px 32px .10` + `0 4px 8px .04` | `0 16px 40px .7` | 大浮层、向导 |

---

## 3. 字体层级

字体族：系统字体（`-apple-system` / SF Pro），中文回退系统。
字重：`regular 400` / `medium 500` / `semibold 600` / `bold 700`。

| token | 字号 | 字重 | 用途 |
|---|---|---|---|
| `micro` | 11 | 500 | Tab 角标 |
| `caption` | 12 | 500 | 分组小标题、时间 |
| `small` | 13 | 400 | 副说明、步骤状态 |
| `body` | 15 | 400 | 正文、列表预览 |
| `bodyLg` | 17 | 400 | 大正文 |
| `title` | 17 | 600 | 卡片标题、会话名 |
| `headline` | 20 | 600 | 页面主标题 |
| `title2` | 22 | 700 | 区块标题 |
| `display` | 28 | 700 | 欢迎/引导大标题 |
| `largeTitle` | 34 | 700 | 极少用 |

行高：正文 1.4–1.5，标题 1.2–1.3。

---

## 4. 间距（4pt 栅格）
`xs4 / sm8 / md12 / lg16 / xl20 / x2 24 / x05 40 / x3 32 / x4 48 / x5 64`

---

## 5. 圆角（单一来源）
`sm8 / md12 / lg16 / xl20 / bubble18 / pill24 / full∞`
- chip/标签：sm(8)
- 卡片/按钮/输入框：md(12)
- 底部 Sheet/Modal：lg(16)
- 用户气泡：bubble(18)（保留现状）
- 输入胶囊/头像组：pill(24)
- 圆形头像/按钮：full

---

## 6. 动效
`fast 150ms`（按压/态切换）· `normal 250ms`（页面/浮层）· `slow 350ms`（大转场）
曲线：`Curves.easeOutCubic`。按压用 `PressableScale`（弹簧 0.95）或 `fillTertiary` 高亮（无 Android 水波纹）。

---

## 7. 组件库规范（统一组件，禁止重复造轮子）

### AppTopBar（统一顶栏，替代全部散落 AppBar）
- 毛玻璃 `blur 20` + 半透明 `background(.82)` + 底部 0.5px `divider` 发丝线。
- 支持 `leading`（菜单/返回）、`title`、`actions`、`centerTitle`、`useGlass`。
- 高度 48（聊天页可 48+statusBar）。

### AppBottomNav（统一底栏，替代两套并存底栏）
- 浮动胶囊式（参考现有 `agent_bottom_nav` 的 3-tab 浮动设计），毛玻璃 `surface` + 0.5px 边框 + 圆角 pill(24)。
- 选中态：滑动指示器 `primarySurface` 圆角背景 + 图标 Fill 字重 + 文字 `primary`。
- 支持可配置 tab 列表（主页/消息、Agent/库、探索）与可选输入态切换。
- 顶部无生硬边框，靠毛玻璃与阴影浮于内容之上。

### ElevatedCard（带阴影卡片）
- `surface` 底 + `shadowSm` + 可选 0.5px `divider` 边框；圆角 md(12)。
- 旧 `RoundedCard`（仅边框无阴影）标记废弃，逐步迁移。

### AppListTile（统一列表项）
- `leading`(图标/头像) + `title` + `subtitle` + `trailing`；垂直 padding md(12)。
- 按压：`highlightColor = fillTertiary`，无 Android 水波纹（`NoSplash`）。
- 可选 `showDivider`（0.5px，缩进对齐 leading）。

### AppButton（统一按钮）
- `primary`（品牌蓝实心）/ `secondary`（surface + 0.5px 边框）/ `ghost`（透明）。
- 高 48，圆角 md(12)，字重 semibold；`disabled` 态降透明度。

### AppAvatar（统一头像）
- 首字母 + 品牌蓝→hover 渐变；圆角 `size*0.3`（squircle 感）；可选 `ring`（白色描边 + shadowSm）。

### 状态组件
- `StatePlaceholder`（empty/loading/error）已存在，全量接入。
- `Skeleton` 系列接入聊天加载、列表加载。
- 空状态插画用 Phosphor 大图标 + 双行文案（标题 + 说明）。

---

## 8. 导航统一方案
- **废弃** `agent_home_page` 自写 2-tab 底栏与多页散落标准 `AppBar`。
- **统一**为 `AppTopBar`（全部页面）+ `AppBottomNav`（主页流程）。
- 主流程：`ChatScreen`（根对话，左抽屉 + AgentTopBar）→ 抽屉进入 `AgentHomePage`（消息/Agent 两 tab）→ 各子页用 `AppTopBar`。
- 群聊、设置、笔记等子页统一 `AppTopBar`，返回键用 `Icons.arrow_back_ios_new`（框架原生，杜绝 tofu）。

---

## 9. 验收标准
- [ ] `flutter analyze` 零问题；全库无散落圆角/间距 magic number（全部走令牌）。
- [ ] 无 `Colors.white/black` 硬编码（暗色不翻车）。
- [ ] 全 App 顶栏/底栏各只有一套实现。
- [ ] 卡片有阴影层次，不再"平面"。
- [ ] 暗色模式可一键切换且精致。
- [ ] 列表项/按钮有 iOS 按压反馈。
