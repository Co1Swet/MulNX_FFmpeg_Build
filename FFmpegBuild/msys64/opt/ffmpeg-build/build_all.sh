#!/bin/bash
set -euo pipefail

export MSYSTEM=MINGW64
export PATH="/mingw64/bin:/usr/bin:$PATH"

BASE="/opt/ffmpeg-build"
cd "$BASE"

echo "==================================="
echo " 1. 环境检查与自动修复"
echo "==================================="
if ! command -v make &>/dev/null; then
    if [ -f /mingw64/bin/mingw32-make.exe ]; then
        cp /mingw64/bin/mingw32-make.exe /mingw64/bin/make.exe
    else
        pacman -S --noconfirm mingw-w64-x86_64-make
        [ ! -f /mingw64/bin/make.exe ] && cp /mingw64/bin/mingw32-make.exe /mingw64/bin/make.exe
    fi
fi

for pkg in mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-pkg-config mingw-w64-x86_64-nasm mingw-w64-x86_64-lame mingw-w64-x86_64-mpg123 make git diffutils; do
    if ! pacman -Q $pkg &>/dev/null; then
        echo "正在安装 $pkg ..."
        pacman -S --noconfirm $pkg
    fi
done
MINGW_MAKE="/mingw64/bin/make"
MSYS_MAKE="/usr/bin/make"
for tool in gcc g++; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "错误：MinGW 编译器不可用：$tool" >&2
        exit 1
    fi
done
if [ ! -x "$MSYS_MAKE.exe" ]; then
    echo "错误：MSYS make 安装后仍不可用：$MSYS_MAKE" >&2
    exit 1
fi

echo "==================================="
echo " 2. 源码完整性检查"
echo "==================================="
if [ ! -d "$BASE/ffmpegs" ] || [ ! -f "$BASE/ffmpegs/Makefile" ]; then
    echo "错误：ffmpegs 缺失"
    exit 1
fi
if [ ! -d "$BASE/openh264s" ]; then
    echo "错误：openh264s 缺失"
    exit 1
fi
echo "通过"

echo "==================================="
echo " 3. 编译 OpenH264 静态库（带完整的静态依赖声明）"
echo "==================================="
INSTALL_OPENH264="/opt/openh264"
rm -rf "$INSTALL_OPENH264"
mkdir -p "$INSTALL_OPENH264"

cd "$BASE/openh264s"
"$MINGW_MAKE" clean ENABLE64BIT=Yes OS=mingw_nt ARCH=x86_64
"$MINGW_MAKE" ENABLE64BIT=Yes OS=mingw_nt ARCH=x86_64

