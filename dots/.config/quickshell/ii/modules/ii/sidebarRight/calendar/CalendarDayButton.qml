import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property int month: -1
    property int year: -1
    property bool openDialogOnClick: true

    readonly property bool isSelected: {
        if (month === -1 || year === -1 || !day) return false;
        var dayNum = parseInt(day);
        if (isNaN(dayNum)) return false;
        
        var selectedDate = GlobalStates.selectedCalendarDate;
        if (!selectedDate) return false;
        
        return selectedDate.getDate() === dayNum &&
               selectedDate.getMonth() === month &&
               selectedDate.getFullYear() === year;
    }

    onClicked: {
        if (month !== -1 && year !== -1) {
            var selectedDate = new Date(year, month, parseInt(day));
            GlobalStates.selectedCalendarDate = selectedDate;
            if (openDialogOnClick) {
                GlobalStates.googleCalendarDialogOpen = true;
            }
        }
    }

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: isSelected
    buttonRadius: Appearance.rounding.small
    
    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: button.toggled ? Appearance.m3colors.m3onPrimary : 
            (isToday == 1) ? Appearance.colors.colPrimary : 
            (isToday == 0) ? Appearance.colors.colOnLayer1 : 
            Appearance.colors.colOutlineVariant

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    readonly property bool hasEvents: {
        if (!GoogleCalendar.authenticated || month === -1 || year === -1 || !day) return false;
        var dayNum = parseInt(day);
        if (isNaN(dayNum)) return false;
        
        var targetDateStr = year + "-" + (month + 1).toString().padStart(2, '0') + "-" + dayNum.toString().padStart(2, '0');
        
        for (var i = 0; i < GoogleCalendar.events.length; i++) {
            var e = GoogleCalendar.events[i];
            if (!e.start || !e.end) continue;
            
            if (e.isAllDay) {
                var targetTime = new Date(year, month, dayNum).getTime();
                var startTime = new Date(e.start + "T00:00:00").getTime();
                var endTime = new Date(e.end + "T00:00:00").getTime();
                if (targetTime >= startTime && targetTime < endTime) return true;
            } else {
                var eventStartDateStr = e.start.substring(0, 10);
                var eventEndDateStr = e.end.substring(0, 10);
                
                var targetTime = new Date(targetDateStr + "T00:00:00").getTime();
                var eventStartTime = new Date(eventStartDateStr + "T00:00:00").getTime();
                var eventEndTime = new Date(eventEndDateStr + "T00:00:00").getTime();
                
                if (targetTime >= eventStartTime && targetTime <= eventEndTime) return true;
            }
        }
        return false;
    }

    Rectangle {
        id: eventDot
        width: 4
        height: 4
        radius: 2
        color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : Appearance.colors.colPrimary
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        visible: button.hasEvents
    }
}

