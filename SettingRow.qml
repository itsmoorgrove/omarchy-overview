pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  required property var surface
  required property var overview
  required property string settingKey
  required property string title
  required property var options

  width: parent ? parent.width : 0
  height: Style.spacing.controlHeight

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: root.surface.surfaceText
    font.family: root.surface.fontFamily
    font.pixelSize: Style.font.body
  }

  Segmented {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    options: root.options
    current: root.overview.setting(root.settingKey)
    fontFamily: root.surface.fontFamily
    foreground: root.surface.surfaceText
    accent: root.surface.surfaceAccent
    onSelected: function(value) {
      root.overview.updateSetting(root.settingKey, value)
    }
  }
}