mkdir -p "$INSTALL_OPENH264/lib/pkgconfig" "$INSTALL_OPENH264/include/wels"
cp libopenh264.a "$INSTALL_OPENH264/lib/"
cp codec/api/wels/*.h "$INSTALL_OPENH264/include/wels/"

# 关键：pkg-config 文件声明 Libs.private 为完整的静态链接参数
cat > "$INSTALL_OPENH264/lib/pkgconfig/openh264.pc" << 'EOF'
prefix=/opt/openh264
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include/wels

Name: OpenH264
Description: Cisco OpenH264 Codec (static)
Version: 2.4.1
Libs: -L${libdir} -lopenh264
Libs.private: -lstdc++ -lgcc -lgcc_eh -lwinpthread
Cflags: -I${includedir}
EOF

# 安装到 mingw64 系统路径
mkdir -p /mingw64/include/wels /mingw64/lib/pkgconfig
cp -r "$INSTALL_OPENH264/include/wels/"* /mingw64/include/wels/
cp "$INSTALL_OPENH264/lib/libopenh264.a" /mingw64/lib/
cp "$INSTALL_OPENH264/lib/pkgconfig/openh264.pc" /mingw64/lib/pkgconfig/

echo "OpenH264 静态库安装完成"
pkg-config --modversion openh264
# 调试：显示 pkg-config 返回的静态链接标志（供检查）
echo "静态链接标志：$(pkg-config --static --libs openh264)"

cd "$BASE"

echo "==================================="
echo " 4. 构建 FFmpeg（源码树外构建）"
echo "==================================="
INSTALL_FFMPEG="$BASE/ffmpeg_install"
BUILD_ROOT="$BASE/build"
BUILD_FFMPEG="$BUILD_ROOT/ffmpeg"
INSTALL_STAGING="$BUILD_ROOT/ffmpeg-install-stage"
SOURCE_FFMPEG="$BASE/ffmpegs"

if [ -L "$BUILD_ROOT" ]; then
    echo "错误：拒绝使用符号链接作为构建目录：$BUILD_ROOT" >&2
    exit 1
fi
mkdir -p "$BUILD_ROOT"
for dir in "$BUILD_FFMPEG" "$INSTALL_STAGING"; do
    case "$dir" in
        "$BUILD_ROOT/ffmpeg"|"$BUILD_ROOT/ffmpeg-install-stage")
            ;;
        *)
            echo "错误：拒绝清理非预期目录：$dir" >&2
            exit 1
            ;;
    esac
    if [ -L "$dir" ]; then
        echo "错误：拒绝清理符号链接：$dir" >&2
        exit 1
    fi
    rm -rf -- "$dir"
    mkdir -p "$dir"
done
cd "$BUILD_FFMPEG"

# 使用 -static 标志强制所有非系统库静态链接
# 无需 --enable-w32threads / --disable-pthreads，因为 -static 会静态链接 pthread 本身
if ! pkg-config --exists "ffnvcodec >= 12.1.14.0"; then
    echo "错误：需要兼容 FFmpeg 的 nv-codec-headers（ffnvcodec >= 12.1.14.0）" >&2
    exit 1
fi

# Keep audio encoding limited to FLAC, MP3, and PCM, alongside the H.264 encoders.
# Include MinGW's CRT directory declarations even when configure misses direct.h.
"$SOURCE_FFMPEG/configure" \
    --prefix="$INSTALL_FFMPEG" \
    --enable-shared --disable-static \
    --disable-doc --disable-programs \
    --enable-avcodec --enable-avformat --enable-avutil \
    --enable-swscale --enable-swresample --enable-avfilter \
    --disable-everything \
    --enable-avdevice --enable-indev=dshow \
    --enable-d3d11va \
    --enable-decoder=h264,flac,mp3,pcm_s16le \
    --enable-encoder=flac,libmp3lame,mp3_mf,pcm_s16le,libopenh264,h264_nvenc,h264_mf \
    --enable-hwaccel=h264_d3d11va,h264_d3d11va2 \
    --enable-demuxer=mov,matroska,flac,mp3,wav \
    --enable-muxer=mp4,mov,matroska,flac,mp3,wav \
    --enable-parser=h264,flac,mpegaudio \
    --enable-protocol=file --disable-protocol=http \
    --enable-filter=scale,format,trim,overlay,apad,atrim,asetpts,aresample,volume,amix,concat,anullsrc,crop,hflip,vflip,transpose,rotate,fps,setpts,setsar,setdar,fade,colorbalance,hue,unsharp,drawbox,tpad,xfade,hwupload,hwdownload,hwmap,scale_d3d11 \
    --enable-libopenh264 --enable-libmp3lame \
    --enable-ffnvcodec --enable-nvenc --enable-mediafoundation \
    --extra-cflags="-include direct.h" \
    --extra-libs="-lmpg123 -lshlwapi" \
    --extra-ldflags="-static" \
    --pkg-config-flags="--static" || {
        echo "===== configure 失败，显示日志尾部 ====="
        tail -80 ffbuild/config.log
        exit 1
    }

EXPECTED_ENCODERS=$(printf '%s\n' \
    CONFIG_FRAME_THREAD_ENCODER \
    CONFIG_FLAC_ENCODER \
    CONFIG_H264_MF_ENCODER \
    CONFIG_H264_NVENC_ENCODER \
    CONFIG_LIBMP3LAME_ENCODER \
    CONFIG_LIBOPENH264_ENCODER \
    CONFIG_MP3_MF_ENCODER \
    CONFIG_PCM_S16LE_ENCODER | sort)
ACTUAL_ENCODERS=$(grep -E '^CONFIG_[A-Z0-9_]+_ENCODER=yes$' ffbuild/config.mak | cut -d= -f1 | sort)
if [ "$ACTUAL_ENCODERS" != "$EXPECTED_ENCODERS" ]; then
    echo "错误：启用的编码器超出 H.264 / FLAC / MP3 / PCM 白名单" >&2
    printf '期望：\n%s\n实际：\n%s\n' "$EXPECTED_ENCODERS" "$ACTUAL_ENCODERS" >&2
    exit 1
fi

for feature in CONFIG_AAC_ENCODER CONFIG_AAC_DECODER CONFIG_AAC_PARSER CONFIG_HEVC_DECODER CONFIG_HEVC_PARSER; do
    if ! grep -q "^#define ${feature} 0$" config_components.h; then
        echo "错误：AAC 编解码或 HEVC 解码/parser 不应启用：$feature" >&2
        exit 1
    fi
done

for feature in \
    CONFIG_H264_DECODER CONFIG_FLAC_DECODER CONFIG_MP3_DECODER CONFIG_PCM_S16LE_DECODER \
    CONFIG_FLAC_DEMUXER CONFIG_MP3_DEMUXER CONFIG_WAV_DEMUXER \
    CONFIG_MOV_DEMUXER CONFIG_MATROSKA_DEMUXER \
    CONFIG_FLAC_MUXER CONFIG_MP3_MUXER CONFIG_WAV_MUXER \
    CONFIG_MOV_MUXER CONFIG_MP4_MUXER CONFIG_MATROSKA_MUXER \
    CONFIG_H264_PARSER CONFIG_FLAC_PARSER CONFIG_MPEGAUDIO_PARSER \
    CONFIG_DSHOW_INDEV CONFIG_H264_D3D11VA_HWACCEL CONFIG_H264_D3D11VA2_HWACCEL; do
    if ! grep -q "^${feature}=yes$" ffbuild/config.mak; then
        echo "错误：预期的编解码/容器/输入组件未启用：$feature" >&2
        tail -80 ffbuild/config.log
        exit 1
    fi
done

for feature in \
    CONFIG_SCALE_FILTER CONFIG_FORMAT_FILTER CONFIG_TRIM_FILTER CONFIG_OVERLAY_FILTER \
    CONFIG_APAD_FILTER CONFIG_ATRIM_FILTER CONFIG_ASETPTS_FILTER \
    CONFIG_ARESAMPLE_FILTER CONFIG_VOLUME_FILTER CONFIG_AMIX_FILTER \
    CONFIG_CONCAT_FILTER CONFIG_ANULLSRC_FILTER \
    CONFIG_HWDOWNLOAD_FILTER CONFIG_HWUPLOAD_FILTER CONFIG_HWMAP_FILTER \
    CONFIG_SCALE_D3D11_FILTER; do
    if ! grep -q "^${feature}=yes$" ffbuild/config.mak; then
        echo "错误：预期的音频编辑滤镜未启用：$feature" >&2
        tail -80 ffbuild/config.log
        exit 1
    fi
done

for feature in \
    CONFIG_CROP_FILTER CONFIG_HFLIP_FILTER CONFIG_VFLIP_FILTER \
    CONFIG_TRANSPOSE_FILTER CONFIG_ROTATE_FILTER CONFIG_FPS_FILTER \
    CONFIG_SETPTS_FILTER CONFIG_SETSAR_FILTER CONFIG_SETDAR_FILTER \
    CONFIG_FADE_FILTER CONFIG_COLORBALANCE_FILTER CONFIG_HUE_FILTER \
    CONFIG_UNSHARP_FILTER CONFIG_DRAWBOX_FILTER CONFIG_TPAD_FILTER \
    CONFIG_XFADE_FILTER; do
    if ! grep -q "^${feature}=yes$" ffbuild/config.mak; then
        echo "错误：预期的视频编辑滤镜未启用：$feature" >&2
        tail -80 ffbuild/config.log
        exit 1
    fi
done

for feature in CONFIG_HTTP_PROTOCOL; do
    if ! grep -q "^#define ${feature} 0$" config_components.h; then
        echo "错误：不需要的 HTTP 协议支持不应启用：$feature" >&2
        exit 1
    fi
done

for feature in \
    CONFIG_LIBOPENH264 CONFIG_H264_NVENC_ENCODER CONFIG_H264_MF_ENCODER \
    CONFIG_LIBMP3LAME; do
    if ! grep -q "^${feature}=yes$" ffbuild/config.mak; then
        echo "错误：FFmpeg 未启用预期编码器/依赖：$feature" >&2
        tail -80 ffbuild/config.log
        exit 1
    fi
done

echo "开始编译 FFmpeg（单线程，输出日志到 build.log）..."
"$MSYS_MAKE" -j1 V=1 2>&1 | tee build.log
"$MSYS_MAKE" DESTDIR="$INSTALL_STAGING" install
STAGED_INSTALL="$INSTALL_STAGING$INSTALL_FFMPEG"

echo ""
echo "==================================="
echo " 5. 最终验证"
echo "==================================="
cd "$STAGED_INSTALL/bin"
shopt -s nullglob
DLLS=( *.dll )
if [ "${#DLLS[@]}" -eq 0 ]; then
    echo "错误：安装暂存目录中没有 FFmpeg DLL" >&2
    exit 1
fi
FAIL=0
for dll in "${DLLS[@]}"; do
    echo -n "检查 $dll ... "
    DEPS=$(ldd "$dll" 2>/dev/null)
    # 检查是否依赖任何 MinGW 运行时 DLL
    if echo "$DEPS" | grep -qE "libwinpthread|libpthread|libstdc\+\+|libgcc_s|libiconv|libz|libopenh264|libmp3lame|libmpg123"; then
        echo "失败！依赖了非系统库："
        echo "$DEPS" | grep -E "lib(winpthread|pthread|stdc\+\+|gcc_s|iconv|z|openh264|mp3lame|mpg123)"
        FAIL=1
    else
        echo "通过"
    fi
done

if [ $FAIL -ne 0 ]; then
    echo ""
    echo "=============================================="
    echo "  验证失败，请查看 build.log 分析链接命令。"
    echo "=============================================="
    exit 1
fi

echo "发布经过验证的 FFmpeg 安装..."
if [ -L "$INSTALL_FFMPEG" ]; then
    echo "错误：拒绝替换符号链接安装目录：$INSTALL_FFMPEG" >&2
    exit 1
fi
BACKUP_INSTALL=""
if [ -e "$INSTALL_FFMPEG" ]; then
    BACKUP_INSTALL=$(mktemp -d "$BUILD_ROOT/ffmpeg-install-backup.XXXXXX")
    rmdir "$BACKUP_INSTALL"
    mv -- "$INSTALL_FFMPEG" "$BACKUP_INSTALL"
fi
if ! cp -a -- "$STAGED_INSTALL" "$INSTALL_FFMPEG"; then
    if [ -e "$INSTALL_FFMPEG" ]; then
        rm -rf -- "$INSTALL_FFMPEG"
    fi
    if [ -n "$BACKUP_INSTALL" ]; then
        mv -- "$BACKUP_INSTALL" "$INSTALL_FFMPEG" || {
            echo "错误：新安装发布失败，旧安装仍保存在：$BACKUP_INSTALL" >&2
            exit 1
        }
    fi
    echo "错误：无法发布 FFmpeg 安装" >&2
    exit 1
fi

cd "$BASE"
echo ""
echo "=============================================="
echo "  构建成功：目标音视频编解码器、容器、滤镜及 D3D11VA/NVENC 支持已启用。"
if [ -n "$BACKUP_INSTALL" ]; then
    echo "  旧产物备份：$BACKUP_INSTALL"
fi
echo "  产物目录：$INSTALL_FFMPEG"
echo "=============================================="
