#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPS_DIR="$ROOT_DIR/.deps"
WHISPER_DIR="$DEPS_DIR/whisper.cpp"
RESOURCE_DIR="$ROOT_DIR/Sources/VoiceTyper/Resources"
BIN_DIR="$RESOURCE_DIR/bin"
LIB_DIR="$RESOURCE_DIR/lib"
MODEL_DIR="$RESOURCE_DIR/Models"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"

mkdir -p "$DEPS_DIR" "$BIN_DIR" "$LIB_DIR" "$MODEL_DIR"

if [ ! -d "$WHISPER_DIR/.git" ]; then
    git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
else
    git -C "$WHISPER_DIR" pull --ff-only
fi

if command -v cmake >/dev/null 2>&1; then
    cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
    cmake --build "$WHISPER_DIR/build" --config Release -j
    cp "$WHISPER_DIR/build/bin/whisper-cli" "$BIN_DIR/whisper-cli"
else
    echo "cmake is required to build current whisper.cpp. Install it with: brew install cmake" >&2
    exit 1
fi

chmod +x "$BIN_DIR/whisper-cli"

find "$WHISPER_DIR/build" -name '*.dylib' -exec cp -P {} "$LIB_DIR/" \;

if command -v install_name_tool >/dev/null 2>&1; then
    while IFS= read -r rpath; do
        install_name_tool -delete_rpath "$rpath" "$BIN_DIR/whisper-cli" 2>/dev/null || true
    done < <(otool -l "$BIN_DIR/whisper-cli" | awk '/LC_RPATH/{getline; getline; print $2}')
    install_name_tool -add_rpath "@executable_path/../lib" "$BIN_DIR/whisper-cli" 2>/dev/null || true
fi

if [ ! -f "$MODEL_DIR/ggml-base.bin" ]; then
    curl -L "$MODEL_URL" -o "$MODEL_DIR/ggml-base.bin"
fi

echo "Whisper resources are ready:"
echo "$BIN_DIR/whisper-cli"
echo "$LIB_DIR"
echo "$MODEL_DIR/ggml-base.bin"
