#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
echo 'Higgs TTS 3: 1 Enable startup, 2 Start, 3 Stop and free GPU memory, 4 Change model (stop Higgs first), 0 Disable'
read -r -p 'Select: ' choice
case "$choice" in
    1)
        if [ "$(id -u)" -eq 0 ]; then
            runuser -u dwemer -- ./service.sh enable
        else
            ./service.sh enable
        fi
        ;;
    2|3|0)
        case "$choice" in
            2) action=start ;;
            3) action=stop ;;
            0) action=disable ;;
        esac
        if [ "$(id -u)" -eq 0 ]; then
            ./service.sh "$action"
        else
            # Older launchers must fail promptly rather than ask for a Linux password.
            sudo -n ./service.sh "$action" || {
                echo 'Unable to control Higgs. Use an updated DwemerDistro launcher and check the service error above.' >&2
                exit 1
            }
        fi
        ;;
    4)
        if [ "$(id -u)" -eq 0 ]; then
            runuser -u dwemer -- bash ./install.sh ask
        else
            bash ./install.sh ask
        fi
        ;;
    *) echo 'No changes made.' ;;
esac
