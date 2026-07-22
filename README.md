<div align="center">

<img src="Resources/InceptLaunch-icon-source.png" width="160" alt="InceptLaunch" />

# InceptLaunch

**把 macOS 26 拿走的 Launchpad 找回来——原生、飞快。**

全屏可视化应用网格，支持文件夹、即时搜索和手动布局，
基于 SwiftUI + AppKit 打造，适用于 macOS Tahoe 及更新系统。

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue?logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange?logo=swift)](https://www.swift.org)
[![Release](https://img.shields.io/badge/release-1.0.0-brightgreen)](../../releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**简体中文** | [English](README_en.md)

</div>

---

## 为什么做这个

macOS 26 Tahoe 用类 Spotlight 的 Apps 入口取代了经典的 Launchpad。它搜索起来很高效，却丢掉了 Launchpad 最迷人的东西：**空间记忆**。知道某个应用在第几页、哪个角落，往往比每次都打字更快。

InceptLaunch 把这种体验带了回来——一个安静、全屏的网格，整理一次，终生可靠。

## 核心特性

- **全屏网格** —— 无边框 overlay，真实系统图标，页面指示器，行数随屏幕自适应。
- **即时搜索** —— 实时过滤，完整**拼音**支持（输入 `yy` 即可找到「音乐」/ Music），键盘导航，点任意空白处即退出。
- **文件夹** —— 把一个应用拖到另一个上即可成组；可重命名、在弹窗网格中打开、把应用拖出。
- **Apple 应用智能成夹** —— 首次启动时，几十个 `com.apple.*` 应用自动收进一个「Apple」文件夹，之后新装的也会悄悄归入，绝不打乱你的布局。
- **拖拽整理** —— 重排图标、跨页移动；布局自动保存，重新扫描也不会被打乱。
- **移到废纸篓** —— 长按或右键移除应用，带二次确认。
- **一键唤起** —— 随时用 `⌥ Space`、菜单栏或 Dock 打开。

## 安装

从 [Releases](../../releases) 下载最新的 `InceptLaunch-*.dmg`，打开后把 **InceptLaunch** 拖进 **Applications** 即可。

> 当前版本为 ad-hoc 签名的个人分发包。首次启动可能需要右键 → **打开** 以绕过 Gatekeeper。

## 快速上手

1. 启动 InceptLaunch。
2. 按 `⌥ Space`（Option + 空格）打开网格。
3. 点击应用即可启动，或直接输入开始搜索。
4. 拖动应用重新排列；把一个拖到另一个上即可建文件夹。
5. 按 `Esc` 或点击空白处退出。

## 路线图

InceptLaunch 的演进方向，对照最初的[设计规格](docs/superpowers/specs/2026-07-20-inceptlaunch-launchpad-replica-design.md)追踪。

| 阶段 | 重点 | 状态 |
|------|------|------|
| **v0.1** 原型 | 应用扫描、网格、搜索、启动、菜单栏 | ✅ 已完成 |
| **v0.2** 基础体验 | 全屏 overlay、全局快捷键、分页、设置、布局持久化 | ✅ 已完成 |
| **v0.3** 手动组织 | 拖拽排序、跨页移动、文件夹、Apple 与目录折叠 | ✅ 已完成 |
| **v0.4** 完整复刻 | 编辑模式、移到废纸篓、多显示器、动画打磨、键盘导航 | 🚧 进行中 |
| **v1.0** 稳定发布 | 性能、错误处理、首次使用引导、自动更新、签名与公证 | 📋 计划中 |

### 接下来要做

- **编辑模式** —— 长按进入抖动模式，批量整理和隐藏应用。
- **隐藏而非删除** —— 隐藏低价值应用（helper、卸载器等），可在设置中恢复。
- **多显示器与 Space** —— 在多显示器、全屏应用和 Stage Manager 下可预测地弹出，退出后焦点还原。
- **动画打磨** —— 打开/关闭、翻页、文件夹过渡，并遵循系统「减弱动态效果」设置。
- **多套布局** —— 在工作 / 个人 / 演示网格之间切换。
- **旧 Launchpad 迁移** —— 实验性地从旧版 Launchpad 数据库导入页面和文件夹。

## 设计原则

InceptLaunch 遵循「Launchpad 优先」的理念：

- 手动布局优先于智能排序。
- 视觉网格优先于命令输入。
- 隐藏优先于删除。
- 稳定启动优先于炫技动画。
- 本地持久化优先于云同步。

目标是做一个值得信赖的系统伴侣，而不是一个功能堆砌、核心摇晃的启动器。

## 参与贡献

这目前是一个个人项目。欢迎通过 [Issues](../../issues) 提交想法和 bug 报告。

## 许可协议

基于 [MIT 协议](LICENSE) 开源。版权所有 © 2026。
