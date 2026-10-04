import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: root

    property bool open: false
    property string searchText: ""

    function launchApp(app) {
        if (!app)
            return

        app.execute()

        root.open = false
        root.searchText = ""
    }

    // Only actual application desktop entries.
    // No filesystem or wallpaper searching.
    property var filteredApps: {
        let apps = [...DesktopEntries.applications.values]

        apps = apps.filter(app => {
            if (!app)
                return false

            if (app.noDisplay)
                return false

            if (!app.icon || app.icon === "")
                return false

            if (Quickshell.iconPath(app.icon, true) === "")
                return false

            let name = String(app.name || "").trim()

            if (name === "")
                return false

            // Don't show entries named like image files.
            let lower = name.toLowerCase()

            if (lower.endsWith(".jpg")
                || lower.endsWith(".jpeg")
                || lower.endsWith(".png")
                || lower.endsWith(".webp")
                || lower.endsWith(".gif")
                || lower.endsWith(".bmp")
                || lower.endsWith(".svg"))
                return false

            // Don't show entries whose desktop ID looks like an image.
            let id = String(app.id || "").toLowerCase()

            if (id.endsWith(".jpg")
                || id.endsWith(".jpeg")
                || id.endsWith(".png")
                || id.endsWith(".webp")
                || id.endsWith(".gif")
                || id.endsWith(".bmp")
                || id.endsWith(".svg"))
                return false

            return true
        })

        let query = root.searchText.trim().toLowerCase()

        if (query === "")
            return apps

        // Search ONLY the application name.
        return apps.filter(app => {
            let name = String(app.name || "").toLowerCase()

            return name.includes(query)
        })
    }

    // IPC
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.open = !root.open

            if (root.open)
                Qt.callLater(() => search.forceActiveFocus())
        }

        function open(): void {
            root.open = true

            Qt.callLater(() => search.forceActiveFocus())
        }

        function close(): void {
            root.open = false
            root.searchText = ""
        }
    }

    PanelWindow {
        id: launcherWindow

        visible: root.open

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        color: "transparent"

        focusable: root.open

        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.keyboardFocus: root.open
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // Click outside → close
        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.open = false
                root.searchText = ""
            }
        }

        Rectangle {
            id: launcher

            width: 600
            height: 650

            anchors.centerIn: parent

            radius: 24

            color: "#e91b1b1b"

            border.width: 1
            border.color: "#40ffffff"

            // Keep clicks inside the launcher
            MouseArea {
                anchors.fill: parent

                onClicked: {
                    mouse.accepted = true
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 20

                spacing: 14

                // Search box
                TextField {
                    id: search

                    width: parent.width
                    height: 52

                    placeholderText: "Search applications..."

                    text: root.searchText

                    color: "white"
                    placeholderTextColor: "#80ffffff"

                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 17

                    background: Rectangle {
                        radius: 14

                        color: "#251f1f1f"

                        border.width: 1
                        border.color: "#35ffffff"
                    }

                    onTextChanged: {
                        root.searchText = text
                        appList.currentIndex = 0
                    }

                    Keys.onEscapePressed: {
                        root.open = false
                        root.searchText = ""
                    }

                    Keys.onDownPressed: {
                        if (appList.count > 0) {
                            appList.forceActiveFocus()

                            appList.currentIndex =
                                Math.min(
                                    appList.currentIndex + 1,
                                    appList.count - 1
                                )
                        }
                    }

                    Keys.onUpPressed: {
                        if (appList.count > 0) {
                            appList.forceActiveFocus()

                            appList.currentIndex =
                                Math.max(
                                    appList.currentIndex - 1,
                                    0
                                )
                        }
                    }

                    Keys.onReturnPressed: {
                        if (appList.currentItem)
                            root.launchApp(
                                appList.currentItem.app
                            )
                    }
                }

                // App list
                ListView {
                    id: appList

                    width: parent.width

                    height:
                        parent.height
                        - search.height
                        - 14

                    clip: true

                    spacing: 6

                    model: root.filteredApps

                    delegate: Rectangle {
                        id: appItem

                        required property var modelData

                        property var app: modelData

                        width: appList.width
                        height: 64

                        radius: 14

                        color:
                            ListView.isCurrentItem
                            ? "#35ffffff"
                            : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10

                            spacing: 14

                            Image {
                                width: 44
                                height: 44

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                source:
                                    Quickshell.iconPath(
                                        app.icon,
                                        true
                                    )

                                fillMode:
                                    Image.PreserveAspectFit

                                asynchronous: true
                            }

                            Column {
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                width: parent.width - 60

                                spacing: 2

                                Text {
                                    text:
                                        app.name || "Unknown"

                                    color: "white"

                                    font.family:
                                        "Iosevka Nerd Font"

                                    font.pixelSize: 16

                                    elide:
                                        Text.ElideRight
                                }

                                Text {
                                    text:
                                        app.genericName || ""

                                    color: "#80ffffff"

                                    font.family:
                                        "Iosevka Nerd Font"

                                    font.pixelSize: 12

                                    elide:
                                        Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                root.launchApp(app)
                            }
                        }
                    }

                    Keys.onEscapePressed: {
                        root.open = false
                        root.searchText = ""
                    }

                    Keys.onReturnPressed: {
                        if (currentItem)
                            root.launchApp(currentItem.app)
                    }
                }
            }
        }

        Keys.onEscapePressed: {
            root.open = false
            root.searchText = ""
        }
    }

    onOpenChanged: {
        if (root.open) {
            Qt.callLater(() => search.forceActiveFocus())
        }
    }
}
