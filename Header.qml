pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  required property var surface
  required property var overview

  implicitHeight: Math.max(title.implicitHeight, gear.implicitHeight)

  Row {
    id: title
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Style.spacing.sm
    spacing: Style.spacing.sm

    Text {
      id: titleLabel
      text: "Workspaces"
      color: root.surface.surfaceText
      font.family: root.surface.fontFamily
      font.pixelSize: Style.font.heading
    }

    Text {
      anchors.baseline: titleLabel.baseline
      text: "· " + root.surface.monitorName + " · " + root.surface.slots.length + " spaces"
      color: root.surface.surfaceText
      opacity: 0.5
      font.family: root.surface.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }

  Rectangle {
    id: filter
    anchors.centerIn: parent
    visible: root.overview.filtering
    width: Math.max(Style.space(200), filterRow.implicitWidth + Style.spacing.rowPaddingX * 2)
    height: Style.spacing.controlHeight
    radius: Style.cornerRadius
    color: Util.alpha(root.surface.surfaceText, 0.08)
    border.width: 1
    border.color: Util.alpha(root.surface.surfaceAccent, 0.5)

    Row {
      id: filterRow
      anchors.centerIn: parent
      spacing: Style.spacing.sm

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍉"
        color: root.surface.surfaceAccent
        font.family: root.surface.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.overview.filterText || "Filter windows…"
        color: root.surface.surfaceText
        opacity: root.overview.filterText ? 1 : 0.5
        font.family: root.surface.fontFamily
        font.pixelSize: Style.font.body
        textFormat: Text.PlainText
      }
    }
  }

  IconButton {
    id: gear
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    flat: true
    glyph: "󰒓"
    fontFamily: root.surface.fontFamily
    foreground: root.surface.surfaceText
    accent: root.surface.surfaceAccent
    active: root.overview.settingsOpen
    onActivated: root.overview.settingsOpen = !root.overview.settingsOpen
  }
}