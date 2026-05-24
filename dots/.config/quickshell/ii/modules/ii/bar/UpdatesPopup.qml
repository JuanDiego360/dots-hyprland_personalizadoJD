import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

        // Header
        StyledPopupHeaderRow {
            icon: "download"
            label: "Actualizaciones"
        }

        StyledPopupValueRow {
            icon: "package"
            label: "Pacman:"
            value: Updates.pacmanCount.toString()
        }

        StyledPopupValueRow {
            icon: "extension"
            label: "AUR:"
            value: Updates.aurCount.toString()
        }

        StyledPopupValueRow {
            icon: "layers"
            label: "Flatpak:"
            value: Updates.flatpakCount.toString()
        }
    }
}
