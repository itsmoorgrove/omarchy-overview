pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Row {
  id: root

  property var options: []
  property var current: ""
  property string fontFamily: Style.font.menuFamily
  property color foreground: Color.menu.text
  property color accent: Color.menu.selectedText

  signal selected(var value)

  spacing: Style.spacing.xs

  Repeater {
    model: root.options

    Rectangle {
      id: option

      required property var modelData

      readonly property var optionValue: option.modelData.value
      readonly property bool active: String(option.optionValue) === String(root.current)

      width: Math.max(Style.space(58), optionLabel.implicitWidth + Style.spacing.rowPaddingX * 2)
      height: Style.spacing.controlHeight
      radius: Style.cornerRadius > 0 ? Style.cornerRadius : 3
      color: active ? Util.alpha(root.accent, 0.18)
        : (optionHover.hovered ? Util.alpha(root.foreground, 0.08) : "transparent")
      border.width: 1
      border.color: active ? Util.alpha(root.accent, 0.8) : Util.alpha(root.foreground, 0.16)

      Behavior on color {
        ColorAnimation { duration: 110 }
      }

      Text {
        id: optionLabel
        anchors.centerIn: parent
        text: option.modelData.label
        color: option.active ? root.accent : root.foreground
        opacity: option.active ? 1 : 0.75
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      HoverHandler {
        id: optionHover
        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        onTapped: root.selected(option.optionValue)
      }
    }
  }
}
