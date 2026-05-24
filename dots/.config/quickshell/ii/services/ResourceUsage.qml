pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats

    property real gpuUsage: 0
    property real gpuMemoryUsed: 0
    property real gpuMemoryTotal: 1
    property real gpuMemoryUsedPercentage: gpuMemoryTotal > 0 ? (gpuMemoryUsed / gpuMemoryTotal) : 0
    property string gpuName: "GPU"
    property bool gpuAvailable: false
    property string maxAvailableGpuString: "--"
    property string maxAvailableGpuMemString: "--"

    property string gpuBusyFilePath: ""
    property string gpuMemUsedFilePath: ""
    property string gpuMemTotalFilePath: ""


    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []
    property list<real> gpuUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateGpuUsageHistory() {
        gpuUsageHistory = [...gpuUsageHistory, gpuUsage]
        if (gpuUsageHistory.length > historyLength) {
            gpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateGpuUsageHistory()
    }

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            if (gpuBusyFilePath) fileGpuBusy.reload()
            if (gpuMemUsedFilePath) fileGpuMemUsed.reload()
            if (gpuMemTotalFilePath) fileGpuMemTotal.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Parse GPU usage
            if (gpuBusyFilePath) {
                const gpuText = fileGpuBusy.text().trim()
                const gpuVal = Number(gpuText)
                if (!isNaN(gpuVal)) {
                    gpuUsage = gpuVal / 100.0
                    gpuAvailable = true
                }
            }

            // Parse GPU VRAM
            if (gpuMemUsedFilePath && gpuMemTotalFilePath) {
                const memUsedText = fileGpuMemUsed.text().trim()
                const memTotalText = fileGpuMemTotal.text().trim()
                const used = Number(memUsedText)
                const total = Number(memTotalText)
                if (!isNaN(used) && !isNaN(total) && total > 0) {
                    gpuMemoryUsed = used / 1024  // bytes to KB
                    gpuMemoryTotal = total / 1024
                }
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileGpuBusy; path: root.gpuBusyFilePath }
    FileView { id: fileGpuMemUsed; path: root.gpuMemUsedFilePath }
    FileView { id: fileGpuMemTotal; path: root.gpuMemTotalFilePath }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    Process {
        id: detectGpuProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", Directories.scriptPath + "/detect_gpu.sh"]
        running: true
        stdout: StdioCollector {
            id: gpuDetectCollector
            onStreamFinished: {
                const text = gpuDetectCollector.text
                const busyMatch = text.match(/BUSY:(.+)/)
                const memUsedMatch = text.match(/MEMUSED:(.+)/)
                const memTotalMatch = text.match(/MEMTOTAL:(.+)/)
                const nameMatch = text.match(/NAME:(.+)/)
                if (busyMatch) {
                    root.gpuBusyFilePath = busyMatch[1].trim()
                    root.gpuAvailable = true
                }
                if (memUsedMatch) root.gpuMemUsedFilePath = memUsedMatch[1].trim()
                if (memTotalMatch) root.gpuMemTotalFilePath = memTotalMatch[1].trim()
                if (nameMatch) root.gpuName = nameMatch[1].trim()
                if (root.gpuMemTotalFilePath) {
                    root.maxAvailableGpuMemString = (root.gpuMemoryTotal / (1024 * 1024)).toFixed(1) + " GB"
                }
            }
        }
    }
}
