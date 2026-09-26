# MulNX_FFmpeg_Build

> **MulNX_CS2 的 FFmpeg 依赖构建专用仓库**

本仓库是 [MulNX_CS2](https://github.com/Co1Swet/MulNX_CS2) 的配套仓库，专门用于存放该项目所依赖的 FFmpeg 构建环境、编译产物及完整工具链快照。

---

## ⚠️ 重要声明

**本仓库主要用于展示与合规存档，并非一个常规的、接受外部贡献的开源协作项目。**

- 本仓库**不建议直接提交 Pull Request**。
- 如果你有任何问题、建议或希望贡献代码，**请先通过 Issue 或直接联系作者**，征得同意后再进行操作。
- 未经沟通的 PR 可能会被直接关闭，因为本仓库的内容是特定环境的完整快照，随意修改可能破坏其可复现性与合规完整性。
- 如果你想基于本仓库进行自定义构建，欢迎 **Fork 到你自己的账号下** 任意修改，但请不要向本仓库发起 PR。

感谢理解与配合。

---

## 📌 为什么单独建立这个仓库？

### 1. 开源合规性（Open Source Compliance）

本项目严格遵守所依赖的开源软件许可证。FFmpeg 及其构建过程中涉及的第三方库（如 MSYS2 环境下的各类 `pacman` 包）均受各自的开源许可证约束。

本仓库完整保留了：

- FFmpeg 构建所需的完整 MSYS2 环境快照（`FFmpegBuild/msys64`）
- 构建过程中下载和安装的所有第三方依赖包及其元数据（`pacman` 包数据库、`.pkg.tar.zst` 缓存、`.sig` 签名文件）
- 构建日志（`pacman.log`）及许可证文件

将这部分内容独立存放，能够确保主仓库 [MulNX_CS2](https://github.com/Co1Swet/MulNX_CS2) 的许可证声明与依赖来源清晰可追溯，便于审计和合规检查。

### 2. 用户自定制性（User Customization）

不同的用户、不同的编译目标、不同的 Windows 环境，往往需要不同的 FFmpeg 编译参数和依赖组合。

本仓库提供了一个**开箱即用的完整构建环境快照**，用户可以：

- 直接复用本仓库中的 MSYS2 工具链，无需从零配置编译环境
- 根据自己的需求修改 FFmpeg 的 `configure` 参数、启用/禁用特定的编解码器
- 替换或升级 `msys64` 中的特定依赖包，自行重新构建
- 参考本仓库的依赖清单，快速定位缺失的库或工具

### 3. 防止主仓库过大（Keep the Main Repository Lean）

FFmpeg 的完整构建环境包含数万个文件（近 3 万个散碎文件，总体积超过 400MB），其中包括：

- 编译器工具链（GCC、binutils、nasm 等）
- 各类第三方库及其头文件
- 包管理器的缓存与数据库
- 时区、证书等系统级配置

如果将这些内容直接塞进主仓库 [MulNX_CS2](https://github.com/Co1Swet/MulNX_CS2)：

- 主仓库的体积会急剧膨胀，克隆和拉取速度大幅下降
- 日常的 `git add .`、`git commit` 会变得异常缓慢
- 推送时极易因文件数量过多触发 GitHub 的 HTTP 502 / 408 超时错误

因此，我们将构建环境剥离到本仓库，主仓库只需专注于源代码和核心逻辑，保持轻量与高效。

---

## 📁 仓库内容说明

| 路径 | 说明 |
| ------ | ------ |
| `FFmpegBuild/msys64/` | 完整的 MSYS2 构建环境快照，含工具链、依赖库、头文件等 |
| `FFmpegBuild/msys64/var/cache/pacman/pkg/` | 构建过程中下载的第三方依赖包缓存（`.pkg.tar.zst`）及签名 |
| `FFmpegBuild/msys64/var/lib/pacman/` | 包管理器数据库，记录所有已安装依赖的版本与元数据 |
| `FFmpegBuild/msys64/var/log/pacman.log` | 完整的包安装与构建日志 |

---

## 📜 许可证与合规声明

本仓库中包含的第三方组件（如 MSYS2 工具链、FFmpeg、各类 `pacman` 包）**均遵循其各自的开源许可证**。

- FFmpeg 本身遵循 LGPL / GPL 许可证（具体取决于编译配置）
- MSYS2 及其包管理器遵循相关开源协议
- 各第三方依赖包遵循其 `desc` 文件中声明的许可证

本仓库作为 [MulNX_CS2](https://github.com/Co1Swet/MulNX_CS2) 的依赖快照仓库，**同步包含了主仓库的快照许可证信息**，以确保在分发、修改和再构建过程中，所有上游许可证要求均被满足。

> ⚠️ **注意**：如果您计划将本仓库中的构建产物用于商业分发，请务必逐一核对 `FFmpegBuild/msys64/var/lib/pacman/local/*/desc` 中记录的许可证信息，确保符合您的使用场景。

---

## 🔗 相关仓库

- **主项目**：[MulNX_CS2](https://github.com/Co1Swet/MulNX_CS2)
- **本仓库（依赖构建）**：[MulNX_FFmpeg_Build](https://github.com/Co1Swet/MulNX_FFmpeg_Build)

---

## 🤝 反馈与联系

**再次强调：本仓库不建议直接提交 Pull Request。**

- 如有任何疑问、建议或希望贡献内容，请先通过 [Issues](https://github.com/Co1Swet/MulNX_FFmpeg_Build/issues) 发起讨论，或直接联系作者 [@Co1Swet](https://github.com/Co1Swet)。
- 未经沟通的 PR 可能会被关闭，敬请谅解。

---

*本仓库为 MulNX 项目组维护，用于 FFmpeg 依赖构建与合规存档，主要供展示与参考。*
