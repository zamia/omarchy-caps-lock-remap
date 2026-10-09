import QtQuick
import QtQuick.Controls
import Quickshell
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

  // The mapping this widget keeps in force: an XKB option, or "" to leave
  // Caps Lock to the user's own Hyprland config. It is this bar entry's own
  // setting in shell.json. No Hyprland config file is ever written — the
  // option is set on the running compositor and set again whenever a config
  // reload puts the user's own value back.
  //
  // It is read from shell.json directly rather than from the `settings` the
  // bar injects. After a plugin rescan the bar rebuilds a widget with the
  // settings it had when the bar was last laid out, and acting on those would
  // quietly bring back an older mapping.
  property string mapping: ""
  property bool mappingLoaded: false

  // Hyprland's live kb_options string. What the panel reports as "now" is
  // always derived from it, never from what was last clicked.
  property string kbOptions: ""
  property string error: ""

  // The options string last handed to Hyprland. Seeing it still unmet after
  // the apply means Hyprland refused it, and asking again would only loop.
  property string attempted: ""
  property bool syncAgain: false
  property bool reloadOnFollow: false

  // One cursor walks the mapping rows and then the bar-position row, whose
  // three chips get a cursor of their own for left/right.
  property int cursorIndex: 0
  property bool cursorActive: false
  property int sectionCursor: 0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var rows: Model.rows()
  readonly property string current: Model.currentOption(kbOptions)
  readonly property int sectionRow: rows.length
  readonly property string section: Model.sectionOf(bar ? bar.layoutConfig : null, moduleName)
  readonly property string followDetail: mapping === ""
    ? "Your own kb_options decide. Right now that gives: " + Model.labelFor(current)
    : "Your own kb_options decide, and this widget changes nothing"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Read the live options, then enforce the mapping against them.
  function sync() {
    if (statusProcess.running) { syncAgain = true; return }
    statusProcess.running = true
  }

  function enforce() {
    if (!mappingLoaded) return
    if (mapping === "" || Model.satisfies(kbOptions, mapping)) {
      if (attempted !== "") error = ""
      attempted = ""
      return
    }
    if (applyProcess.running) return

    var wanted = Model.withMapping(kbOptions, mapping)
    if (!Model.isSafe(wanted)) {
      error = "Your kb_options has characters this widget will not pass on, so it was left alone"
      return
    }
    if (attempted === wanted) {
      error = "Hyprland did not accept " + mapping
      return
    }
    attempted = wanted
    applyProcess.command = ["hyprctl", "eval", 'hl.config({ input = { kb_options = "' + wanted + '" } })']
    applyProcess.running = true
  }

  function choose(option) {
    if (option === mapping) return
    error = ""
    reloadOnFollow = option === ""
    var shell = bar ? bar.shell : null
    if (!shell || typeof shell.updateEntryInline !== "function"
        || shell.updateEntryInline(moduleName, { id: moduleName, mapping: option }) === false) {
      reloadOnFollow = false
      error = "Could not save the choice to the bar settings"
    }
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
    else choose(rows[cursorIndex].option)
  }

  function sectionIndex() {
    for (var i = 0; i < Model.SECTIONS.length; i++)
      if (Model.SECTIONS[i].value === section) return i
    return 0
  }

  function loadSaved(text) {
    var saved = Model.savedMapping(text, moduleName)
    if (saved !== null) mapping = saved
    if (mappingLoaded) return
    mappingLoaded = true
    sync()
  }

  // Handing Caps Lock back means dropping the option this widget set, and
  // the only way to learn the user's own value again is to re-read the config.
  onMappingChanged: {
    attempted = ""
    if (mapping === "" && reloadOnFollow) {
      reloadOnFollow = false
      reloadProcess.running = true
    } else {
      sync()
    }
  }

  onOpenedChanged: {
    if (!opened) return
    sync()
    cursorActive = false
    cursorIndex = 0
    sectionCursor = sectionIndex()
  }

  Component.onCompleted: sync()

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadSaved(text())
    onLoadFailed: if (!root.mappingLoaded) root.loadSaved("")
  }

  Process {
    id: statusProcess
    command: ["hyprctl", "-j", "getoption", "input:kb_options"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.kbOptions = Model.parseOption(statusOut.text)
      if (root.syncAgain) {
        root.syncAgain = false
        root.sync()
      } else if (exitCode === 0) {
        root.enforce()
      }
    }
  }

  Process {
    id: applyProcess
    onExited: root.sync()
  }

  Process {
    id: reloadProcess
    command: ["hyprctl", "reload", "config-only"]
  }

  // A config reload puts the user's own kb_options back, whether it came
  // from a hand edit, another tool, or this widget handing the key back.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || event.name !== "configreloaded") return
      root.attempted = ""
      root.sync()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    // Switch mapping without the menu, so a Hyprland bind or a script can
    // do it: `omarchy-shell io.github.zamia.caps-lock-remap set caps:escape`.
    // `set config` hands the key back to the user's own config.
    function set(option: string): string {
      var value = option === "config" ? "" : option
      if (value !== "" && !Model.byOption(value)) return "unknown mapping: " + option
      root.choose(value)
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(760))

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
            model: root.rows

            CursorSurface {
              id: row

              required property var modelData
              required property int index

              readonly property bool selected: modelData.option === root.mapping

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
                  text: modelData.option === "" ? root.followDetail : modelData.detail
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
