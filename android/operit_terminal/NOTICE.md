# OperitTerminalCore (modified)

本目录 `android/operit_terminal` 包含从 [Operit](https://github.com/AAswordman/Operit)
项目提取并修改的 `OperitTerminalCore` 终端内核模块（包名 `com.ai.assistance.operit.terminal`）。

- 原始许可证：**LGPL-3.0**（详见同目录 `LICENSE`）。
- 本模块为修改版本，用于 personal_agent_app 的“终端沙箱”功能：
  通过 PRoot + 内置 Ubuntu 24 rootfs 提供用户态 Linux 环境，
  由 Flutter 侧经 MethodChannel/EventChannel 驱动，未使用其 Compose UI 与 SSH/FTP 服务端。
- 对应源码即本仓库（personal_agent_app）中的该目录，已随仓库分发，满足 LGPL 提供对应源码的要求。
- 本模块以 `implementation(project(":operit_terminal"))` 方式被 `:app` 依赖，
  其原生库（liboperit_proot / libbash / libbusybox / libsudo / liboperit_loader / libpty）
  与 rootfs（`ubuntu-noble-aarch64-pd-v4.18.0.tar.xz`）随 APK 打包发布。
