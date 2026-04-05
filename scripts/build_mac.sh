#!/bin/sh

# 引数のチェック
if [ $# -lt 1 ]; then
    echo "Usage: $0 installdir [builddir] [--debug]"
    echo "  installdir: インストール先ディレクトリ"
    echo "  builddir: ビルド用ディレクトリ (省略時は 'build')"
    echo "  --debug: デバッグビルドを実行 (省略時はリリースビルド)"
    exit 1
fi

SCRIPT_DIR=`dirname $0`
SCRIPT_DIR=`cd ${SCRIPT_DIR} && pwd`
PROJECT_ROOT=`cd ${SCRIPT_DIR}/.. && pwd`

# macOS互換の realpath -m 代替（存在しないパスも解決）
resolve_path() {
    local path="$1"
    case "$path" in
        /*) echo "$path" ;;
        *) echo "$(pwd)/$path" ;;
    esac
}
INSTALL_DIR=$(resolve_path "$1")
BUILD_DIR="${2:-build}"

# macOS 検出
OS=$(uname -s)
if [ "$OS" != "Darwin" ]; then
    echo "このスクリプトはmacOS専用です。Linuxでは scripts/build.sh を使用してください。"
    exit 1
fi

# macOSのCPUコア数取得
NPROC=$(sysctl -n hw.logicalcpu)

# macOSの.NET RID (Runtime Identifier) を CPU アーキテクチャから決定
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DOTNET_RID="osx-arm64"
else
    DOTNET_RID="osx-x64"
fi
echo "macOS アーキテクチャ: ${ARCH}, .NET RID: ${DOTNET_RID}"

# macOS互換の sed -i 関数
sed_inplace() {
    sed -i '' "$@"
}

# wget があればそのまま使い、なければ curl を使う
download() {
    local url="$1"
    local output="$2"
    if command -v wget >/dev/null 2>&1; then
        wget "$url" -O "$output"
    else
        curl -fL "$url" -o "$output"
    fi
}

# .NET 10 SDK 必須チェック
if ! command -v dotnet >/dev/null 2>&1; then
    echo "dotnet コマンドが見つかりません。.NET 10 SDK をインストールしてください。"
    exit 1
fi
if ! dotnet --list-sdks | awk '{print $1}' | grep -Eq '^10\.'; then
    echo ".NET 10 SDK が見つかりません。dotnet --list-sdks を確認してください。"
    exit 1
fi

# デバッグビルドのオプションをチェック
DEBUG_BUILD=false
if [ "$2" = "--debug" ] || [ "$3" = "--debug" ]; then
    DEBUG_BUILD=true
    echo "デバッグビルドモードで実行します"
    if [ "$2" = "--debug" ]; then
        BUILD_DIR="build"
    fi
else
    echo "リリースビルドモードで実行します"
fi

# 依存のみビルドオプション
DEPS_ONLY=false
if [ "$2" = "--deps-only" ] || [ "$3" = "--deps-only" ]; then
    DEPS_ONLY=true
    if [ "$2" = "--deps-only" ]; then
        BUILD_DIR="build"
    fi
fi

# buildディレクトリがない場合は作成
if [ ! -d "${BUILD_DIR}" ]; then
    mkdir "${BUILD_DIR}"
fi

# buildディレクトリに移動
cd "${BUILD_DIR}" || exit 1
BUILD_DIR=`pwd`

# 依存のみビルドして終了
if [ "${DEPS_ONLY}" = "true" ]; then
    echo "依存のみをビルドします (DEST=${INSTALL_DIR})"
    "${SCRIPT_DIR}/build_dep_mac.sh" "${INSTALL_DIR}"
    exit 0
fi

echo "${BUILD_DIR} にインストールを行います。"

# --- 依存ライブラリのビルド ---

# libjpeg-turboのビルド
if [ ! -d "libjpeg-turbo-3.1.0" ]; then
    echo "libjpeg-turbo のビルドを行います。"
    (download https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.0/libjpeg-turbo-3.1.0.tar.gz libjpeg-turbo.tar.gz \
    && tar xf libjpeg-turbo.tar.gz \
    && rm libjpeg-turbo.tar.gz \
    && cd libjpeg-turbo-3.1.0 \
    && cmake -G "Unix Makefiles" -B _build \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=${BUILD_DIR}/baselibs \
      -DENABLE_SHARED=OFF \
      -DENABLE_STATIC=ON \
    && cd _build && make -j${NPROC} \
    && make install) || exit 1
else
    echo "libjpeg-turbo はビルド済みです。スキップします。"
fi

# ----- 地デジ/BS向け ffmpeg_nekopandaのAmatsukazeCLIのビルド -----
# macOS では libmfx/libvpl/cuvid/ffnvcodec は非対応のため無効化
if [ ! -d "build_ffnk" ]; then
    mkdir build_ffnk
fi
cd build_ffnk
if [ ! -d "ffmpeg_nekopanda" ]; then
    echo "ffmpeg (地デジ/BS向け) のビルドを行います。"
    BASELIBS_PKGCFG="${BUILD_DIR}/baselibs/lib/pkgconfig"
    (git clone --depth 1 -b amatsukaze https://github.com/nekopanda/FFmpeg.git ffmpeg_nekopanda \
    && cd ffmpeg_nekopanda \
    && download https://github.com/FFmpeg/FFmpeg/commit/effadce6c756247ea8bae32dc13bb3e6f464f0eb.patch patch0.diff \
    && patch -p1 < patch0.diff \
    && CFLAGS="-w -Wno-error=incompatible-function-pointer-types" PKG_CONFIG_PATH="${BASELIBS_PKGCFG}" ./configure --prefix=`pwd`/build --enable-pic \
      --disable-iconv --disable-xlib --disable-lzma --disable-bzlib \
      --enable-gpl --enable-version3 \
      --disable-autodetect --disable-doc --disable-network --disable-devices \
    && make -j${NPROC} \
    && make install) || exit 1
fi

echo "AmatsukazeCLI (地デジ/BS向け) のビルドを行います。"
FFNK_PKGCFG_PATH="`pwd`/ffmpeg_nekopanda/build/lib/pkgconfig"
BASELIBS_PKGCFG_PATH="${BUILD_DIR}/baselibs/lib/pkgconfig"
(meson setup --buildtype release --pkg-config-path "${FFNK_PKGCFG_PATH}:${BASELIBS_PKGCFG_PATH}" "${SCRIPT_DIR}/.." && ninja) || exit 1
cd ..

# ----- BS4K向け ffmpeg_6.1.2ベースのAmatsukazeCLIのビルド -----
if [ ! -d "build_ff612" ]; then
    mkdir build_ff612
fi
cd build_ff612
if [ ! -d "ffmpeg-6.1.2" ]; then
    echo "ffmpeg (BS4K向け) のビルドを行います。"
    BASELIBS_PKGCFG="${BUILD_DIR}/baselibs/lib/pkgconfig"
    (download https://www.ffmpeg.org/releases/ffmpeg-6.1.2.tar.xz ffmpeg-6.1.2.tar.xz \
    && tar -xf ffmpeg-6.1.2.tar.xz \
    && cd ffmpeg-6.1.2 \
    && CFLAGS="-w -Wno-error=incompatible-function-pointer-types" LDFLAGS="-lc++" PKG_CONFIG_PATH="${BASELIBS_PKGCFG}" ./configure --prefix=`pwd`/build --enable-pic \
      --disable-iconv --disable-xlib --disable-lzma --disable-bzlib \
      --enable-gpl --enable-version3 \
      --disable-autodetect --disable-doc --disable-network --disable-devices \
    && make -j${NPROC} \
    && make install) || exit 1
fi

echo "AmatsukazeCLI (BS4K向け) のビルドを行います。"
FF612_PKGCFG_PATH="`pwd`/ffmpeg-6.1.2/build/lib/pkgconfig"
(meson setup --buildtype release --pkg-config-path "${FF612_PKGCFG_PATH}:${BASELIBS_PKGCFG_PATH}" "${SCRIPT_DIR}/.." && ninja) || exit 1
# macOS では .dylib が生成される
cp Amatsukaze/libAmatsukaze.dylib Amatsukaze/libAmatsukaze2.dylib
cd ..

# dotnet の AmatsukazeServer, AmatsukazeAddTask, AmatsukazeServerCLI のビルド
if [ "$DEBUG_BUILD" = true ]; then
    echo "AmatsukazeServer, AmatsukazeAddTask, AmatsukazeServerCLI のデバッグビルドを行います。"
    cd "${PROJECT_ROOT}" || exit 1
    (dotnet build "${PROJECT_ROOT}/AmatsukazeLinux.sln" -c Debug) || exit 1
else
    echo "AmatsukazeServer, AmatsukazeAddTask, AmatsukazeServerCLI のリリースビルドを行います。"
    cd "${PROJECT_ROOT}" || exit 1
    (dotnet build "${PROJECT_ROOT}/AmatsukazeLinux.sln" -c Release) || exit 1
fi


# ----- インストール -----
mkdir -p "${INSTALL_DIR}/avs"
mkdir -p "${INSTALL_DIR}/avscache"
mkdir -p "${INSTALL_DIR}/bat"
mkdir -p "${INSTALL_DIR}/drcs"
mkdir -p "${INSTALL_DIR}/exe_files"
mkdir -p "${INSTALL_DIR}/exe_files/plugins64"
mkdir -p "${INSTALL_DIR}/logo"
mkdir -p "${INSTALL_DIR}/profile"
mkdir -p "${INSTALL_DIR}/scripts"
touch "${INSTALL_DIR}/drcs/drcs_map.txt"

# 実行ファイルのインストール
echo "実行ファイルをインストールします..."
install -d "${INSTALL_DIR}"
cp ./scripts/AmatsukazeServer.sh "${INSTALL_DIR}/"
install -d "${INSTALL_DIR}/exe_files"
cp "${BUILD_DIR}/build_ffnk/AmatsukazeCLI/AmatsukazeCLI" "${INSTALL_DIR}/exe_files/"
cp "${BUILD_DIR}/build_ffnk/Amatsukaze/libAmatsukaze.dylib" "${INSTALL_DIR}/exe_files/"
cp "${BUILD_DIR}/build_ff612/Amatsukaze/libAmatsukaze2.dylib" "${INSTALL_DIR}/exe_files/"
# macOS では .NET P/Invoke が "libAmatsukaze.so" を探すため、.dylib へのシンボリックリンクを作成する
ln -sf libAmatsukaze.dylib "${INSTALL_DIR}/exe_files/libAmatsukaze.so"
ln -sf libAmatsukaze2.dylib "${INSTALL_DIR}/exe_files/libAmatsukaze2.so"

# .NET アプリケーションの公開
if [ "$DEBUG_BUILD" = true ]; then
    echo ".NET アプリケーションをデバッグモードで公開します..."
    DOTNET_PUBLISH_CONFIG=Debug
else
    echo ".NET アプリケーションをリリースモードで公開します..."
    DOTNET_PUBLISH_CONFIG=Release
fi

DOTNET_PUBLISH_PROJECTS="
AmatsukazeServerCLI/AmatsukazeServerCLI.csproj
AmatsukazeAddTask/AmatsukazeAddTask.csproj
ScriptCommand/ScriptCommand.csproj
"
for project in ${DOTNET_PUBLISH_PROJECTS}; do
    if ! dotnet publish "${project}" -c "${DOTNET_PUBLISH_CONFIG}" -r "${DOTNET_RID}" --self-contained true -p:PublishSingleFile=true -o "${INSTALL_DIR}/exe_files"; then
        echo ".NET アプリケーションの公開に失敗しました (${project})"
        exit 1
    fi
done

# WebUI 静的ファイルの公開
WEBUI_PUBLISH_DIR="${BUILD_DIR}/webui_publish"
echo "WebUI (static) を公開します..."
if ! dotnet publish "AmatsukazeServer/AmatsukazeServer.csproj" -c "${DOTNET_PUBLISH_CONFIG}" -r "${DOTNET_RID}" --self-contained false -p:PublishSingleFile=false -o "${WEBUI_PUBLISH_DIR}"; then
    echo "WebUI の公開に失敗しました"
    exit 1
fi
if [ -d "${WEBUI_PUBLISH_DIR}/wwwroot" ]; then
    rm -rf "${INSTALL_DIR}/exe_files/wwwroot"
    cp -r "${WEBUI_PUBLISH_DIR}/wwwroot" "${INSTALL_DIR}/exe_files/wwwroot"
fi

# defaultファイルのコピー
cp -r defaults/avs/*       "${INSTALL_DIR}/avs/"
cp -r defaults/bat_linux/* "${INSTALL_DIR}/bat/"
cp -r defaults/exe_files/* "${INSTALL_DIR}/exe_files/"
cp -r defaults/profile/*   "${INSTALL_DIR}/profile/"
cp -r scripts/*            "${INSTALL_DIR}/scripts/"

# ラッパースクリプトに実行権限を付与
if [ -d "${INSTALL_DIR}/exe_files/cmd" ]; then
    chmod +x "${INSTALL_DIR}/exe_files/cmd"/* || true
fi

# JLファイルのインストール
if [ ! -d "${INSTALL_DIR}/JL" ]; then
    echo "JLファイルのインストールを開始します..."
    mkdir -p "${INSTALL_DIR}/JL" || exit 1
    download https://github.com/tobitti0/join_logo_scp/archive/refs/tags/Ver4.1.0_Linux.tar.gz Ver4.1.0_Linux.tar.gz || exit 1
    tar -xf Ver4.1.0_Linux.tar.gz || exit 1
    cp -r join_logo_scp-Ver4.1.0_Linux/JL/* "${INSTALL_DIR}/JL/" || exit 1
    rm -rf join_logo_scp-Ver4.1.0_Linux Ver4.1.0_Linux.tar.gz || exit 1
fi

echo "インストールが完了しました (WebUI は REST ポート+1 で公開されます)"
