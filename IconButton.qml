pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string glyph: ""
  property string label: ""
  property string fontFamily: Style.font.menuFamily
  property color foreground: Color.menu.text
  property color accent: Color.menu.selectedText
  property bool active: false
  property real glyphSize: Style.font.iconLarge

  signal activated()

  implicitWidth: content.implicitWidth + Style.spacing.rowPaddingX * 2
  implicitHeight: Style.spacing.controlHeight
  radius: Style.cornerRadius
  color: hover.hovered || root.active ? Util.alpha(root.foreground, 0.12) : "transparent"
  border.width: 1
  border.color: root.active ? Util.alpha(root.accent, 0.7) : Util.alpha(root.foreground, 0.18)

  Behavior on color {
    ColorAnimation { duration: 120 }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: root.label ? Style.spacing.sm : 0

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.glyph !== ""
      text: root.glyph
      color: root.active ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.glyphSize
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== ""
      text: root.label
      color: root.active ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    onTapped: root.activated()
  }
}