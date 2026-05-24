pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Currently only supports Arch.
 */
Singleton {
    id: root

    property bool available: false
    property alias checking: checkUpdatesProc.running
    property int pacmanCount: 0
    property int aurCount: 0
    property int flatpakCount: 0
    property int count: pacmanCount + aurCount + flatpakCount
    
    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Process {
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["which", "checkupdates"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            root.refresh();
        }
    }

    Process {
        id: checkUpdatesProc
        command: ["/home/juandiego/.config/hypr/hyprland/scripts/check_all_updates.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 3) {
                    root.pacmanCount = parseInt(parts[0]) || 0;
                    root.aurCount = parseInt(parts[1]) || 0;
                    root.flatpakCount = parseInt(parts[2]) || 0;
                } else {
                    root.pacmanCount = parseInt(text.trim()) || 0;
                    root.aurCount = 0;
                    root.flatpakCount = 0;
                }
            }
        }
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh();
        }

        function clear(): void {
            root.pacmanCount = 0;
            root.aurCount = 0;
            root.flatpakCount = 0;
        }
    }
}
