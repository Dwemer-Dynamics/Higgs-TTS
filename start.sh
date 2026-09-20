#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
cuda_home=$(cat runtime/cuda-home)
case "$cuda_home" in /usr/local/cuda-12.8|/usr/local/cuda-13.0) ;; *) echo 'Invalid installed CUDA path' >&2; exit 1;; esac
export LD_LIBRARY_PATH="/usr/lib/wsl/lib:$cuda_home/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"
# Keep GGUF extraction writable by the service user, separate from other runtimes.
export TMPDIR="$PWD/runtime/tmp"
mkdir -p "$TMPDIR"
exec ./runtime/audiocpp_server --config "$PWD/server.json"
