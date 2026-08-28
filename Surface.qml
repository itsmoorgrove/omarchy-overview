pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "Model.js" as Model

PanelWindow {
  id: root

  required property var overview

  readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)
  readonly property var frame: Model.monitorFrame(root.hyprMonitor)
  readonly property string monitorName: root.hyprMonitor ? String(root.hyprMonitor.name) : ""
  readonly property bool primary: Hyprland.focusedMonitor !== null && root.hyprMonitor !== null
    && Hyprland.focusedMonitor.id === root.hyprMonitor.id

  readonly property real aspect: root.frame && root.frame.height > 0
    ? root.frame.width / root.frame.height
    : 16 / 10
  readonly property var slots: Model.slotsFor(Hyprland.workspaces, root.monitorName, root.primary, {
    minSlots: root.overview.minSlots,
    showEmpty: root.overview.showEmpty,
    showSpecial: root.overview.showSpecial
  })

  property int slotIndex: 0
  property int windowIndex: -1
  property var cards: []

  property bool dragging: false
  property string dragAddress: ""
  property string dragLabel: ""
  property real dragX: 0
  property real dragY: 0
  property int dropIndex: -1

  readonly property var insets: Model.reservedInsets(root.hyprMonitor)
  readonly property real chromeMargin: Style.spacing.lg

  readonly property string wallpaperUrl: "file://" + Quickshell.env("HOME")
    + "/.local/state/omarchy/current/background"

  readonly property color surfaceText: Color.menu.text
  readonly property color surfaceAccent: Color.menu.selectedText
  readonly property string fontFamily: Style.font.menuFamily

  function registerCard(index, item) {
    var next = root.cards.slice()
    next[index] = item
    root.cards = next
  }

  function selectedSlot() {
    return root.slotIndex >= 0 && root.slotIndex < root.slots.length ? root.slots[root.slotIndex] : null
  }

  function clampSelection() {
    if (root.slots.length === 0) {
      root.slotIndex = 0
      root.windowIndex = -1
      return
    }
    if (root.slotIndex >= root.slots.length) root.slotIndex = root.slots.length - 1
    if (root.slotIndex < 0) root.slotIndex = 0
  }

  function moveSlot(delta) {
    if (root.slots.length === 0) return
    root.slotIndex = (root.slotIndex + delta + root.slots.length) % root.slots.length
    root.windowIndex = -1
  }

  function slotWindows(index) {
    var slot = index >= 0 && index < root.slots.length ? root.slots[index] : null
    return slot && slot.workspace ? Model.windowsOf(slot.workspace, root.frame) : []
  }

  function moveWindowSelection(delta) {
    var windows = root.slotWindows(root.slotIndex)
    if (windows.length === 0) return

    var next = root.windowIndex + delta
    if (next < -1) next = windows.length - 1
    if (next >= windows.length) next = -1
    root.windowIndex = next
  }

  function jumpToWorkspace(id) {
    for (var i = 0; i < root.slots.length; i++) {
      if (!root.slots[i].special && root.slots[i].id === id) {
        root.slotIndex = i
        root.windowIndex = -1
        return true
      }
    }
    return false
  }

  function activateSelection() {
    var windows = root.slotWindows(root.slotIndex)
    if (root.windowIndex >= 0 && root.windowIndex < windows.length) {
      root.overview.activateWindow(windows[root.windowIndex].address)
    } else {
      root.overview.activateWorkspace(root.selectedSlot())
    }
  }

  function activateFilterMatch() {
    for (var i = 0; i < root.slots.length; i++) {
      var windows = root.slotWindows(i)
      for (var w = 0; w < windows.length; w++) {
        if (Model.matches(windows[w], root.overview.filterText)) {
          root.overview.activateWindow(windows[w].address)
          return
        }
      }
    }
  }

  function cardIndexAt(point) {
    for (var i = 0; i < root.cards.length; i++) {
      var card = root.cards[i]
      if (!card || !card.visible) continue
      var local = card.mapFromItem(null, point.x, point.y)
      if (local.x >= 0 && local.y >= 0 && local.x <= card.width && local.y <= card.height) return i
    }
    return -1
  }

  function beginDrag(address, label, point) {
    if (!Model.isAddress(address)) return
    root.dragging = true
    root.dragAddress = address
    root.dragLabel = label
    root.dragX = point.x
    root.dragY = point.y
    root.dropIndex = root.cardIndexAt(point)
  }

  function updateDrag(point) {
    if (!root.dragging) return
    root.dragX = point.x
    root.dragY = point.y
    root.dropIndex = root.cardIndexAt(point)
  }

  function cancelDrag() {
    root.dragging = false
    root.dragAddress = ""
    root.dragLabel = ""
    root.dropIndex = -1
  }

  function endDrag() {
    if (!root.dragging) return

    var target = root.dropIndex >= 0 && root.dropIndex < root.slots.length
      ? root.slots[root.dropIndex]
      : null
    var address = root.dragAddress

    root.cancelDrag()
    if (target) root.overview.moveWindow(address, target)
  }

  visible: root.overview.opened
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-overview"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: root.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  onVisibleChanged: {
    if (!root.visible) {
      root.cancelDrag()
      return
    }

    root.slotIndex = 0
    root.windowIndex = -1

    for (var i = 0; i < root.slots.length; i++) {
      if (root.slots[i].workspace && root.slots[i].workspace.focused) {
        root.slotIndex = i
        break
      }
    }

    Qt.callLater(function() { keys.forceActiveFocus() })
  }

  onSlotsChanged: root.clampSelection()

  Connections {
    target: root.overview

    function onSettingsOpenChanged() {
      if (!root.overview.settingsOpen && root.visible) {
        Qt.callLater(function() { keys.forceActiveFocus() })
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, Model.dimAlpha(root.overview.dim))
    opacity: root.overview.opened ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: root.overview.dismiss()
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: root.primary

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (root.overview.settingsOpen) return

      if (event.key === Qt.Key_Escape) {
        if (root.overview.filtering || root.overview.filterText) {
          root.overview.filtering = false
          root.overview.filterText = ""
        } else {
          root.overview.dismiss()
        }
        event.accepted = true
        return
      }

      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (root.overview.filtering && root.overview.filterText) root.activateFilterMatch()
        else root.activateSelection()
        event.accepted = true
        return
      }

      if (root.overview.filtering) {
        if (Util.editsFilter(event, root.overview.filterText)) {
          root.overview.filterText = Util.editedFilter(event, root.overview.filterText)
          event.accepted = true
          return
        }
        if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
            && event.text.charCodeAt(0) !== 127) {
          root.overview.filterText += event.text
          event.accepted = true
          return
        }
      }

      switch (event.key) {
      case Qt.Key_Left:
      case Qt.Key_H:
        root.moveSlot(-1)
        event.accepted = true
        return
      case Qt.Key_Right:
      case Qt.Key_L:
        root.moveSlot(1)
        event.accepted = true
        return
      case Qt.Key_Up:
      case Qt.Key_K:
        root.moveWindowSelection(-1)
        event.accepted = true
        return
      case Qt.Key_Down:
      case Qt.Key_J:
        root.moveWindowSelection(1)
        event.accepted = true
        return
      case Qt.Key_Tab:
        root.moveSlot(event.modifiers & Qt.ShiftModifier ? -1 : 1)
        event.accepted = true
        return
      case Qt.Key_Slash:
        root.overview.filtering = true
        event.accepted = true
        return
      case Qt.Key_Comma:
      case Qt.Key_S:
        root.overview.settingsOpen = true
        event.accepted = true
        return
      case Qt.Key_Q:
        root.overview.dismiss()
        event.accepted = true
        return
      }

      if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
        var id = event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0
        if (root.jumpToWorkspace(id)) event.accepted = true
      }
    }
  }

  Item {
    id: stage
    anchors.fill: parent
    anchors.topMargin: root.chromeMargin + root.insets.top
    anchors.bottomMargin: root.chromeMargin + root.insets.bottom
    anchors.leftMargin: root.chromeMargin + root.insets.left
    anchors.rightMargin: root.chromeMargin + root.insets.right
    opacity: root.overview.opened ? 1 : 0
    scale: root.overview.opened ? 1 : 0.97

    Behavior on opacity {
      NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }

    Header {
      id: header
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      surface: root
      overview: root.overview
    }

    Item {
      id: field
      anchors.top: header.bottom
      anchors.topMargin: Style.spacing.panelGap
      anchors.bottom: footer.top
      anchors.bottomMargin: Style.spacing.panelGap
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.panelPadding - root.chromeMargin
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.panelPadding - root.chromeMargin

      readonly property real gap: Style.spacing.xxl
      readonly property var grid: Model.bestGrid(root.slots.length, root.aspect, field.width, field.height,
        field.gap, Style.spaceReal(Model.densityWidth(root.overview.density)))

      Grid {
        anchors.centerIn: parent
        columns: Math.max(1, field.grid.columns)
        spacing: field.gap

        Repeater {
          model: root.slots

          WorkspaceCard {
            required property int index
            required property var modelData

            width: field.grid.cardWidth
            height: field.grid.cardHeight
            slot: modelData
            slotIndex: index
            surface: root
            overview: root.overview

            Component.onCompleted: root.registerCard(index, this)
          }
        }
      }
    }

    Footer {
      id: footer
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      surface: root
      overview: root.overview
    }
  }

  Rectangle {
    id: ghost
    visible: root.dragging
    x: root.dragX - ghost.width / 2
    y: root.dragY - ghost.height / 2
    z: 100
    width: Math.min(Style.space(240), ghostLabel.implicitWidth + Style.spacing.rowPaddingX * 2)
    height: Style.spacing.controlHeight
    radius: Style.cornerRadius
    color: Color.menu.background
    border.width: 1
    border.color: root.surfaceAccent
    opacity: 0.95

    Text {
      id: ghostLabel
      anchors.centerIn: parent
      width: ghost.width - Style.spacing.rowPaddingX * 2
      text: root.dragLabel
      color: root.surfaceText
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }
  }

  Loader {
    anchors.fill: parent
    active: root.overview.settingsOpen && root.primary
    z: 200

    sourceComponent: SettingsSheet {
      surface: root
      overview: root.overview
    }
  }
}