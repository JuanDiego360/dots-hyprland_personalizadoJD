import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 520
    backgroundWidth: 380

    property string viewState: "list" // "list", "create", "edit", "auth"
    property var editingEvent: null
    
    // Form fields
    property string formSummary: ""
    property string formDescription: ""
    property string formStartTime: "09:00"
    property string formEndTime: "10:00"
    property bool formAllDay: false

    function resetForm() {
        formSummary = "";
        formDescription = "";
        formStartTime = "09:00";
        formEndTime = "10:00";
        formAllDay = false;
        editingEvent = null;
        summaryInput.text = "";
        descInput.text = "";
        startInput.text = "09:00";
        endInput.text = "10:00";
    }

    function populateForm(event) {
        editingEvent = event;
        formSummary = event.summary;
        formDescription = event.description;
        formAllDay = event.isAllDay;
        
        summaryInput.text = event.summary;
        descInput.text = event.description;
        
        if (event.isAllDay) {
            formStartTime = "00:00";
            formEndTime = "00:00";
            startInput.text = "00:00";
            endInput.text = "00:00";
        } else {
            var startPart = event.start.split("T");
            if (startPart.length > 1) {
                formStartTime = startPart[1].substring(0, 5);
                startInput.text = formStartTime;
            } else {
                formStartTime = "09:00";
                startInput.text = "09:00";
            }
            var endPart = event.end.split("T");
            if (endPart.length > 1) {
                formEndTime = endPart[1].substring(0, 5);
                endInput.text = formEndTime;
            } else {
                formEndTime = "10:00";
                endInput.text = "10:00";
            }
        }
    }

    onShowChanged: {
        if (show) {
            resetForm();
            if (!GoogleCalendar.authenticated) {
                viewState = "auth";
                GoogleCalendar.checkAuthAndLoadEvents();
            } else {
                viewState = "list";
            }
        }
    }

    Connections {
        target: GoogleCalendar
        function onEventsLoaded() {
            if (viewState === "auth" && GoogleCalendar.authenticated) {
                viewState = "list";
            }
        }
        function onOperationCompleted(success, message) {
            statusBanner.bannerText = message;
            statusBanner.isError = !success;
            statusBanner.visible = true;
            bannerTimer.restart();
            if (success) {
                viewState = "list";
                resetForm();
            }
        }
    }

    // Helper functions
    function eventMatchesDate(event, date) {
        if (!event || !date) return false;
        var startStr = event.start;
        var endStr = event.end;
        if (!startStr || !endStr) return false;

        var yearStr = date.getFullYear().toString();
        var monthStr = (date.getMonth() + 1).toString().padStart(2, '0');
        var dayStr = date.getDate().toString().padStart(2, '0');
        var targetDateStr = yearStr + "-" + monthStr + "-" + dayStr;

        if (event.isAllDay) {
            var targetTime = date.getTime();
            var startTime = new Date(startStr + "T00:00:00").getTime();
            var endTime = new Date(endStr + "T00:00:00").getTime();
            return targetTime >= startTime && targetTime < endTime;
        } else {
            var eventStartDateStr = startStr.substring(0, 10);
            var eventEndDateStr = endStr.substring(0, 10);
            
            var targetTime = new Date(targetDateStr + "T00:00:00").getTime();
            var eventStartTime = new Date(eventStartDateStr + "T00:00:00").getTime();
            var eventEndTime = new Date(eventEndDateStr + "T00:00:00").getTime();
            
            return targetTime >= eventStartTime && targetTime <= eventEndTime;
        }
    }

    function getFormattedTime(event) {
        if (event.isAllDay) return "Todo el día";
        var startPart = event.start.split("T");
        var endPart = event.end.split("T");
        var sTime = startPart.length > 1 ? startPart[1].substring(0, 5) : "";
        var eTime = endPart.length > 1 ? endPart[1].substring(0, 5) : "";
        return sTime + " - " + eTime;
    }

    function buildIsoString(date, timeStr) {
        var yearStr = date.getFullYear().toString();
        var monthStr = (date.getMonth() + 1).toString().padStart(2, '0');
        var dayStr = date.getDate().toString().padStart(2, '0');
        var hhmm = timeStr.trim();
        if (hhmm.indexOf(':') === -1) {
            hhmm = "12:00";
        }
        var parts = hhmm.split(':');
        var hours = parts[0].padStart(2, '0');
        var minutes = parts.length > 1 ? parts[1].padStart(2, '0') : "00";
        return yearStr + "-" + monthStr + "-" + dayStr + "T" + hours + ":" + minutes + ":00";
    }

    // Title / Date Header
    WindowDialogTitle {
        text: Translation.tr("Google Calendar")
    }

    StyledText {
        text: GlobalStates.selectedCalendarDate.toLocaleDateString(Qt.locale(), "dd MMMM yyyy")
        font.pixelSize: Appearance.font.pixelSize.normal
        font.weight: Font.DemiBold
        color: Appearance.colors.colPrimary
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -10
    }

    WindowDialogSeparator {}

    // Status Banner for feedback
    Rectangle {
        id: statusBanner
        visible: false
        Layout.fillWidth: true
        implicitHeight: bannerTextCol.implicitHeight + 16
        radius: Appearance.rounding.small
        color: isError ? Qt.rgba(1, 0.2, 0.2, 0.15) : Qt.rgba(0.2, 0.8, 0.2, 0.15)
        border.color: isError ? "#FF5555" : "#55FF55"
        border.width: 1

        property string bannerText: ""
        property bool isError: false

        RowLayout {
            id: bannerTextCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            MaterialSymbol {
                text: statusBanner.isError ? "error" : "check_circle"
                color: statusBanner.isError ? "#FF5555" : "#55FF55"
                iconSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                text: statusBanner.bannerText
                Layout.fillWidth: true
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.Wrap
            }
        }

        Timer {
            id: bannerTimer
            interval: 4000
            onTriggered: statusBanner.visible = false
        }
    }

    // Indeterminate Progress Bar for loading states
    StyledIndeterminateProgressBar {
        visible: GoogleCalendar.loading
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    // MAIN AREA
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        // View 1: Auth Screen
        ColumnLayout {
            anchors.fill: parent
            visible: root.viewState === "auth"
            spacing: 20
            Layout.alignment: Qt.AlignVCenter

            MaterialSymbol {
                text: "calendar_month"
                iconSize: Appearance.font.pixelSize.larger * 3
                color: Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: GoogleCalendar.errorType === "credentials_missing" 
                    ? "Falta configurar credenciales" 
                    : "Conectar con Google Calendar"
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                text: GoogleCalendar.errorType === "credentials_missing"
                    ? "Por favor, crea un cliente OAuth de escritorio en Google Cloud Console, descarga el archivo JSON de credenciales y guárdalo como:\n~/.config/illogical-impulse/credentials.json"
                    : "Inicia sesión para sincronizar tus eventos de Google Calendar. Esto abrirá tu navegador web."
                Layout.fillWidth: true
                color: Appearance.colors.colOutline
                font.pixelSize: Appearance.font.pixelSize.small
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Item { Layout.fillHeight: true }

            DialogButton {
                buttonText: GoogleCalendar.errorType === "credentials_missing" ? "Reintentar / Cargar" : "Iniciar Sesión"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    if (GoogleCalendar.errorType === "credentials_missing") {
                        GoogleCalendar.checkAuthAndLoadEvents();
                    } else {
                        GoogleCalendar.authenticate();
                    }
                }
            }
        }

        // View 2: Events List
        ColumnLayout {
            anchors.fill: parent
            visible: root.viewState === "list"
            spacing: 10

            ListView {
                id: eventsListView
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true
                spacing: 8

                model: GoogleCalendar.events.filter(e => root.eventMatchesDate(e, GlobalStates.selectedCalendarDate))

                delegate: Rectangle {
                    width: ListView.view.width
                    implicitHeight: delegateRow.implicitHeight + 16
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    border.width: 1
                    border.color: Appearance.colors.colLayer2Border

                    RowLayout {
                        id: delegateRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                text: modelData.summary
                                font.weight: Font.Bold
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer2
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: root.getFormattedTime(modelData)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colPrimary
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData.description
                                visible: modelData.description !== ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOutline
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        // Edit / Delete icons
                        RowLayout {
                            spacing: 4
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                            CalendarHeaderButton {
                                forceCircle: true
                                downAction: () => {
                                    root.populateForm(modelData);
                                    root.viewState = "edit";
                                }
                                contentItem: MaterialSymbol {
                                    text: "edit"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            CalendarHeaderButton {
                                forceCircle: true
                                downAction: () => {
                                    GoogleCalendar.deleteEvent(modelData.id);
                                }
                                contentItem: MaterialSymbol {
                                    text: "delete"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: "#FF5555"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // Placeholder if empty
                Label {
                    anchors.centerIn: parent
                    visible: eventsListView.count === 0
                    text: "No hay eventos para este día."
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOutline
                }
            }

            DialogButton {
                buttonText: "Nuevo Evento"
                Layout.fillWidth: true
                onClicked: {
                    root.resetForm();
                    root.viewState = "create";
                }
            }
        }

        // View 3: Create / Edit Form
        ScrollView {
            anchors.fill: parent
            visible: root.viewState === "create" || root.viewState === "edit"
            clip: true

            ColumnLayout {
                width: parent.width - 16
                spacing: 12
                Layout.margins: 8

                StyledText {
                    text: root.viewState === "create" ? "Nuevo Evento" : "Editar Evento"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }

                // Title
                StyledText {
                    text: "Título:"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOutline
                }
                MaterialTextField {
                    id: summaryInput
                    Layout.fillWidth: true
                    placeholderText: "Reunión, Cumpleaños..."
                    onTextChanged: root.formSummary = text
                }

                // Description
                StyledText {
                    text: "Descripción:"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOutline
                }
                MaterialTextField {
                    id: descInput
                    Layout.fillWidth: true
                    placeholderText: "Detalles del evento..."
                    onTextChanged: root.formDescription = text
                }

                // All day
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "Todo el día"
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledSwitch {
                        checked: root.formAllDay
                        onCheckedChanged: root.formAllDay = checked
                    }
                }

                // Time Pickers (Visible if not all-day)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !root.formAllDay
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: "Hora Inicio (HH:MM):"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOutline
                            }
                            MaterialTextField {
                                id: startInput
                                placeholderText: "09:00"
                                onTextChanged: root.formStartTime = text
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: "Hora Fin (HH:MM):"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOutline
                            }
                            MaterialTextField {
                                id: endInput
                                placeholderText: "10:00"
                                onTextChanged: root.formEndTime = text
                            }
                        }
                    }
                }

                Item { implicitHeight: 16 }

                // Actions row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    DialogButton {
                        buttonText: "Cancelar"
                        Layout.fillWidth: true
                        onClicked: {
                            root.viewState = "list";
                        }
                    }

                    DialogButton {
                        buttonText: "Guardar"
                        Layout.fillWidth: true
                        onClicked: {
                            var startIso = "";
                            var endIso = "";
                            if (root.formAllDay) {
                                var yearStr = GlobalStates.selectedCalendarDate.getFullYear().toString();
                                var monthStr = (GlobalStates.selectedCalendarDate.getMonth() + 1).toString().padStart(2, '0');
                                var dayStr = GlobalStates.selectedCalendarDate.getDate().toString().padStart(2, '0');
                                startIso = yearStr + "-" + monthStr + "-" + dayStr;
                                
                                var nextDay = new Date(GlobalStates.selectedCalendarDate.getTime() + 24 * 60 * 60 * 1000);
                                var nextYearStr = nextDay.getFullYear().toString();
                                var nextMonthStr = (nextDay.getMonth() + 1).toString().padStart(2, '0');
                                var nextDayStr = nextDay.getDate().toString().padStart(2, '0');
                                endIso = nextYearStr + "-" + nextMonthStr + "-" + nextDayStr;
                            } else {
                                startIso = root.buildIsoString(GlobalStates.selectedCalendarDate, root.formStartTime);
                                endIso = root.buildIsoString(GlobalStates.selectedCalendarDate, root.formEndTime);
                            }

                            if (root.viewState === "create") {
                                GoogleCalendar.createEvent(
                                    root.formSummary, 
                                    startIso, 
                                    endIso, 
                                    root.formDescription, 
                                    root.formAllDay,
                                    "America/Bogota"
                                );
                            } else {
                                GoogleCalendar.updateEvent(
                                    root.editingEvent.id,
                                    root.formSummary,
                                    startIso,
                                    endIso,
                                    root.formDescription,
                                    root.formAllDay,
                                    "America/Bogota"
                                );
                            }
                        }
                    }
                }
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Cerrar")
            onClicked: root.dismiss()
        }
    }
}
