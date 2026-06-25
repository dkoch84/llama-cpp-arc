#!/usr/bin/env bash
# Build llama.cpp with the SYCL backend for the Intel Arc A750 and place
# llama-server at a predictable path. Upstream is built unmodified at a pinned
# commit. Idempotent: re-run to rebuild / bump the pinned ref.
set -euo pipefail

# --- Pins (verified working on Arc A750, oneAPI 2026.0, Arch) -----------------
# ggml version 0.15.2.
# LLAMA_CPP_REF must be a FULL 40-char SHA: `git fetch` can't resolve a short
# SHA from a remote.
LLAMA_CPP_REPO="https://github.com/ggml-org/llama.cpp.git"
LLAMA_CPP_REF="${LLAMA_CPP_REF:-beac5309f1bc67534f509bf29420abf58fff063c}"
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-$HOME/llama.cpp}"
ONEAPI_SETVARS="${ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}"

# Where the built binary lands (point your serving layer at this path).
EXPECTED_BIN="$LLAMA_CPP_DIR/build/bin/llama-server"

# --- Toolchain ----------------------------------------------------------------
[ -f "$ONEAPI_SETVARS" ] || { echo "missing oneAPI at $ONEAPI_SETVARS (Arch: extra/intel-oneapi-toolkit)" >&2; exit 1; }
# setvars references unbound vars (e.g. OCL_ICD_FILENAMES); relax nounset around it.
set +u; # shellcheck disable=SC1090
source "$ONEAPI_SETVARS" >/dev/null 2>&1 || true; set -u
command -v icpx >/dev/null || { echo "icpx not on PATH after sourcing setvars" >&2; exit 1; }

# --- Fetch source at the pinned commit (shallow) ------------------------------
if [ ! -d "$LLAMA_CPP_DIR/.git" ]; then
  mkdir -p "$LLAMA_CPP_DIR"
  git -C "$LLAMA_CPP_DIR" init -q
  git -C "$LLAMA_CPP_DIR" remote add origin "$LLAMA_CPP_REPO"
fi
echo ">> fetching $LLAMA_CPP_REF"
git -C "$LLAMA_CPP_DIR" fetch --depth 1 origin "$LLAMA_CPP_REF"
git -C "$LLAMA_CPP_DIR" checkout -q FETCH_HEAD

# --- Configure + build --------------------------------------------------------
echo ">> configuring SYCL build"
cmake -S "$LLAMA_CPP_DIR" -B "$LLAMA_CPP_DIR/build" \
  -DGGML_SYCL=ON \
  -DCMAKE_C_COMPILER=icx \
  -DCMAKE_CXX_COMPILER=icpx \
  -DCMAKE_BUILD_TYPE=Release

echo ">> building llama-server (-j$(nproc))"
cmake --build "$LLAMA_CPP_DIR/build" --config Release -j"$(nproc)" --target llama-server

# --- Verify -------------------------------------------------------------------
[ -x "$EXPECTED_BIN" ] || { echo "build finished but $EXPECTED_BIN missing" >&2; exit 1; }
echo ">> built: $EXPECTED_BIN"
"$EXPECTED_BIN" --version 2>&1 | head -3 || true

cat <<EOF

Done. llama-server is in place:
  $EXPECTED_BIN
Point your serving layer at it (restart it if it caches the binary path).
EOF
