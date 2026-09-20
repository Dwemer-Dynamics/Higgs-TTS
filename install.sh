#!/bin/bash
# Install locally without enabling the service or changing any mod connector.
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
if [ "$(id -u)" -eq 0 ]; then
    echo 'Run this installer as dwemer after installing distro CUDA dependencies.' >&2
    exit 1
fi
exec 9>.install.lock
flock -n 9 || { echo 'Another Higgs installation is running.' >&2; exit 1; }
if [ -f server.pid ] && start-stop-daemon --status --pidfile "$PWD/server.pid" >/dev/null; then
    echo 'Stop Higgs before reinstalling. Existing runtime was preserved.' >&2
    exit 1
fi
variant=$(python3 download_model.py --select "${1:-keep}")
selection=/var/lib/dwemerdistro/cuda-selection.env
if [ ! -r "$selection" ] || [ "$(stat -c '%U:%G' "$selection")" != root:root ]; then
    echo 'Run the DwemerDistro CUDA dependency installer first.' >&2
    exit 1
fi
cuda_home=$(sed -n 's/^CUDA_HOME=//p' "$selection" | head -1)
capability=$(sed -n 's/^CUDA_COMPUTE_CAPABILITY=//p' "$selection" | head -1)
case "$cuda_home" in /usr/local/cuda-12.8|/usr/local/cuda-13.0) ;; *) echo 'Unsupported CUDA selection' >&2; exit 1;; esac
[[ "$capability" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo 'Invalid GPU architecture' >&2; exit 1; }
export PATH="$cuda_home/bin:$PATH"
revision=$(python3 -c 'import json; print(json.load(open("runtime.json"))["commit"])')
source_url=$(python3 -c 'import json; print(json.load(open("runtime.json"))["source"])')
mkdir -p runtime models voices
source_dir="$PWD/runtime/source-$revision"
if [ ! -d "$source_dir/.git" ]; then
    git init "$source_dir"
    git -C "$source_dir" remote add origin "$source_url"
fi
if ! git -C "$source_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$source_dir" fetch --depth 1 origin "$revision"
    git -C "$source_dir" checkout --detach FETCH_HEAD
fi
[ "$(git -C "$source_dir" rev-parse HEAD)" = "$revision" ] || { echo 'Runtime revision mismatch' >&2; exit 1; }
cmake -S "$source_dir" -B "$source_dir/build" -DCMAKE_BUILD_TYPE=Release \
    -DENGINE_ENABLE_CUDA=ON -DCUDAToolkit_ROOT="$cuda_home" \
    -DCMAKE_CUDA_COMPILER="$cuda_home/bin/nvcc" -DCMAKE_CUDA_ARCHITECTURES="${capability/./}" \
    -DAUDIOCPP_MODEL_SET=custom -DAUDIOCPP_MODELS=higgs_audio_tts -DAUDIOCPP_DEPLOYMENT_BUILD=ON
cmake --build "$source_dir/build" --parallel "${BUILD_PARALLEL:-2}" --target audiocpp_server
python3 download_model.py "$variant"
ln -sfn "source-$revision/build/bin/audiocpp_server" runtime/audiocpp_server.new
mv -Tf runtime/audiocpp_server.new runtime/audiocpp_server
printf '%s\n' "$cuda_home" > runtime/cuda-home
echo 'Higgs installed. Enable it in service controls, then select it in your mod server.'
