pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  required property var surface
  required property var overview

  readonly property string shortcutHint: root.overview.shortcut
    ? root.overview.shortcut.replace(/ \+ /g, "+")
    : "unbound"

  implicitHeight: hints.implicitHeight

  Text {
    id: hints
    anchors.centerIn: parent
    width: Math.min(implicitWidth, parent.width - shortcut.implicitWidth * 2 - Style.spacing.xxl)
    text: "↔ move  ·  ↕ window  ·  enter open  ·  drag to move window  ·  / filter  ·  s settings  ·  esc close"
    color: root.surface.surfaceText
    opacity: 0.45
    font.family: root.surface.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
  }

  Text {
    id: shortcut
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.shortcutHint
    color: root.surface.surfaceText
    opacity: 0.35
    font.family: root.surface.fontFamily
    font.pixelSize: Style.font.caption
  }
}