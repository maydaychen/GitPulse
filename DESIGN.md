---
version: alpha
name: TeaPulse Design System
description: Dark-first precision instrument design system for native SwiftUI Gitea & DevOps management across iOS, iPadOS, and macOS.
colors:
  primary: "#10B981"
  primary-action: "#10B981"
  primary-hover: "#34D399"
  on-primary: "#04130D"
  secondary: "#94A3B8"
  tertiary: "#A78BFA"
  neutral: "#23293A"
  surface: "#0B0D13"
  surface-card: "#12151E"
  surface-elevated: "#1A1E2B"
  on-surface: "#F1F5F9"
  warning: "#FBBF24"
  error: "#F87171"
typography:
  headline-lg:
    fontFamily: "SF Pro Display"
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: -0.02em
  headline-md:
    fontFamily: "SF Pro Display"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: -0.01em
  body-md:
    fontFamily: "SF Pro Text"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.5
  body-sm:
    fontFamily: "SF Pro Text"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
  label-md:
    fontFamily: "SF Pro Text"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: 0.02em
  code-md:
    fontFamily: "SF Mono"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.55
    fontFeature: '"tnum" 1'
  code-sm:
    fontFamily: "SF Mono"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.4
    fontFeature: '"tnum" 1'
rounded:
  sm: 6px
  md: 10px
  lg: 14px
  xl: 20px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
components:
  button-primary:
    backgroundColor: "{colors.primary-action}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
    height: 40px
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
    height: 40px
  button-secondary:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
    height: 36px
  card-default:
    backgroundColor: "{colors.surface-card}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
  card-elevated:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.secondary}"
    typography: "{typography.headline-md}"
    rounded: "{rounded.xl}"
    padding: "{spacing.lg}"
  page-header:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.headline-lg}"
    padding: "{spacing.md}"
  badge-merged:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.tertiary}"
    typography: "{typography.code-sm}"
    rounded: "{rounded.sm}"
    padding: "{spacing.xs}"
  badge-running:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.warning}"
    typography: "{typography.code-sm}"
    rounded: "{rounded.sm}"
    padding: "{spacing.xs}"
  badge-error:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.error}"
    typography: "{typography.code-sm}"
    rounded: "{rounded.sm}"
    padding: "{spacing.xs}"
  code-block:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.code-md}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
  floating-dock:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label-md}"
    rounded: "{rounded.full}"
    padding: "{spacing.sm}"
---

## Overview

TeaPulse 是一套面向 Apple 全生态（iOS、iPadOS 与 macOS）原生 SwiftUI 代码托管与运维管理客户端的设计系统。视觉灵感源自 **Linear Mobile** 的高信噪比克制层级、**GitHub Mobile** 的移动端代码阅读体验，以及 **Raycast** 的命令驱动效率，彻底告别传统系统设置表单式的分组灰块风格。

界面采用 **Dark-First 精密仪器感** 气质：以低饱和石墨暗底建立安静的工作台，仅在 CI 构建结果、PR 合并状态与 Runner 在线信号处点亮语义色彩。在 iPhone 上强调单手拇指热区的底部悬浮毛玻璃控制坞；在 iPadOS 与 macOS 上自适应展开三栏 `NavigationSplitView` 与 `⌘K` 全局命令面板。

## Colors

色彩体系由中性石墨表面阶梯与高识别度工程状态信号色组成，所有文本与组件配对均满足 WCAG AA（>= 4.5:1）对比度基线。

| 语义角色 | Dark Mode | Light Mode | 用途说明 |
| --- | --- | --- | --- |
| `surface` | `#0B0D13` | `#F8FAFC` | 主画布底色与沉浸代码区底层 |
| `surface-card` | `#12151E` | `#FFFFFF` | 一级卡片、列表容器与面板主体 |
| `surface-elevated` | `#1A1E2B` | `#F1F5F9` | 悬浮 Dock、分段控件、状态徽章底 |
| `neutral` | `#23293A` | `#E2E8F0` | 次级按钮、微胶囊与分割线承载 |
| `on-surface` | `#F1F5F9` | `#0F172A` | 标题、正文与高对比代码文本 |
| `secondary` | `#94A3B8` | `#475569` | 元数据、时间戳、辅助说明文案 |
| `primary` | `#10B981` | `#047857` | 在线信号灯、CI 通过与强调文字 |
| `primary-action` | `#10B981` | `#047857` | 主动作与选中胶囊的实心背景 |
| `primary-hover` | `#34D399` | `#065F46` | 主动作按压／悬停背景 |
| `on-primary` | `#04130D` | `#FFFFFF` | 主动作与选中胶囊文字，浅色模式使用白字 |
| `tertiary` | `#A78BFA` | `#6D28D9` | PR 已合并、Stacked PR 合并列车标识 |
| `warning` | `#FBBF24` | `#B45309` | Workflow 运行中、待手动审批、延迟警告 |
| `error` | `#F87171` | `#B91C1C` | 构建失败、Runner 离线、Webhook 异常 |

