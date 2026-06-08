pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.utils

Singleton {
    id: root

    property bool authenticated: false
    property bool loading: false
    property var events: []
    property string errorType: ""
    property string statusMessage: ""

    readonly property string gcalScriptPath: Quickshell.shellPath("services/gCloud/gcal-sync-venv.sh")
    property var notifiedEvents: ({})

    signal eventsLoaded()
    signal operationCompleted(bool success, string message)

    function checkAuthAndLoadEvents(startDate, endDate) {
        loading = true;
        errorType = "";
        
        var startArg = startDate ? startDate : "";
        var endArg = endDate ? endDate : "";
        
        var cmd = [gcalScriptPath, "list"];
        if (startArg) {
            cmd.push("--start", startArg);
        }
        if (endArg) {
            cmd.push("--end", endArg);
        }

        var seq = [
            cmd,
            (out) => {
                loading = false;
                try {
                    var data = JSON.parse(out);
                    if (data.status === "success") {
                        root.events = data.events;
                        root.authenticated = true;
                        root.errorType = "";
                        root.eventsLoaded();
                    } else if (data.status === "error") {
                        root.authenticated = false;
                        root.errorType = data.error_type;
                        root.statusMessage = data.message;
                        root.events = [];
                    }
                } catch(e) {
                    root.authenticated = false;
                    root.errorType = "parse_error";
                    root.statusMessage = "Error parsing script output: " + e + "\n" + out;
                    root.events = [];
                }
            }
        ];
        gcalProc.runSequence(seq);
    }

    function authenticate() {
        loading = true;
        var seq = [
            [gcalScriptPath, "auth"],
            (out) => {
                loading = false;
                try {
                    var data = JSON.parse(out);
                    if (data.status === "success") {
                        root.authenticated = true;
                        root.errorType = "";
                        root.statusMessage = data.message;
                        root.operationCompleted(true, "Autenticado con éxito.");
                        // Reload events
                        checkAuthAndLoadEvents();
                    } else {
                        root.authenticated = false;
                        root.errorType = data.error_type || "auth_failed";
                        root.statusMessage = data.message;
                        root.operationCompleted(false, data.message);
                    }
                } catch(e) {
                    root.authenticated = false;
                    root.errorType = "parse_error";
                    root.statusMessage = "Error: " + e;
                    root.operationCompleted(false, "Error: " + e);
                }
            }
        ];
        gcalProc.runSequence(seq);
    }

    function createEvent(summary, start, end, description, allDay, timezone) {
        loading = true;
        var cmd = [gcalScriptPath, "create", "--summary", summary, "--start", start, "--end", end];
        if (description) {
            cmd.push("--description", description);
        }
        if (allDay) {
            cmd.push("--all-day");
        }
        if (timezone) {
            cmd.push("--timezone", timezone);
        }

        var seq = [
            cmd,
            (out) => {
                loading = false;
                try {
                    var data = JSON.parse(out);
                    if (data.status === "success") {
                        root.operationCompleted(true, "Evento creado con éxito.");
                        // Reload events
                        checkAuthAndLoadEvents();
                    } else {
                        root.operationCompleted(false, data.message);
                    }
                } catch(e) {
                    root.operationCompleted(false, "Error: " + e);
                }
            }
        ];
        gcalProc.runSequence(seq);
    }

    function updateEvent(eventId, summary, start, end, description, allDay, timezone) {
        loading = true;
        var cmd = [gcalScriptPath, "update", "--id", eventId];
        if (summary !== undefined) {
            cmd.push("--summary", summary);
        }
        if (start) {
            cmd.push("--start", start);
        }
        if (end) {
            cmd.push("--end", end);
        }
        if (description !== undefined) {
            cmd.push("--description", description);
        }
        if (allDay) {
            cmd.push("--all-day");
        }
        if (timezone) {
            cmd.push("--timezone", timezone);
        }

        var seq = [
            cmd,
            (out) => {
                loading = false;
                try {
                    var data = JSON.parse(out);
                    if (data.status === "success") {
                        root.operationCompleted(true, "Evento actualizado con éxito.");
                        checkAuthAndLoadEvents();
                    } else {
                        root.operationCompleted(false, data.message);
                    }
                } catch(e) {
                    root.operationCompleted(false, "Error: " + e);
                }
            }
        ];
        gcalProc.runSequence(seq);
    }

    function deleteEvent(eventId) {
        loading = true;
        var seq = [
            [gcalScriptPath, "delete", "--id", eventId],
            (out) => {
                loading = false;
                try {
                    var data = JSON.parse(out);
                    if (data.status === "success") {
                        root.operationCompleted(true, "Evento eliminado con éxito.");
                        checkAuthAndLoadEvents();
                    } else {
                        root.operationCompleted(false, data.message);
                    }
                } catch(e) {
                    root.operationCompleted(false, "Error: " + e);
                }
            }
        ];
        gcalProc.runSequence(seq);
    }

    MultiTurnProcess {
        id: gcalProc
    }

    Component.onCompleted: {
        // Initial load of events
        checkAuthAndLoadEvents();
    }

    Timer {
        id: refreshTimer
        interval: 15 * 60 * 1000 // every 15 minutes
        running: authenticated
        repeat: true
        onTriggered: checkAuthAndLoadEvents()
    }

    Timer {
        id: notificationCheckTimer
        interval: 60 * 1000 // every 1 minute
        running: authenticated && events.length > 0
        repeat: true
        onTriggered: {
            var now = new Date();
            var tenMinutesFromNow = new Date(now.getTime() + 10 * 60 * 1000);
            
            for (var i = 0; i < events.length; i++) {
                var e = events[i];
                if (!e.start || e.isAllDay) continue;
                
                var eventStart = new Date(e.start);
                // If the event starts in the next 10 minutes (and is in the future)
                if (eventStart > now && eventStart <= tenMinutesFromNow) {
                    if (!notifiedEvents[e.id]) {
                        notifiedEvents[e.id] = true;
                        root.notifiedEvents = Object.assign({}, notifiedEvents);
                        
                        var timeStr = eventStart.toLocaleTimeString(Qt.locale(), "HH:mm");
                        var title = "Recordatorio: " + e.summary;
                        var body = "Comienza a las " + timeStr + (e.description ? ("\n" + e.description) : "");
                        Quickshell.execDetached(["notify-send", title, body, "-a", "Google Calendar", "-i", "calendar_month"]);
                    }
                }
            }
        }
    }
}
