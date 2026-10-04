import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire


ShellRoot {
    id: root

    // ============================================================
    // STATE
    // ============================================================

    property bool popupOpen: false
    property int popupPage: 0
    property string currentWallpaper: ""

    // ============================================================
    // LAUNCHER
    // ============================================================

    Launcher {
        id: launcher
    }

    // ============================================================
    // WALLPAPER COLORS
    // ============================================================

    ColorQuantizer {
        id: wallpaperColors
        source: root.currentWallpaper
        depth: 3
        rescaleSize: 64
    }

    property color wallpaperColor:
        wallpaperColors.colors.length > 0
            ? wallpaperColors.colors[0]
            : "#334155"

    property color glass:
        Qt.rgba(
            wallpaperColor.r * 0.35,
            wallpaperColor.g * 0.35,
            wallpaperColor.b * 0.35,
            0.90
        )

    property color glassDark:
        Qt.rgba(
            wallpaperColor.r * 0.20,
            wallpaperColor.g * 0.20,
            wallpaperColor.b * 0.20,
            0.88
        )

    property color glassHover:
        Qt.rgba(
            Math.min(wallpaperColor.r * 0.55 + 0.10, 1),
            Math.min(wallpaperColor.g * 0.55 + 0.10, 1),
            Math.min(wallpaperColor.b * 0.55 + 0.10, 1),
            0.92
        )

    property color border:
        Qt.rgba(
            Math.min(wallpaperColor.r + 0.30, 1),
            Math.min(wallpaperColor.g + 0.30, 1),
            Math.min(wallpaperColor.b + 0.30, 1),
            0.35
        )

    property color textColor: "#f1f5f9"
    property color muted: "#aeb8c4"

    // ============================================================
    // CLOCK
    // ============================================================

    property string currentTime:
        Qt.formatDateTime(
            new Date(),
            "hh:mm AP"
        )

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            root.currentTime =
                Qt.formatDateTime(
                    new Date(),
                    "hh:mm AP"
                )
        }
    }

    // ============================================================
    // WALLPAPERS
    // ============================================================

    ListModel {
        id: wallpapers
    }

    Process {
        id: wallpaperScanner

        command: [
            "sh",
            "-c",
            "find /home/rex/Pictures/Wallpapers -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) -print"
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                wallpapers.clear()

                let output = this.text.trim()

                if (output === "")
                    return

                let files = output.split("\n")

                for (let file of files) {
                    file = file.trim()

                    if (file !== "") {
                        wallpapers.append({
                            path: file
                        })
                    }
                }

                if (
                    root.currentWallpaper === "" &&
                    wallpapers.count > 0
                ) {
                    root.currentWallpaper =
                        wallpapers.get(0).path
                }
            }
        }
    }

    // ============================================================
    // MUSIC PLAYER
    // ONLY ACCEPT MUSIC.YOUTUBE.COM
    // ============================================================

    property var musicPlayer: {
        for (let player of Mpris.players.values) {

            let metadata = player.metadata

            if (metadata) {
                let url =
                    metadata["xesam:url"] ||
                    metadata["xesam:URL"] ||
                    metadata["mpris:url"] ||
                    ""

                if (
                    String(url).includes(
                        "music.youtube.com"
                    )
                ) {
                    return player
                }
            }
        }

        return null
    }

    // ============================================================
    // AUDIO
    // ============================================================

    property var audioSink:
        Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSink
        ]
    }

    property real audioVolume:
        audioSink && audioSink.audio
            ? audioSink.audio.volume
            : 0

    // ============================================================
    // BATTERY
    // ============================================================

    property int batteryPercent: 0
    property string batteryState: "Unknown"

    Process {
        id: batteryProcess

        command: [
            "sh",
            "-c",
            "upower -i \"$(upower -e | grep BAT)\""
        ]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {

                let output = this.text

                let percentageMatch =
                    output.match(
                        /percentage:\s+([0-9]+)%/i
                    )

                if (percentageMatch) {
                    root.batteryPercent =
                        parseInt(
                            percentageMatch[1]
                        )
                }

                let stateMatch =
                    output.match(
                        /state:\s+([^\n\r]+)/i
                    )

                if (stateMatch) {
                    root.batteryState =
                        stateMatch[1].trim()
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true

        onTriggered: {
            batteryProcess.running = false
            batteryProcess.running = true
        }
    }

    // ============================================================
    // CLOCK BAR
    // ============================================================

    PanelWindow {
        id: bar

        anchors.top: true

        margins.top: 4

        implicitWidth: clockText.implicitWidth + 55
        implicitHeight: 32

        exclusiveZone: 35

        color: "transparent"

        Rectangle {
            anchors.fill: parent

            radius: 19

            color: root.glass

            border.width: 1
            border.color: root.border

            Text {
                id: clockText

                anchors.centerIn: parent

                text: root.currentTime

                color: root.textColor

                font.family: "Iosevka Nerd Font"
                font.pixelSize: 14
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    root.popupPage = 0
                    root.popupOpen =
                        !root.popupOpen
                }
            }
        }
    }

    // ============================================================
    // POPUP
    // ============================================================

    PopupWindow {
        id: popup

        anchor.window: bar

        anchor.rect.x:
            bar.width / 2 -
            implicitWidth / 2

        anchor.rect.y:
            bar.height + 9

        implicitWidth: 390
        implicitHeight: 500

        visible: root.popupOpen

        grabFocus: true

        color: "transparent"

        onVisibleChanged: {
            if (!visible)
                root.popupOpen = false

            if (visible)
                popupFocus.forceActiveFocus()
        }

        // ========================================================
        // KEYBOARD FOCUS
        // ========================================================

        FocusScope {
            id: popupFocus

            anchors.fill: parent

            focus: true

            Keys.priority: Keys.BeforeItem

            Keys.onLeftPressed: function(event) {
                if (!root.popupOpen)
                    return

                root.popupPage =
                    Math.max(
                        0,
                        root.popupPage - 1
                    )

                event.accepted = true
            }

            Keys.onRightPressed: function(event) {
                if (!root.popupOpen)
                    return

                root.popupPage =
                    Math.min(
                        1,
                        root.popupPage + 1
                    )

                event.accepted = true
            }

            Keys.onEscapePressed: function(event) {
                root.popupOpen = false

                event.accepted = true
            }

            // ====================================================
            // POPUP BACKGROUND
            // ====================================================

            Rectangle {
                anchors.fill: parent

                radius: 21

                color: root.glass

                border.width: 1
                border.color: root.border

                Loader {
                    anchors.fill: parent

                    sourceComponent:
                        root.popupPage === 0
                            ? pageMain
                            : pageAudioBattery
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 35
                    z: 10

                    onClicked: {
                        if (root.popupPage === 1)
                            root.popupPage = 0
                    }
                }

                MouseArea {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 35
                    z: 10

                    onClicked: {
                        if (root.popupPage === 0)
                            root.popupPage = 1
                    }
                }
            }
        }
    }

    // ============================================================
    // PAGE 0
    // NOW PLAYING + WALLPAPERS
    // ============================================================

    Component {
        id: pageMain

        Column {
            anchors.fill: parent

            anchors.margins: 18

            spacing: 15

            Text {
                text: "NOW PLAYING"

                color: root.muted

                font.family:
                    "Iosevka Nerd Font"

                font.pixelSize: 11

                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 72

                radius: 14

                color: root.glassDark

                border.width: 1
                border.color: root.border

                Column {
                    anchors.centerIn: parent

                    spacing: 3

                    Text {
                        width: 320

                        text: {
                            let player =
                                root.musicPlayer

                            if (!player)
                                return "Nothing playing"

                            return player.trackTitle ||
                                "Unknown Title"
                        }

                        color: root.textColor

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 11

                        horizontalAlignment:
                            Text.AlignHCenter

                        elide:
                            Text.ElideRight
                    }

                    Text {
                        width: 320

                        text: {
                            let player =
                                root.musicPlayer

                            if (!player)
                                return ""

                            return player.trackArtist ||
                                "Unknown Artist"
                        }

                        color: root.muted

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 11

                        horizontalAlignment:
                            Text.AlignHCenter

                        elide:
                            Text.ElideRight
                    }
                }
            }

            Row {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                spacing: 8

                Rectangle {
                    width: 72
                    height: 38

                    radius: 11

                    color: root.glassDark

                    border.width: 1
                    border.color: root.border

                    Text {
                        anchors.centerIn:
                            parent

                        text: "󰒮"

                        color:
                            root.textColor

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 19
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            let player =
                                root.musicPlayer

                            if (
                                player &&
                                player.canGoPrevious
                            ) {
                                player.previous()
                            }
                        }
                    }
                }

                Rectangle {
                    width: 72
                    height: 38

                    radius: 11

                    color: root.glassHover

                    border.width: 1
                    border.color: root.border

                    Text {
                        anchors.centerIn:
                            parent

                        text: {
                            let player =
                                root.musicPlayer

                            if (!player)
                                return "󰐊"

                            return player.isPlaying
                                ? "󰏤"
                                : "󰐊"
                        }

                        color:
                            root.textColor

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 19
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            let player =
                                root.musicPlayer

                            if (
                                player &&
                                player.canTogglePlaying
                            ) {
                                player.togglePlaying()
                            }
                        }
                    }
                }

                Rectangle {
                    width: 72
                    height: 38

                    radius: 11

                    color: root.glassDark

                    border.width: 1
                    border.color: root.border

                    Text {
                        anchors.centerIn:
                            parent

                        text: "󰒭"

                        color:
                            root.textColor

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 19
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            let player =
                                root.musicPlayer

                            if (
                                player &&
                                player.canGoNext
                            ) {
                                player.next()
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1

                color: root.border
            }

            Text {
                text: "WALLPAPER"

                color: root.muted

                font.family:
                    "Iosevka Nerd Font"

                font.pixelSize: 11

                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: 285

                radius: 14

                color: root.glassDark

                border.width: 1
                border.color: root.border

                ListView {
                    anchors.fill: parent

                    anchors.margins: 8

                    clip: true

                    spacing: 7

                    model: wallpapers

                    delegate: Rectangle {
                        width:
                            ListView.view.width

                        height: 70

                        radius: 11

                        color: root.glassDark

                        border.width: 1
                        border.color: root.border

                        Row {
                            anchors.fill: parent

                            anchors.margins: 7

                            spacing: 11

                            Image {
                                width: 90
                                height: 56

                                source:
                                    "file://" +
                                    model.path

                                fillMode:
                                    Image.PreserveAspectCrop

                                asynchronous: true

                                smooth: true

                                sourceSize.width: 180
                                sourceSize.height: 112

                                Rectangle {
                                    anchors.fill:
                                        parent

                                    radius: 8

                                    color:
                                        "transparent"

                                    border.width: 1

                                    border.color:
                                        root.border
                                }
                            }

                            Text {
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                width: 235

                                text: {
                                    let parts =
                                        model.path.split("/")

                                    return parts[
                                        parts.length - 1
                                    ]
                                }

                                color:
                                    root.textColor

                                font.family:
                                    "Iosevka Nerd Font"

                                font.pixelSize: 11

                                elide:
                                    Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            hoverEnabled: true

                            onEntered: {
                                parent.color =
                                    root.glassHover
                            }

                            onExited: {
                                parent.color =
                                    root.glassDark
                            }

                            onClicked: {
                                root.currentWallpaper =
                                    model.path

                                Quickshell.execDetached({
                                    command: [
                                        "sh",
                                        "-c",
                                        "mkdir -p \"$HOME/.cache\"; ln -sfn \"$1\" \"$HOME/.cache/hyprlock-wallpaper\"; pkill -x swaybg 2>/dev/null; exec swaybg -i \"$1\" -m fill",
                                        "sh",
                                        model.path
                                    ]
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // PAGE 1
    // AUDIO + BATTERY + LOCK
    // ============================================================

    Component {
        id: pageAudioBattery

        Column {
            anchors.fill: parent

            anchors.margins: 18

            spacing: 15

            Text {
                text: "SYSTEM"

                color: root.muted

                font.family:
                    "Iosevka Nerd Font"

                font.pixelSize: 11

                font.bold: true
            }

            // ====================================================
            // AUDIO + BATTERY
            // ====================================================

            Row {
                width: parent.width

                spacing: 10

                // AUDIO

                Rectangle {
                    width:
                        (parent.width - 10) / 2

                    height: 150

                    radius: 14

                    color: root.glassDark

                    border.width: 1
                    border.color: root.border

                    Column {
                        anchors.fill: parent

                        anchors.margins: 14

                        spacing: 12

                        Text {
                            text: "AUDIO"

                            color:
                                root.muted

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 11

                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text: "󰕾"

                            color:
                                root.textColor

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 30
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                Math.round(
                                    root.audioVolume * 100
                                ) + "%"

                            color:
                                root.textColor

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 12
                        }

                        Slider {
                            id: volumeSlider

                            width:
                                parent.width

                            value:
                                root.audioVolume

                            from: 0
                            to: 1

                            focusPolicy:
                                Qt.NoFocus

                            onMoved: {
                                if (
                                    root.audioSink &&
                                    root.audioSink.audio
                                ) {
                                    root.audioSink.audio.volume =
                                        value
                                }
                            }
                        }
                    }
                }

                // BATTERY

                Rectangle {
                    width:
                        (parent.width - 10) / 2

                    height: 150

                    radius: 14

                    color: root.glassDark

                    border.width: 1
                    border.color: root.border

                    Column {
                        anchors.centerIn: parent

                        spacing: 10

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text: "BATTERY"

                            color:
                                root.muted

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 11

                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text: "󰁹"

                            color:
                                root.textColor

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 32
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                root.batteryPercent +
                                "%"

                            color:
                                root.textColor

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 15

                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter:
                                parent.horizontalCenter

                            text:
                                root.batteryState

                            color:
                                root.muted

                            font.family:
                                "Iosevka Nerd Font"

                            font.pixelSize: 10
                        }
                    }
                }
            }

            // ====================================================
            // LOCK BUTTON
            // ====================================================

            Rectangle {
                width: parent.width
                height: Math.max(0, parent.height - y)

                radius: 14

                color: root.glassDark

                border.width: 1
                border.color: root.border

                Column {
                    anchors.centerIn: parent

                    spacing: 10

                    Text {
                        anchors.horizontalCenter:
                            parent.horizontalCenter

                        text: "󰌾"

                        color:
                            root.textColor

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 42
                    }

                    Text {
                        anchors.horizontalCenter:
                            parent.horizontalCenter

                        text: "LOCK"

                        color:
                            root.textColor

                        font.family:
                            "Iosevka Nerd Font"

                        font.pixelSize: 12

                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent

                    hoverEnabled: true

                    onEntered: {
                        parent.color =
                            root.glassHover
                    }

                    onExited: {
                        parent.color =
                            root.glassDark
                    }

                    onClicked: {
                        Quickshell.execDetached([
                            "hyprlock"
                        ])
                    }
                }
            }
        }
    }
}