即使全局切换为 Light Mode，源码浏览、Diff 对比与 Actions 终端日志面板仍保持独立的深色代码表面（`#0B0D13`），避免语法高亮在浅色背景下失真。

登录链路探针属于普通诊断卡片，使用随主题切换的 `surface-elevated` 与 `on-surface`，不使用固定深色代码表面。浅色模式的主动作使用深绿底白字，默认及按压状态均保持至少 4.5:1 的文字对比度。

## Typography

采用双字体系统分离「界面叙事」与「工程数据」：

- **界面字体**：`SF Pro Display` / `SF Pro Text`（Web 原型回退 `-apple-system, BlinkMacSystemFont, sans-serif`），保持与 Apple 原生系统一致的字重节奏。
- **工程等宽字体**：`SF Mono`（回退 `JetBrains Mono, ui-monospace, monospace`），专门用于 Commit SHA、分支名、Runner 标签、Diff 行号与终端日志。
- **等宽数字约束**：所有时间戳、PR 计数、`+128 -24` 增删行数与秒表计时器强制启用 `tabular-nums`（`font-feature-settings: "tnum" 1`），防止实时刷新时数字抖动。
- **最小字号底线**：所有可读正文、标签与代码块字号不低于 `12px`。

## Layout

遵循严格的大中小三级间距体系（`sm / md / lg`）建立清晰信息层级，禁止组件间使用散乱硬编码间距：

- **小间距 `sm (8px)`**：卡片内部行间距、同行按钮与徽章组间距、分组标题与本组列表间距。
- **中间距 `md (16px)`**：视口水平页边距、卡片与弹窗容器内边距、同组相邻卡片及双列网格间距。
- **大间距 `lg (24px)`**：页头与主内容之间、跨业务分组区块（Section）之间的垂直间距。
- **光学微距 `xs (4px)`**：仅用于状态徽章与微胶囊的内部光学垫高。
- **iPhone 紧凑单栏**：顶部安全区留给灵动岛实时构建进度，连接状态直接收敛于页头右侧单行探针胶囊；PR 详情与仓库页使用 Sticky 分段工作区与底部悬浮胶囊 Dock。
- **iPadOS / macOS 三栏分栏**：采用原生 `NavigationSplitView`，左侧 `220px` 毛玻璃侧边栏承载实例切换与 5 大一级视图，中间 `340px` 列表栏保留上下文，右侧自适应宽区直接展开代码树、Split Diff 或实时日志流。

## Elevation & Depth

用 **明度阶梯 + `1px` 半透明微边框**（Dark：`rgba(255, 255, 255, 0.08)`；Light：`rgba(15, 23, 42, 0.08)`）替代厚重投影和 iOS 原生 `InsetGroupedList` 灰底套白块。

1. **L0 画布层（`surface`）**：提供安静底色与终端隔离区。
2. **L1 内容卡层（`surface-card`）**：承载仓库、PR、Issue 与 Cron 任务行。
3. **L2 悬浮操作层（`surface-elevated`）**：配合背景毛玻璃（`ultraThinMaterial` / `backdrop-filter: blur(16px)`）用于底部 Dock、命令面板与模态弹窗。

## Shapes

收紧全圆大胶囊的滥用，通过克制的圆角建立工业精密感：

