# llama-cpp-arc

Reproducible build of [llama.cpp](https://github.com/ggml-org/llama.cpp)'s
`llama-server` with the **SYCL backend**, targeting the **Intel Arc A750**
(Alchemist / DG2). Upstream is built unmodified at a pinned commit — this repo
is just the build recipe, so the binary can be recreated identically.

## Prerequisites

- Intel oneAPI Base Toolkit at `/opt/intel/oneapi/` (provides `icx` / `icpx`)
- `level-zero-loader` + `intel-compute-runtime` — the Arc GPU must appear under
  `sycl-ls` as a `level_zero:gpu` device
- `cmake`, `git`

## Build

```bash
./build.sh
```

Idempotent. Fetches llama.cpp at the pinned ref into `$LLAMA_CPP_DIR`
(default `~/llama.cpp`), configures the SYCL backend with `icx`/`icpx`, builds
`llama-server`, and verifies the binary at `$LLAMA_CPP_DIR/build/bin/llama-server`.

Override via env: `LLAMA_CPP_REF`, `LLAMA_CPP_DIR`, `ONEAPI_SETVARS`.

## Pinned version

- `LLAMA_CPP_REF=beac5309f1bc67534f509bf29420abf58fff063c` (beac530) — ggml 0.15.2
- Verified with Intel oneAPI DPC++/C++ Compiler 2026.0.0 on Arch Linux, Arc A750 (level-zero)

Bump `LLAMA_CPP_REF` in `build.sh` to move forward. Keep it a full 40-char SHA —
`git fetch` can't resolve a short SHA from a remote — so rebuilds stay reproducible.

## Notes

- `setvars.sh` references unbound shell vars, so `build.sh` relaxes `set -u`
  only around sourcing it.
- Runtime flags (context size, flash-attn, quantization) are intentionally not
  baked in here — this repo builds the engine; how it's launched is left to
  whatever serves the models.
