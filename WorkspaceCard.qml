pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  required property var slot
  required property int slotIndex
  required property var surface
  required property var overview

  readonly property bool ready: root.slot !== null && root.surface !== null && root.overview !== null
  readonly property var windows: root.ready && root.slot.workspace
    ? Model.windowsOf(root.slot.workspace, root.surface.frame)
    : []
  readonly property bool empty: root.windows.length === 0
  readonly property bool current: root.ready && root.slot.workspace !== null
    && root.slot.workspace.focused === true
  readonly property bool selected: root.surface.slotIndex === root.slotIndex
  readonly property bool dropTarget: root.surface.dragging && root.surface.dropIndex === root.slotIndex
  readonly property color accent: root.surface.surfaceAccent
  readonly property color text: root.surface.surfaceText

  Rectangle {
    id: canvas
    anchors.fill: parent
    radius: Style.cornerRadius > 0 ? Style.cornerRadius + 2 : 4
    color: Util.alpha(Color.background, 0.72)
    clip: true

    border.width: root.dropTarget || root.selected || root.current ? 2 : 1
    border.color: root.dropTarget
      ? root.accent
      : (root.selected ? Util.alpha(root.accent, 0.85)
        : (root.current ? Util.alpha(root.text, 0.55) : Util.alpha(root.text, 0.14)))

    Behavior on border.color {
      ColorAnimation { duration: 120 }
    }

    Image {
      anchors.fill: parent
      visible: root.overview.showWallpaper && status === Image.Ready
      source: root.overview.showWallpaper ? root.surface.wallpaperUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      opacity: 0.4
      sourceSize.width: Math.max(1, Math.round(canvas.width))
    }

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.background, root.dropTarget ? 0.15 : 0.4)
    }

    Item {
      id: mini
      anchors.fill: parent

      Repeater {
        model: root.windows

        WindowTile {
          required property int index
          required property var modelData

          entry: modelData
          stackIndex: index
          card: root
          surface: root.surface
          overview: root.overview

          x: Math.round(modelData.rect.x * mini.width)
          y: Math.round(modelData.rect.y * mini.height)
          width: Math.max(6, Math.round(modelData.rect.width * mini.width))
          height: Math.max(6, Math.round(modelData.rect.height * mini.height))
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.empty && !root.dropTarget
      text: "󰐕"
      color: root.text
      opacity: 0.18
      font.family: root.surface.fontFamily
      font.pixelSize: Math.max(Style.font.display, Math.round(canvas.height * 0.18))
    }

    Text {
      anchors.centerIn: parent
      visible: root.dropTarget
      text: "Move here"
      color: root.accent
      font.family: root.surface.fontFamily
      font.pixelSize: Style.font.body
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: Style.spacing.sm
      width: Math.max(badge.implicitWidth + Style.spacing.md, Style.space(22))
      height: Style.space(18)
      radius: Style.cornerRadius > 0 ? Style.cornerRadius : 3
      color: root.current ? root.accent : Util.alpha(Color.background, 0.8)
      border.width: 1
      border.color: root.current ? root.accent : Util.alpha(root.text, 0.2)

      Text {
        id: badge
        anchors.centerIn: parent
        text: root.ready ? root.slot.label : ""
        color: root.current ? Color.background : root.text
        font.family: root.surface.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        if (!root.ready) return
        root.surface.slotIndex = root.slotIndex
        root.surface.windowIndex = -1
      }
      onClicked: if (root.ready) root.overview.activateWorkspace(root.slot)
    }
  }
}