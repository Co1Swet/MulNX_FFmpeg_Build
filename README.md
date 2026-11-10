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

### 构建方式

在 MSYS2 `MINGW64` 环境中运行 `FFmpegBuild/msys64/opt/ffmpeg-build/build_all.sh`。FFmpeg 会在源码树外的 `opt/ffmpeg-build/build/ffmpeg/` 配置和编译。编码器白名单包含 H.264（NVENC、Media Foundation、OpenH264）、FLAC、MP3（`libmp3lame` 与 Media Foundation）和 `pcm_s16le`；脚本会检查没有其他编码器被启用。容器层启用 MP4/MOV（`mov` demuxer、`mp4`/`mov` muxer）与 Matroska/MKV 的读取和写出，并保留 FLAC、MP3、WAV 的读写支持。这里只启用本构建所选编码格式的容器读写能力，不代表支持容器中所有可能的编码格式；可解码的流仍受本构建启用的解码器限制。AAC 编码器、解码器和 parser 均保持禁用；HEVC 解码器及 parser 也禁用，所以含 AAC 或 HEVC 的文件不能保证完整解码处理。HTTP 协议已关闭，仅保留本地文件协议。DirectShow 输入通过 `avdevice` 库启用；由于 `--disable-programs`，构建只输出 FFmpeg 库，不生成 `ffmpeg.exe` / `ffprobe.exe`。MP3 的 LAME 开发库由构建脚本通过 MSYS2 安装；Media Foundation MP3 编码器则依赖运行 Windows 上可用的兼容 MFT，`libmp3lame` 可作为稳定替代。

音频处理启用 `apad`（补静音）、`atrim`（裁剪）、`asetpts`（重建时间戳）、`aresample`（重采样）、`volume`（音量调整）、`amix`（混音）、`concat`（拼接）和 `anullsrc`（生成静音源）滤镜。轻中度视频编辑启用缩放/格式转换、裁剪、水平/垂直翻转、旋转/转置、帧率和时间戳调整、宽高比设置、淡入淡出、色彩平衡/色相、锐化、画框、补帧及交叉淡化（`scale`、`format`、`crop`、`hflip`、`vflip`、`transpose`、`rotate`、`fps`、`setpts`、`setsar`、`setdar`、`fade`、`colorbalance`、`hue`、`unsharp`、`drawbox`、`tpad`、`xfade`）。未启用依赖 GPL 的 `eq` 滤镜，也未启用需要额外字体库的 `drawtext`。安装产物会先暂存并验证，成功后再更新到 `opt/ffmpeg-build/ffmpeg_install/`。已有安装会保留在 `opt/ffmpeg-build/build/ffmpeg-install-backup*` 中以便回退。

H.264 D3D11VA 与 NVENC 支持均启用。除旧式 `h264_d3d11va` 外，也启用 `h264_d3d11va2` 帧上下文模式：它可提供 `AV_PIX_FMT_D3D11` 帧，供 NVENC 直接消费；只有解码与编码共用兼容 D3D11 设备/帧上下文时，才能实现无系统内存往返的路径。`hwupload`、`hwdownload`、`hwmap` 以及 `scale_d3d11` 也已启用：`hwdownload` 会发生 GPU 到 CPU 拷贝，不能用于零拷贝路径；`hwmap` 用于支持的硬件帧映射，`scale_d3d11` 可在 D3D11 设备上缩放。其他通用视频滤镜多为软件滤镜，使用它们可能需要硬件帧下载/上传，需结合实际滤镜链验证是否保持零拷贝。构建脚本会检查 D3D11VA2 hwaccel 是否启用。MSYS2 的 LAME 4 静态库还依赖 `mpg123`/`shlwapi`；构建会将这些依赖静态链接，并在 DLL 依赖检查中确认未泄漏为运行时 DLL。

音频格式选择以减少已知专利负担为目标：FLAC 是无损格式，MP3 主要相关专利的授权项目已于 2017 年终止；这不构成法律意见或对任何地区、实现及第三方权利的绝对保证。分发前仍应核查具体依赖的许可证和适用法律。

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
