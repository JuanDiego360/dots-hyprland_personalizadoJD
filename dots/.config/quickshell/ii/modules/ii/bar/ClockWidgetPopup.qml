import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.sidebarRight.calendar

StyledPopup {
    id: root
    property string formattedDate: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM dd, yyyy")
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    property string todosSection: getUpcomingTodos()

    onActiveChanged: {
        if (active) {
            GlobalStates.selectedCalendarDate = new Date();
        }
    }

    function getUpcomingTodos() {
        const unfinishedTodos = Todo.list.filter(function (item) {
            return !item.done;
        });
        if (unfinishedTodos.length === 0) {
            return Translation.tr("No pending tasks");
        }

        // Limit to first 5 todos to keep popup manageable
        const limitedTodos = unfinishedTodos.slice(0, 5);
        let todoText = limitedTodos.map(function (item, index) {
            return `  ${index + 1}. ${item.content}`;
        }).join('\n');

        if (unfinishedTodos.length > 5) {
            todoText += `\n  ${Translation.tr("... and %1 more").arg(unfinishedTodos.length - 5)}`;
        }

        return todoText;
    }

    function getEventsForDate(date) {
        if (!GoogleCalendar.authenticated || !date) return [];
        
        var targetYear = date.getFullYear();
        var targetMonth = date.getMonth();
        var targetDay = date.getDate();
        var targetDateStr = targetYear + "-" + (targetMonth + 1).toString().padStart(2, '0') + "-" + targetDay.toString().padStart(2, '0');
        var targetTime = new Date(targetYear, targetMonth, targetDay).getTime();
        
        return GoogleCalendar.events.filter(function(e) {
            if (!e.start || !e.end) return false;
            
            if (e.isAllDay) {
                var startTime = new Date(e.start + "T00:00:00").getTime();
                var endTime = new Date(e.end + "T00:00:00").getTime();
                return (targetTime >= startTime && targetTime < endTime);
            } else {
                var eventStartDateStr = e.start.substring(0, 10);
                var eventEndDateStr = e.end.substring(0, 10);
                var eventStartTime = new Date(eventStartDateStr + "T00:00:00").getTime();
                var eventEndTime = new Date(eventEndDateStr + "T00:00:00").getTime();
                return (targetTime >= eventStartTime && targetTime <= eventEndTime);
            }
        });
    }

    function getEventsText(date) {
        var dayEvents = getEventsForDate(date);
        if (dayEvents.length === 0) {
            return "  " + Translation.tr("No events");
        }
        
        return dayEvents.map(function (item) {
            var timeStr = "";
            if (item.isAllDay) {
                timeStr = "[Todo el día] ";
            } else {
                var eventStart = new Date(item.start);
                timeStr = "[" + eventStart.toLocaleTimeString(Qt.locale(), "HH:mm") + "] ";
            }
            return "  • " + timeStr + item.summary;
        }).join('\n');
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

        StyledPopupHeaderRow {
            icon: "calendar_month"
            label: root.formattedDate
        }

        StyledPopupValueRow {
            icon: "timelapse"
            label: Translation.tr("System uptime:")
            value: root.formattedUptime
        }

        Rectangle {
            height: 1
            color: Appearance.colors.colOutlineVariant
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        CalendarWidget {
            id: calendarWidget
            Layout.alignment: Qt.AlignHCenter
            openDialogOnClick: false
        }

        Rectangle {
            height: 1
            color: Appearance.colors.colOutlineVariant
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        // Events
        Column {
            spacing: 0
            Layout.fillWidth: true

            StyledPopupValueRow {
                icon: "event"
                label: "Eventos (" + Qt.locale().toString(GlobalStates.selectedCalendarDate, "dd/MM") + "):"
                value: ""
            }

            StyledText {
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSurfaceVariant
                text: GoogleCalendar.authenticated ? getEventsText(GlobalStates.selectedCalendarDate) : "  Google Calendar sin autenticar"
            }
        }

        Rectangle {
            height: 1
            color: Appearance.colors.colOutlineVariant
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        // Tasks
        Column {
            spacing: 0
            Layout.fillWidth: true

            StyledPopupValueRow {
                icon: "checklist"
                label: Translation.tr("To Do:")
                value: ""
            }

            StyledText {
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSurfaceVariant
                text: root.todosSection
            }
        }
    }
}
