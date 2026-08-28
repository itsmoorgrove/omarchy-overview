pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  required property var entry
  required property int stackIndex
  required property var card
  required property var surface
  required property var overview

  readonly property bool ready: root.entry !== null && root.card !== null && root.surface !== null
    && root.overview !== null
  readonly property bool live: root.ready && root.overview.previews === "live"
    && root.entry.toplevel !== null && root.entry.toplevel.wayland !== null
  readonly property bool matched: !root.ready || Model.matches(root.entry, root.overview.filterText)
  readonly property bool dimmed: root.ready && root.overview.filterText !== "" && !root.matched
  readonly property bool held: root.ready && root.surface.dragging
    && root.surface.dragAddress === root.entry.address
  readonly property bool selected: root.ready && root.surface.slotIndex === root.card.slotIndex
    && root.surface.windowIndex === root.stackIndex
  readonly property string label: root.ready
    ? (root.entry.title || root.entry.appId || "window")
    : ""

  readonly property var desktopEntry: root.ready && root.entry.appId
    ? DesktopEntries.heuristicLookup(root.entry.appId)
    : null
  readonly property string iconSource: {
    if (!root.ready) return ""
    var name = root.desktopEntry && root.desktopEntry.icon ? root.desktopEntry.icon : root.entry.appId
    var path = name ? Quickshell.iconPath(name, true) : ""
    return path ? path : Quickshell.iconPath("application-x-executable", true)
  }

  z: root.stackIndex
  opacity: root.held ? 0.3 : (root.dimmed ? 0.28 : 1)

  Behavior on opacity {
    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
  }

  Rectangle {
    id: frame
    anchors.fill: parent
    anchors.margins: 1
    radius: Style.cornerRadius > 0 ? Style.cornerRadius : 3
    color: Util.alpha(Color.background, 0.92)
    clip: true
    border.width: root.selected || area.containsMouse ? 2 : 1
    border.color: root.selected || area.containsMouse
      ? root.surface.surfaceAccent
      : Util.alpha(root.surface.surfaceText, 0.22)

    Loader {
      anchors.fill: parent
      active: root.live && root.surface.visible

      sourceComponent: ScreencopyView {
        captureSource: root.entry.toplevel.wayland
        live: true
        paintCursor: false
      }
    }

    Image {
      id: icon

      readonly property int size: Math.max(8,
        Math.round(Math.min(Style.space(64), Math.min(frame.width, frame.height) * 0.5)))

      anchors.centerIn: parent
      visible: !root.live
      source: root.live ? "" : root.iconSource
      sourceSize.width: icon.size
      sourceSize.height: icon.size
      width: icon.size
      height: icon.size
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: Math.min(Style.space(20), frame.height * 0.28)
      visible: root.overview.showTitles && height >= Style.space(12)
      color: Util.alpha(Color.background, 0.82)

      Text {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.sm
        anchors.rightMargin: Style.spacing.sm
        text: root.label
        color: root.surface.surfaceText
        font.family: root.surface.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    property point origin: Qt.point(0, 0)
    property bool dragStarted: false

    onEntered: {
      if (!root.ready) return
      root.surface.slotIndex = root.card.slotIndex
      root.surface.windowIndex = root.stackIndex
    }

    onPressed: function(mouse) {
      origin = Qt.point(mouse.x, mouse.y)
      dragStarted = false
    }

    onPositionChanged: function(mouse) {
      if (!root.ready || !pressed || !(mouse.buttons & Qt.LeftButton)) return
      var point = mapToItem(null, mouse.x, mouse.y)

      if (!dragStarted) {
        if (Math.abs(mouse.x - origin.x) < 8 && Math.abs(mouse.y - origin.y) < 8) return
        dragStarted = true
        root.surface.beginDrag(root.entry.address, root.label, point)
        return
      }

      root.surface.updateDrag(point)
    }

    onReleased: if (dragStarted) root.surface.endDrag()

    onCanceled: {
      if (!dragStarted) return
      dragStarted = false
      root.surface.cancelDrag()
    }

    onClicked: function(mouse) {
      if (dragStarted || !root.ready) return
      if (mouse.button === Qt.MiddleButton) root.overview.closeWindow(root.entry.address)
      else root.overview.activateWindow(root.entry.address)
    }
  }

  Rectangle {
    id: closeButton

    readonly property real diameter: Style.space(20)

    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.spacing.xs + 1
    visible: area.containsMouse && root.width > Style.space(60) && root.height > Style.space(44)
    width: closeButton.diameter
    height: closeButton.diameter
    radius: closeButton.diameter / 2
    color: closeArea.containsMouse ? Color.urgent : Util.alpha(Color.background, 0.9)
    border.width: 1
    border.color: Util.alpha(root.surface.surfaceText, 0.35)

    Text {
      anchors.centerIn: parent
      text: "󰅖"
      color: root.surface.surfaceText
      font.family: root.surface.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: closeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.ready) root.overview.closeWindow(root.entry.address)
    }
  }
}
