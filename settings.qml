import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Shapes

ApplicationWindow {
    id: win
    width: 1060
    height: 700
    minimumWidth: 900
    minimumHeight: 580
    visible: true
    title: "Litio"
    color: t.bg
    font.family: "Segoe UI"
    font.pixelSize: 14

    property int page: backend.devices.length ? 0 : 1
    property string selectedId: ""
    property bool scanned: false
    readonly property var current: backend.devices.find(d => d.id === selectedId) || null
    readonly property var compatible: backend.candidates.map((c, i) => Object.assign({ index: i }, c)).filter(c => c.supported)
    readonly property var incompatible: backend.candidates.filter(c => !c.supported)
    readonly property var liveValues: backend.devices.map(d => backend.live[d.id]).filter(s => s)

    onPageChanged: scanIfNeeded()
    Component.onCompleted: scanIfNeeded()

    function scanIfNeeded() {
        if (page === 1 && !scanned) {
            scanned = true
            backend.scan()
        }
    }

    QtObject {
        id: t
        readonly property bool dark: Application.styleHints.colorScheme !== Qt.Light
        readonly property color bg: dark ? "#0E1014" : "#F4F5F7"
        readonly property color rail: dark ? "#14171D" : "#ECEEF2"
        readonly property color surface: dark ? "#181C23" : "#FFFFFF"
        readonly property color raised: dark ? "#20252E" : "#F0F2F5"
        readonly property color line: dark ? "#2A303B" : "#DDE1E7"
        readonly property color text: dark ? "#F0F2F6" : "#171A20"
        readonly property color muted: dark ? "#919AAB" : "#5F6876"
        readonly property color accent: dark ? "#46D26E" : "#17954A"
        readonly property color onAccent: dark ? "#07180D" : "#FFFFFF"
        readonly property color danger: "#F0564F"
    }

    readonly property var glyphs: ({
        mouse: "M12 3a6 6 0 0 1 6 6v6a6 6 0 0 1-12 0V9a6 6 0 0 1 6-6zM12 7v3.5",
        headset: "M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3",
        gamepad: "M7.5 7h9a5 5 0 0 1 4.9 4l.9 4.5a2.7 2.7 0 0 1-4.8 2.2L15 15H9l-2.5 2.7a2.7 2.7 0 0 1-4.8-2.2l.9-4.5A5 5 0 0 1 7.5 7zM7.5 9.5v3M6 11h3M15.5 10.5h.01M17.5 12.5h.01",
        keyboard: "M4.5 6h15A2.5 2.5 0 0 1 22 8.5v7a2.5 2.5 0 0 1-2.5 2.5h-15A2.5 2.5 0 0 1 2 15.5v-7A2.5 2.5 0 0 1 4.5 6zM6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8",
        other: "M4 8h13a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2zM22 11v2",
        search: "M11 4a7 7 0 1 1 0 14 7 7 0 0 1 0-14zM20.5 20.5l-4.6-4.6",
        tune: "M4 7h9M18 7h2M15.5 4.5v5M4 17h2M11 17h9M8.5 14.5v5",
        plus: "M12 5v14M5 12h14",
        download: "M12 4v11M7 10l5 5 5-5M5 20h14",
        bolt: "M13.5 2 5 13.5h6L10 22l9-12.5h-6.2z",
        trash: "M4 7h16M9 7V4.5h6V7M6.5 7l1 13h9l1-13"
    })
    readonly property var kinds: [
        { value: "mouse", text: "Ratón" }, { value: "headset", text: "Cascos" },
        { value: "gamepad", text: "Mando" }, { value: "keyboard", text: "Teclado" },
        { value: "other", text: "Otro" }
    ]
    readonly property var swatches: ["#00B8FC", "#5AA0FF", "#B482FF", "#F03C3C", "#FF7A2F", "#FFBE46", "#46D26E", "#F2F2F5"]

    function levelColour(level) {
        if (level == null) return t.muted
        return level >= 30 ? "#46D26E" : level >= 15 ? "#F5AA28" : "#F0463C"
    }
    function numberColour(device, level) {
        return device && device.color_mode === "fixed" ? device.color : levelColour(level)
    }
    function statusOf(s) {
        if (!s || !s.online) return s && s.level != null ? "Apagado · último dato" : "Apagado"
        return s.charging ? "Cargando" : "En uso"
    }
    function summary() {
        const using_ = liveValues.filter(s => s.online && !s.charging).length
        const charging = liveValues.filter(s => s.online && s.charging).length
        return using_ + " en uso" + (charging ? " · " + charging + " cargando" : "")
    }

    component Glyph: Item {
        id: glyph
        property string name: "other"
        property color ink: t.text
        property real stroke: 2
        property bool filled: false
        implicitWidth: 20
        implicitHeight: 20
        Shape {
            width: 24
            height: 24
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { xScale: glyph.width / 24; yScale: glyph.height / 24 }
            ShapePath {
                strokeColor: glyph.ink
                strokeWidth: glyph.filled ? 0 : glyph.stroke
                fillColor: glyph.filled ? glyph.ink : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: win.glyphs[glyph.name] || win.glyphs.other }
            }
        }
    }

    component AppButton: Button {
        id: button
        property bool primary: false
        property bool danger: false
        property string icon_: ""
        implicitHeight: 36
        leftPadding: 14
        rightPadding: 14
        hoverEnabled: true
        font.weight: Font.DemiBold
        opacity: enabled ? 1 : 0.45
        contentItem: Item {
            implicitWidth: buttonRow.implicitWidth
            implicitHeight: buttonRow.implicitHeight
            Row {
                id: buttonRow
                anchors.centerIn: parent
                spacing: 7
                Glyph {
                    visible: button.icon_ !== ""
                    name: button.icon_
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    ink: label.color
                }
                Text {
                    id: label
                    text: button.text
                    font: button.font
                    anchors.verticalCenter: parent.verticalCenter
                    color: button.primary ? t.onAccent : button.danger ? t.danger : t.text
                }
            }
        }
        background: Rectangle {
            radius: 9
            color: button.primary ? (button.hovered ? Qt.lighter(t.accent, 1.1) : t.accent)
                 : button.hovered ? t.raised : "transparent"
            border.width: button.primary ? 0 : 1
            border.color: button.danger ? Qt.alpha(t.danger, 0.5) : t.line
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    component Toggle: Switch {
        id: toggle
        padding: 0
        implicitWidth: 42
        implicitHeight: 24
        indicator: Rectangle {
            implicitWidth: 42
            implicitHeight: 24
            radius: 12
            color: toggle.checked ? t.accent : t.raised
            border.width: toggle.checked ? 0 : 1
            border.color: t.line
            Behavior on color { ColorAnimation { duration: 140 } }
            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 3
                x: toggle.checked ? parent.width - width - 3 : 3
                color: toggle.checked ? t.onAccent : t.muted
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item {}
    }

    component Segment: Rectangle {
        id: segment
        property var options: []
        property string value: ""
        property bool glyphs: false
        signal picked(string value)
        implicitHeight: 40
        radius: 10
        color: t.raised
        RowLayout {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 2
            Repeater {
                model: segment.options
                delegate: Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool active: segment.value === modelData.value
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: active ? t.surface : "transparent"
                    border.width: active ? 1 : 0
                    border.color: t.line
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.text
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Glyph {
                        visible: segment.glyphs
                        anchors.centerIn: parent
                        name: option.modelData.value
                        ink: option.active ? t.text : t.muted
                    }
                    Text {
                        visible: !segment.glyphs
                        anchors.centerIn: parent
                        text: option.modelData.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: option.active ? t.text : t.muted
                    }
                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: segment.picked(option.modelData.value)
                    }
                    ToolTip.visible: segment.glyphs && optionArea.containsMouse
                    ToolTip.text: modelData.text
                    ToolTip.delay: 400
                }
            }
        }
    }

    component SectionLabel: Text {
        color: t.muted
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    component AppField: TextField {
        id: field
        implicitHeight: 38
        leftPadding: 12
        rightPadding: 12
        color: t.text
        selectionColor: t.accent
        selectedTextColor: t.onAccent
        placeholderTextColor: t.muted
        background: Rectangle {
            radius: 9
            color: t.raised
            border.width: 1
            border.color: field.activeFocus ? t.accent : "transparent"
        }
    }

    component NavItem: Rectangle {
        id: nav
        property string glyph: ""
        property string label: ""
        property int target: 0
        readonly property bool active: win.page === target
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 10
        color: active ? t.raised : area.containsMouse ? Qt.alpha(t.raised, 0.5) : "transparent"
        Accessible.role: Accessible.Button
        Accessible.name: label
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            spacing: 11
            Glyph {
                name: nav.glyph
                anchors.verticalCenter: parent.verticalCenter
                ink: nav.active ? t.accent : t.muted
            }
            Text {
                text: nav.label
                anchors.verticalCenter: parent.verticalCenter
                font.weight: Font.DemiBold
                color: nav.active ? t.text : t.muted
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.page = nav.target
        }
    }

    component PageHeader: RowLayout {
        property string heading: ""
        property string detail: ""
        default property alias actions: slot.data
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: heading
                color: t.text
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Text {
                text: detail
                color: t.muted
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
        Row {
            id: slot
            spacing: 8
        }
    }

    component LevelBar: Rectangle {
        id: bar
        property real level: 0
        property color ink: t.accent
        implicitHeight: 6
        radius: 3
        color: t.raised
        Rectangle {
            height: parent.height
            radius: 3
            color: bar.ink
            width: parent.width * Math.min(Math.max(bar.level, 0), 100) / 100
            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        }
    }

    component DeviceCard: Rectangle {
        id: card
        required property var modelData
        readonly property var live: backend.live[modelData.id] || null
        readonly property bool on: !!live && live.online
        readonly property bool hasLevel: !!live && live.level != null
        readonly property bool selected: win.selectedId === modelData.id
        readonly property color ink: on ? win.numberColour(modelData, live.level) : t.muted
        Layout.fillWidth: true
        implicitHeight: 118
        radius: 14
        color: hover.containsMouse ? t.raised : t.surface
        border.width: 1
        border.color: selected ? t.accent : t.line
        Accessible.role: Accessible.Button
        Accessible.name: modelData.name
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            RowLayout {
                spacing: 12
                Rectangle {
                    width: 44
                    height: 44
                    radius: 12
                    color: Qt.alpha(card.ink, 0.13)
                    Glyph {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        name: card.modelData.kind
                        ink: card.modelData.tint_glyph && card.on ? card.modelData.color : card.ink
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.name
                        color: t.text
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Row {
                        spacing: 6
                        Rectangle {
                            visible: card.on
                            width: 7
                            height: 7
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: card.live && card.live.charging ? "#FFD84A" : "#46D26E"
                        }
                        Text {
                            text: win.statusOf(card.live)
                            color: t.muted
                            font.pixelSize: 12
                        }
                    }
                }
                Row {
                    Layout.alignment: Qt.AlignBaseline
                    Text {
                        text: card.hasLevel ? card.live.level : "--"
                        color: card.on ? t.text : t.muted
                        font.pixelSize: 28
                        font.weight: Font.Bold
                    }
                    Text {
                        visible: card.hasLevel
                        text: "%"
                        color: t.muted
                        anchors.baseline: parent.children[0].baseline
                        leftPadding: 2
                        font.pixelSize: 13
                    }
                }
            }
            LevelBar {
                Layout.fillWidth: true
                level: card.hasLevel ? card.live.level : 0
                ink: card.ink
            }
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.selectedId = card.selected ? "" : card.modelData.id
        }
    }

    component TrayPreview: ColumnLayout {
        id: preview
        property var device: null
        property int level: 56
        property string caption: ""
        readonly property bool low: device && device.color_mode === "fixed" && level < backend.lowLevel
        spacing: 6
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64
            height: 64
            radius: 12
            color: "#1B1E25"
            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: 28
                height: 28
                stroke: 2.4
                name: preview.device ? preview.device.kind : "other"
                ink: preview.device && preview.device.tint_glyph ? preview.device.color : "#EBEBF0"
            }
            Rectangle {
                visible: preview.low
                anchors.horizontalCenter: parent.horizontalCenter
                y: 36
                width: 44
                height: 23
                radius: 6
                color: "#E12828"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34
                text: preview.level
                color: preview.low ? "white" : win.numberColour(preview.device, preview.level)
                font.pixelSize: 21
                font.weight: Font.Bold
            }
        }
        SectionLabel {
            Layout.alignment: Qt.AlignHCenter
            text: preview.caption
        }
    }

    component CandidateRow: Rectangle {
        id: row
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: 66
        radius: 12
        color: t.surface
        border.width: 1
        border.color: t.line
        opacity: modelData.supported ? 1 : 0.72
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12
            Rectangle {
                width: 38
                height: 38
                radius: 10
                color: t.raised
                Glyph {
                    anchors.centerIn: parent
                    name: row.modelData.kind
                    ink: row.modelData.supported ? t.text : t.muted
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    color: t.text
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.modelData.note
                    color: t.muted
                    elide: Text.ElideRight
                    font.pixelSize: 12
                }
            }
            Text {
                visible: row.modelData.supported
                text: row.modelData.level >= 0 ? row.modelData.level + " %" + (row.modelData.charging ? " · cargando" : "")
                    : row.modelData.online ? "Conectado" : "Sin conexión"
                color: t.muted
                font.pixelSize: 13
            }
            AppButton {
                visible: row.modelData.supported
                text: row.modelData.added ? "Añadido" : "Añadir"
                primary: !row.modelData.added
                enabled: !row.modelData.added
                icon_: row.modelData.added ? "" : "plus"
                onClicked: backend.add(row.modelData.index)
            }
        }
    }

    component SettingRow: Rectangle {
        id: setting
        property string heading: ""
        property string detail: ""
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(76, column.implicitHeight + 32)
        radius: 14
        color: t.surface
        border.width: 1
        border.color: t.line
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 24
            ColumnLayout {
                id: column
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: setting.heading
                    color: t.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: setting.detail
                    color: t.muted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            Row {
                id: slot
                spacing: 12
            }
        }
    }

    component Spinner: Item {
        id: spinner
        implicitWidth: 22
        implicitHeight: 22
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: t.accent
                strokeWidth: 2.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 11; centerY: 11; radiusX: 9; radiusY: 9; startAngle: 0; sweepAngle: 270 }
            }
        }
        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: spinner.visible }
    }

    ColorDialog {
        id: colourDialog
        title: "Elegir color"
        selectedColor: win.current ? win.current.color : "#46D26E"
        onAccepted: if (win.current) backend.setField(win.current.id, "color", selectedColor.toString().toUpperCase())
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Barra lateral
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 216
            color: t.rail
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4
                Row {
                    Layout.topMargin: 8
                    Layout.bottomMargin: 20
                    Layout.leftMargin: 8
                    spacing: 10
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 9
                        // El mismo degradado que el icono del programa (brand.py).
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#62E686" }
                            GradientStop { position: 1; color: "#16A04A" }
                        }
                        Glyph {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            name: "bolt"
                            filled: true
                            ink: "#07180D"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Litio"
                        color: t.text
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                }
                NavItem { glyph: "other"; label: "Dispositivos"; target: 0 }
                NavItem { glyph: "search"; label: "Buscar"; target: 1 }
                NavItem { glyph: "tune"; label: "General"; target: 2 }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.leftMargin: 12
                    Layout.bottomMargin: 6
                    text: win.summary()
                    color: t.muted
                    font.pixelSize: 12
                }
            }
        }

        // Contenido
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.page

            // Dispositivos
            RowLayout {
                spacing: 0
                Flickable {
                    id: deviceList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: deviceColumn.implicitHeight + 56
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    ColumnLayout {
                        id: deviceColumn
                        x: 28
                        y: 28
                        width: deviceList.width - 56
                        spacing: 20
                        PageHeader {
                            heading: "Dispositivos"
                            detail: backend.devices.length ? "Haz clic en uno para cambiar cómo se ve." : ""
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            visible: backend.devices.length > 0
                            columns: deviceColumn.width >= 620 ? 2 : 1
                            rowSpacing: 12
                            columnSpacing: 12
                            Repeater {
                                model: backend.devices
                                delegate: DeviceCard {}
                            }
                        }
                        Rectangle {
                            visible: backend.devices.length === 0
                            Layout.fillWidth: true
                            implicitHeight: 280
                            radius: 14
                            color: t.surface
                            border.width: 1
                            border.color: t.line
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                Glyph {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    stroke: 1.6
                                    name: "other"
                                    ink: t.muted
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Aún no hay dispositivos"
                                    color: t.text
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }
                                AppButton {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 6
                                    primary: true
                                    text: "Buscar dispositivos"
                                    icon_: "search"
                                    onClicked: win.page = 1
                                }
                            }
                        }
                    }
                }

                // Panel de edición
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: win.current ? 320 : 0
                    visible: Layout.preferredWidth > 0
                    clip: true
                    color: t.rail
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Flickable {
                        id: editor
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: editorColumn.implicitHeight + 40
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        ColumnLayout {
                            id: editorColumn
                            x: 20
                            y: 20
                            width: 280
                            spacing: 8
                            visible: !!win.current
                            RowLayout {
                                SectionLabel {
                                    Layout.fillWidth: true
                                    text: "Nombre"
                                }
                                Text {
                                    text: "×"
                                    color: t.muted
                                    font.pixelSize: 20
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.selectedId = ""
                                    }
                                }
                            }
                            AppField {
                                id: nameField
                                Layout.fillWidth: true
                                onEditingFinished: if (win.current && text.trim()) backend.setField(win.current.id, "name", text.trim())
                                Connections {
                                    target: win
                                    function onSelectedIdChanged() {
                                        if (win.current) nameField.text = win.current.name
                                    }
                                }
                            }
                            SectionLabel {
                                Layout.topMargin: 10
                                text: "Tipo"
                            }
                            Segment {
                                Layout.fillWidth: true
                                glyphs: true
                                options: win.kinds
                                value: win.current ? win.current.kind : ""
                                onPicked: value_ => backend.setField(win.current.id, "kind", value_)
                            }
                            SectionLabel {
                                Layout.topMargin: 10
                                text: "Color del número"
                            }
                            Segment {
                                Layout.fillWidth: true
                                options: [{ value: "fixed", text: "Color fijo" }, { value: "level", text: "Según nivel" }]
                                value: win.current ? win.current.color_mode : ""
                                onPicked: value_ => backend.setField(win.current.id, "color_mode", value_)
                            }
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 6
                                Repeater {
                                    model: win.swatches
                                    delegate: Rectangle {
                                        id: swatch
                                        required property string modelData
                                        readonly property bool active: !!win.current && win.current.color.toUpperCase() === modelData
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: modelData
                                        border.width: active ? 2 : 0
                                        border.color: t.text
                                        Accessible.role: Accessible.Button
                                        Accessible.name: modelData
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: backend.setField(win.current.id, "color", swatch.modelData)
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.topMargin: 4
                                spacing: 8
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: win.current ? win.current.color : "transparent"
                                }
                                AppField {
                                    id: hexField
                                    Layout.preferredWidth: 110
                                    text: win.current ? win.current.color.toUpperCase() : ""
                                    validator: RegularExpressionValidator { regularExpression: /#[0-9A-Fa-f]{0,6}/ }
                                    onEditingFinished: if (acceptableInput && text.length === 7) backend.setField(win.current.id, "color", text.toUpperCase())
                                }
                                AppButton {
                                    Layout.fillWidth: true
                                    text: "Otro…"
                                    onClicked: colourDialog.open()
                                }
                            }
                            RowLayout {
                                Layout.topMargin: 12
                                Text {
                                    Layout.fillWidth: true
                                    text: "Colorear también el dibujo"
                                    color: t.text
                                }
                                Toggle {
                                    checked: !!win.current && !!win.current.tint_glyph
                                    onToggled: backend.setField(win.current.id, "tint_glyph", checked)
                                }
                            }
                            RowLayout {
                                Layout.topMargin: 6
                                Text {
                                    Layout.fillWidth: true
                                    text: "Mostrar en la bandeja"
                                    color: t.text
                                }
                                Toggle {
                                    checked: !!win.current && win.current.tray !== false
                                    onToggled: backend.setField(win.current.id, "tray", checked)
                                }
                            }
                            SectionLabel {
                                Layout.topMargin: 14
                                text: "Vista previa en la bandeja"
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                spacing: 16
                                TrayPreview { device: win.current; level: 56; caption: "Normal" }
                                TrayPreview { device: win.current; level: Math.max(backend.lowLevel - 3, 1); caption: "Baja" }
                                Item { Layout.fillWidth: true }
                            }
                            AppButton {
                                Layout.topMargin: 16
                                Layout.fillWidth: true
                                danger: true
                                text: confirm.running ? "Pulsa otra vez para quitar" : "Quitar dispositivo"
                                icon_: "trash"
                                onClicked: {
                                    if (confirm.running) {
                                        confirm.stop()
                                        const id = win.selectedId
                                        win.selectedId = ""
                                        backend.remove(id)
                                    } else {
                                        confirm.start()
                                    }
                                }
                                Timer { id: confirm; interval: 3000 }
                            }
                        }
                    }
                }
            }

            // Buscar
            Flickable {
                id: searchPage
                contentWidth: width
                contentHeight: searchColumn.implicitHeight + 56
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                    id: searchColumn
                    x: 28
                    y: 28
                    width: searchPage.width - 56
                    spacing: 10
                    PageHeader {
                        heading: "Buscar"
                        detail: "Solo se consulta a modelos conocidos. A un aparato desconocido no se le envía nada."
                        Spinner {
                            visible: backend.scanning
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        AppButton {
                            text: backend.scanning ? "Buscando…" : "Buscar de nuevo"
                            icon_: "search"
                            enabled: !backend.scanning
                            onClicked: backend.scan()
                        }
                    }
                    SectionLabel {
                        Layout.topMargin: 14
                        visible: win.compatible.length > 0
                        text: "Compatibles"
                    }
                    Repeater {
                        model: win.compatible
                        delegate: CandidateRow {}
                    }
                    SectionLabel {
                        Layout.topMargin: 14
                        visible: win.incompatible.length > 0
                        text: "Sin protocolo conocido"
                    }
                    Repeater {
                        model: win.incompatible
                        delegate: CandidateRow {}
                    }
                }
            }

            // General
            ColumnLayout {
                spacing: 12
                PageHeader {
                    Layout.margins: 28
                    Layout.bottomMargin: 8
                    heading: "General"
                    detail: "Los cambios se aplican al momento."
                }
                SettingRow {
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    heading: "Stream Deck"
                    detail: "Publica los datos en 127.0.0.1:47631, solo para este PC. Sin esto, las teclas muestran --."
                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: backend.streamdeck
                        onToggled: backend.setStreamdeck(checked)
                    }
                }
                SettingRow {
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    heading: "Aviso de batería baja"
                    detail: "Con color fijo, por debajo de este nivel el número pasa a blanco sobre rojo."
                    Slider {
                        id: lowSlider
                        width: 180
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0
                        to: 50
                        stepSize: 5
                        snapMode: Slider.SnapAlways
                        value: backend.lowLevel
                        onMoved: backend.setLowLevel(value)
                        background: Rectangle {
                            y: (lowSlider.height - height) / 2
                            width: lowSlider.availableWidth
                            height: 6
                            radius: 3
                            color: t.raised
                            Rectangle {
                                width: lowSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: t.accent
                            }
                        }
                        handle: Rectangle {
                            x: lowSlider.visualPosition * (lowSlider.availableWidth - width)
                            y: (lowSlider.height - height) / 2
                            width: 20
                            height: 20
                            radius: 10
                            color: t.text
                        }
                    }
                    Text {
                        width: 74
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: lowSlider.value > 0 ? lowSlider.value + " %" : "Sin aviso"
                        color: t.text
                        font.weight: Font.DemiBold
                    }
                }
                SettingRow {
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    heading: "Actualizar automáticamente"
                    detail: "Busca versiones nuevas en GitHub al arrancar y cada 6 horas, y las instala sin preguntar. Los ajustes se conservan."
                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: backend.autoUpdate
                        onToggled: backend.setAutoUpdate(checked)
                    }
                }
                SettingRow {
                    id: updateRow
                    readonly property var info: backend.update || {}
                    readonly property string status: info.status || ""
                    readonly property var available: info.available || {}
                    readonly property bool busy: ["checking", "downloading", "installing"].includes(status)
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    heading: "Versión " + backend.version
                    detail: !status ? "El programa de fondo no está en marcha; ábrelo para buscar actualizaciones."
                          : info.message + (status === "available" && available.notes ? "\n\n" + available.notes : "")
                    Spinner {
                        visible: updateRow.busy
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    AppButton {
                        visible: updateRow.status !== "" && updateRow.status !== "available"
                        enabled: !updateRow.busy
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar ahora"
                        onClicked: backend.requestUpdate("check")
                    }
                    AppButton {
                        visible: updateRow.status === "available" && updateRow.info.installable
                        anchors.verticalCenter: parent.verticalCenter
                        primary: true
                        icon_: "download"
                        text: "Instalar " + (updateRow.available.version || "")
                        onClicked: backend.requestUpdate("install")
                    }
                    AppButton {
                        visible: updateRow.status === "available" && !updateRow.info.installable
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Ver en GitHub"
                        onClicked: Qt.openUrlExternally(updateRow.available.url)
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