- `sm (6px)`：状态徽章、Commit SHA 标签、Git 分支胶囊。
- `md (10px)`：操作按钮、输入框、分段控件滑块、代码块容器。
- `lg (14px)`：标准列表卡片与统计模块。
- `xl (20px)`：桌面端主容器与弹出 Sheet 面板。
- `full (9999px)`：仅用于底部悬浮胶囊 Dock、头像与圆形状态呼吸灯。

## Components

- **主动作按钮（`button-primary`）**：每个视图只允许出现 1 个实心翡翠绿主按钮（如「批准并合并」或「立即同步」），其余次级操作统一使用低饱和 `neutral` 描边按钮。
- **单页 Sticky 分段工作区**：在 PR 与仓库详情顶部固定摘要头，下方横滑切换「概览对话 / 文件 Diff / CI 检查」，减少页面层级跳跃。
- **命令面板（`⌘K`）**：居中悬浮宽卡片，支持实时模糊搜索仓库、PR、Workflow 与运维任务，保持键盘上下键与回车直达。
- **智能列表行与防折行约束**：单行最多展示 3 层信息密度（主标题 + 等宽分支/状态胶囊 + 右侧对齐数值指标），禁止无序堆叠超过 3 个彩色 Label。所有按钮、状态徽章、分支胶囊与连接探针强制 `white-space: nowrap` 与 `flex-shrink: 0`；仓库路径与分支胶囊拆分为独立 Flex 对齐行，禁止内联拼接后跨行折断。

## Do's and Don'ts

- **Do**：用 `1px` 微边框和卡片明度差区分层级，让数据成为视觉主角。
- **Do**：为所有实时计时器、构建步数与增删行数开启 `tabular-nums`。
- **Do**：严格执行 `sm (8px)` / `md (16px)` / `lg (24px)` 三级间距体系，保持卡片内部紧凑、卡片之间居中、区块之间疏朗。
- **Do**：将同一条 PR 的对话、Diff 与 CI Checks 收敛到单页分段视图内完成闭环审阅。
- **Don't**：不要在浅色模式下铺满 `#F2F2F7` 原生设置表单灰块，也不要并排摆放高饱和大红大蓝方块按钮。
- **Don't**：不要让按钮文字、分支胶囊或顶栏连接状态折行显示，也不要把过长的说明文字塞进列表卡片与弹窗中。
- **Don't**：不要在非代码区域滥用花哨渐变，也不要让非关键徽章抢占「构建失败 / 掉线告警」的注意力。
- **Don't**：不要隐藏破坏性操作（删除仓库、Force Cancel、Reset Cron）的二次确认步骤。

## Motion

- **视图转场**：页面与面板切换使用平滑共享元素过渡或 `200ms cubic-bezier(0.22, 1, 0.36, 1)` 阻尼位移（SwiftUI 端对应 `TeaPulseMotion.snappy` `0.24s` 与 `TeaPulseMotion.spring` `0.32s`；Web 原型端使用 `document.startViewTransition`、`@starting-style` 与独立声明 `transition-behavior: allow-discrete`），体现方向性层级关系。
- **实时呼吸信号与微交互**：对「运行中 Workflow」「在线 Runner」与当前选中连接探针施加双层光环脉冲呼吸动效；可点击卡片、操作按钮、Diff 行内批注与步骤折叠采用轻量缩放（`0.98`）与数值滚动过渡（`.contentTransition(.numericText())`），列表静态正文保持静止。
- **无障碍降级**：严格响应 SwiftUI `@Environment(\.accessibilityReduceMotion)` 与 Web `@media (prefers-reduced-motion: no-preference / reduce)`，开启减少动态效果时仅保留短时长渐隐并取消空间位移、缩放与连续脉冲。

## Data Dense & Code UI

- **Diff 阅读器**：支持 Unified 与 Split 双视图；新增行背景采用 `rgba(16, 185, 129, 0.12)`、删除行采用 `rgba(248, 113, 113, 0.12)`，行号列固定不随代码横向滚动；点击任意行可在行下直接展开内联评审输入框。
- **ANSI 终端日志**：纯黑底 `#050608` 搭配高对比 ANSI 调色板；按 Step 折叠展示耗时，失败的 Step 默认自动展开并高亮首个报错行。
- **灵动岛 Live Activities**：构建进行中在锁屏与灵动岛紧凑显示仓库名、当前 Step 进度条与已用时长，不展示冗余长文本。
