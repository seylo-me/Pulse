# Pulse 脉动

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="Pulse Icon" />
</p>

<p align="center">
  <strong>极简工业美学 macOS 状态栏系统监控与 AI 配额看板</strong><br>
  融合 Nothing OS 点阵物理质感与 Apple visionOS 透亮毛玻璃胶囊交互
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift" alt="Swift 5.10" />
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-007ACC?style=flat-square" alt="Universal Binary" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License MIT" />
</p>

---

## ✦ 设计理念 (Design Philosophy)

**Pulse** 是一款专为开发者与极简设计爱好者打造的 macOS 状态栏应用。我们拒绝冗余花哨的图表堆砌，将 **Nothing OS** 的点阵物理美学、**Teenage Engineering** 的工业严谨感以及 **iOS / visionOS** 的透亮毛玻璃胶囊控制语言深度融合，打造出既克制又有呼吸感的桌面常驻工具。

- **双独立状态栏体系**：网络/硬件监控与 AI 额度中心完全解耦，既可合并联动，也可各自独立常驻与隐藏。
- **极致能耗控制**：后台静默常驻时 CPU 占用稳定在 **0.1%** 以下；仅在点击展开浮窗时动态接入高精度采样。
- **iOS 玻璃胶囊滑块**：告别刻板方角矩形，采用具有物理弹簧惯性的横向滑动高光半透胶囊（`matchedGeometryEffect`）。

---

## ⚡ 核心功能特性

### 1. 📡 实时网络流量监控 (Traffic Monitor)
- **真点阵数字呈现**：采用 5x7 点阵几何光点精准绘制上下行瞬时流速（KB/s、MB/s 自动换算）。
- **Dot-Matrix 频谱均衡器**：48 列动态点阵声谱风格流速柱，具备真实物理惯性衰减动效。
- **Wi-Fi 与公网 IP 诊断**：实时监测 SSID 信号质量、频段速率，一键复制公网与内网 IPv4。
- **Top 活跃进程流速**：精准追踪当前系统占用带宽前 5 的进程与即时收发流量。

### 2. 💻 硬件概览看板 (Hardware Overview)
- **CPU 处理器监控**：实时多核占用率、动态负载进度条与多核心遥测微块（Telemetry Micro-blocks）。
- **GPU 图形显卡**：核心利用率、显存占用（VRAM）、核心温度与帧率监控。
- **内存深度剖析**：分级透视 App 内存、联动联动内存、系统压缩与可用空闲内存。
- **SSD 存储与供电状态**：APFS 存储剩余空间，自动区分台式机交流直供电（AC Power）与笔记本电池状态。

### 3. ✨ AI 额度中心 (AI Quota Center)
- **多模型配额聚合**：聚合 **Antigravity (Google AI)**、**Codex (OpenAI)**、**Claude**、**Grok**、**DeepSeek** 配额看板。
- **独立状态栏驻留**：可将任意主力 AI 模型（如 Codex、Antigravity）单独钉在状态栏，实时展示额度余量与重置倒计时。
- **一键刷新与直达**：点击即可快速触发本地守护进程或 API 配额刷新。

---

## 📦 安装与下载 (Downloads)

前往 [GitHub Releases](https://github.com/seylo-me/Pulse/releases) 页面获取最新安装包：

| 架构版本 | 适用机型 | 下载安装包 |
| :--- | :--- | :--- |
| **Apple Silicon 专属版** | Mac mini / MacBook / iMac (M1, M2, M3, M4 芯片) | `Pulse-v1.5.5-AppleSilicon.dmg` / `.zip` |
| **Intel 专属版** | 搭载 Intel 处理器的老款 Mac 设备 | `Pulse-v1.5.5-Intel.dmg` / `.zip` |
| **Universal 通用版** | 兼容所有 Apple Silicon 芯片 与 Intel 处理器 Mac | `Pulse-v1.5.5-Universal.dmg` / `.zip` |

---

## 🚀 原生架构感知自动更新 (Auto-Updater)
- **开箱即用自动更新**：应用启动时静默检查 GitHub Releases 最新版本，亦可在右键菜单中点击「检查更新...」；
- **智能架构匹配**：自动识别本机芯片架构（Apple Silicon M系列下载 `AppleSilicon.zip`，Intel 下载 `Intel.zip`），兼身体积小、运行快；
- **无缝就地替换与重启**：后台自动下载、解压提取、安全替换 `/Applications/Pulse.app`、清理隔离属性并自动重启；
- **面板右下角版本标识**：浮窗右下角优雅展示当前版本号（如 `v1.5.5`），发现新版时呈现动态更新胶囊。

> **提示**：下载 DMG 后，将 `Pulse.app` 拖入 `Applications` 应用程序文件夹即可。
>
> 💡 **首次启动提示「无法打开，因为无法验证开发者」？**  
> 本项目为开源软件，未绑定每年 $99 的苹果商业企业开发者证书，macOS 会对从网络下载的应用触发 Gatekeeper 拦截：
> 1. **右键打开（推荐）**：在应用程序中，**按住 Control 键鼠标右键点击 `Pulse.app`**，选择 **「打开」**，在弹框中点击 **「仍要打开」** 即可（仅需操作一次，后续双击即可打开）。
> 2. **系统设置放行**：打开 **系统设置 -> 隐私与安全性**，滑到最底部点击 **「仍要打开」**。
> 3. **终端一行命令**：执行 `xattr -cr /Applications/Pulse.app` 即可彻底清除隔离属性。

---

## 🔄 软件更新说明

- **点击版本号直达**：在浮窗左下角直接点击 `v1.5.2 ↗` 徽标，即可一键在浏览器中打开最新 GitHub Releases 发布页面查看更新日志与下载最新包。
- **静默后台检测**：应用支持比对 GitHub Latest Release Tag，若有更新将在版本徽标旁点亮呼吸提示。

---

## 🛠️ 从源码编译 (Build from Source)

### 环境要求
- macOS 13.0 (Ventura) 及以上
- Xcode 15.0+ 或 Command Line Tools (Swift 5.9+)

### 构建步骤
```bash
# 1. 克隆代码仓库
git clone https://github.com/seylo-me/Pulse.git
cd Pulse

# 2. 赋予构建脚本可执行权限并打包
chmod +x build_app.sh
./build_app.sh

# 3. 运行已构建的 App
open dist/Pulse.app
```

`build_app.sh` 脚本将自动完成：
1. 编译 Apple Silicon (`arm64`) 与 Intel (`x86_64`) 二进制切片；
2. 自动通过 `lipo` 合成 Universal 通用应用包；
3. 打包生成独立的 `.dmg` 安装镜像与 `.zip` 压缩包。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 协议开源。
