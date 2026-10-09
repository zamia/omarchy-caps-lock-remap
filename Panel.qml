import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.zamia.caps-lock-remap"
  ipcTarget: "io.github.zamia.caps-lock-remap"
  manageIpc: false

  // Hyprland's live kb_options string. The selected row is always derived
  // from it, never from what was last clicked, so the panel also tells the
  // truth when input.lua or another tool changes the mapping.
  property string kbOptions: ""
  property string error: ""

  // One cursor walks the mapping rows and then the bar-position row, whose
  // three chips get a cursor of their own for left/right.
  property int cursorIndex: 0
  property bool cursorActive: false
  property int sectionCursor: 0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string controlPath: localPath(Qt.resolvedUrl("capsremapctl"))
  readonly property var mappings: Model.MAPPINGS
  readonly property string current: Model.currentOption(kbOptions)
  readonly property int sectionRow: mappings.length
  readonly property string section: Model.sectionOf(bar ? bar.layoutConfig : null, moduleName)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (e) { return value }
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function choose(option) {
    if (setProcess.running || option === current) return
    error = ""
    setProcess.command = [controlPath, "set", option]
    setProcess.running = true
  }

  // Moving rebuilds the widget in its new section, so the panel goes first.
  function moveTo(target) {
    if (target === section) return
    root.close()
    Util.execArgv(["omarchy", "bar", "move", moduleName, "--section", target])
  }

  function moveCursor(dx, dy) {
    if (dy !== 0) cursorIndex = Math.max(0, Math.min(sectionRow, cursorIndex + dy))
    else if (cursorIndex === sectionRow)
      sectionCursor = Math.max(0, Math.min(Model.SECTIONS.length - 1, sectionCursor + dx))
  }

  function activateCursor() {
    if (cursorIndex === sectionRow) moveTo(Model.SECTIONS[sectionCursor].value)
    else choose(mappings[cursorIndex].option)
  }

  function sectionIndex() {
    for (var i = 0; i < Model.SECTIONS.length; i++)
      if (Model.SECTIONS[i].value === section) return i
    return 0
  }

  onOpenedChanged: {
    if (!opened) return
    refresh()
    error = ""
    cursorActive = false
    cursorIndex = 0
    sectionCursor = sectionIndex()
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProcess
    command: [root.controlPath, "status"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.kbOptions = statusOut.text.trim()
    }
  }

  Process {
    id: setProcess
    stdout: StdioCollector { id: setOut; waitForEnd: true }
    stderr: StdioCollector { id: setErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.kbOptions = setOut.text.trim()
      else root.error = setErr.text.trim() || "Could not change the mapping"
    }
  }

  // Any config reload can change the mapping: a hand edit to input.lua,
  // OmaSettings, or this plugin's own write. Re-read on every one.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "configreloaded") root.refresh()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    // Switch mapping without the menu, so a Hyprland bind or a script can
    // do it: `omarchy-shell io.github.zamia.caps-lock-remap set caps:escape`.
    function set(option: string): string {
      if (!Model.byOption(option)) return "unknown mapping: " + option
      root.choose(option)
      return "ok"
    }
    function current(): string { return root.current }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰘲"
    tooltipText: "Caps Lock key: " + Model.labelFor(root.current)
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: {
        if (root.cursorActive) root.activateCursor()
        else root.cursorActive = true
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(4)

          PanelHero {
            width: parent.width
            title: "Caps Lock key"
            meta: "Now: " + Model.labelFor(root.current)
            detail: root.current
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: button.text
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                color: root.foreground
              }
            }
          }

          Repeater {
            model: root.mappings

            CursorSurface {
              id: row

              required property var modelData
              required property int index

              readonly property bool selected: modelData.option === root.current

              width: column.width
              height: Math.max(Style.space(42), rowText.implicitHeight + Style.space(14))
              hasCursor: root.cursorActive && root.cursorIndex === index
              current: selected
              foreground: root.foreground

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { root.cursorActive = true; root.cursorIndex = index }
                onClicked: root.choose(modelData.option)
              }

              Text {
                id: check
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(16)
                text: row.selected ? "󰄬" : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.icon
              }

              Column {
                id: rowText
                anchors.left: check.right
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  text: modelData.label
                  elide: Text.ElideRight
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  width: parent.width
                  text: modelData.detail
                  wrapMode: Text.WordWrap
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.error !== ""
            text: root.error
            wrapMode: Text.WordWrap
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          Item {
            width: parent.width
            height: sectionGroup.implicitHeight + Style.space(8)

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: "Icon position on the bar"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            ButtonGroup {
              id: sectionGroup
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              options: Model.SECTIONS
              value: root.section
              focusable: false
              cursorIndex: root.cursorActive && root.cursorIndex === root.sectionRow ? root.sectionCursor : -1
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) { root.moveTo(value) }
              onHovered: function(index, isHovered) {
                if (!isHovered) return
                root.cursorActive = true
                root.cursorIndex = root.sectionRow
                root.sectionCursor = index
              }
            }
          }

          Text {
            width: parent.width
            topPadding: Style.space(4)
            text: "↑↓ move · enter select · esc close"
            horizontalAlignment: Text.AlignHCenter
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
