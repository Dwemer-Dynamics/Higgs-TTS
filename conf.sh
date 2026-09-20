#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
echo 'Higgs TTS 3: 1 Enable startup, 2 Start, 3 Stop and free GPU memory, 4 Change model (stop Higgs first), 0 Disable'
read -r -p 'Select: ' choice
case "$choice" in
    1) ./service.sh enable ;;
    2) sudo ./service.sh start ;;
    3) sudo ./service.sh stop ;;
    4) bash ./install.sh ask ;;
    0) sudo ./service.sh disable ;;
    *) echo 'No changes made.' ;;
esac
