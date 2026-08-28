pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "Keybind.js" as Keybind

Item {
  id: root

  required property var surface
  required property var overview

  property bool capturing: false
  property string draft: ""

  readonly property string activeShortcut: root.draft || root.overview.shortcut
  readonly property string conflict: root.activeShortcut && root.activeShortcut !== root.overview.shortcut
    ? (root.overview.conflictFor(root.activeShortcut) || "")
    : ""

  readonly property var keyTokens: {
    var tokens = ({})
    tokens[Qt.Key_Tab] = "Tab"
    tokens[Qt.Key_Space] = "space"
    tokens[Qt.Key_Return] = "Return"
    tokens[Qt.Key_Enter] = "Return"
    tokens[Qt.Key_Backspace] = "BackSpace"
    tokens[Qt.Key_Delete] = "Delete"
    tokens[Qt.Key_Insert] = "Insert"
    tokens[Qt.Key_Home] = "Home"
    tokens[Qt.Key_End] = "End"
    tokens[Qt.Key_PageUp] = "Prior"
    tokens[Qt.Key_PageDown] = "Next"
    tokens[Qt.Key_Left] = "Left"
    tokens[Qt.Key_Right] = "Right"
    tokens[Qt.Key_Up] = "Up"
    tokens[Qt.Key_Down] = "Down"
    tokens[Qt.Key_Print] = "Print"
    tokens[Qt.Key_Comma] = "comma"
    tokens[Qt.Key_Period] = "period"
    tokens[Qt.Key_Slash] = "slash"
    tokens[Qt.Key_Semicolon] = "semicolon"
    tokens[Qt.Key_Apostrophe] = "apostrophe"
    tokens[Qt.Key_Backslash] = "backslash"
    tokens[Qt.Key_BracketLeft] = "bracketleft"
    tokens[Qt.Key_BracketRight] = "bracketright"
    tokens[Qt.Key_Minus] = "minus"
    tokens[Qt.Key_Equal] = "equal"
    tokens[Qt.Key_QuoteLeft] = "grave"

    for (var f = 0; f < 12; f++) tokens[Qt.Key_F1 + f] = "F" + (f + 1)
    for (var l = 0; l < 26; l++) tokens[Qt.Key_A + l] = String.fromCharCode(65 + l)
    for (var d = 0; d < 10; d++) tokens[Qt.Key_0 + d] = String(d)

    return tokens
  }

  function modifiersOf(mask) {
    var modifiers = []
    if (mask & Qt.MetaModifier) modifiers.push("SUPER")
    if (mask & Qt.ControlModifier) modifiers.push("CTRL")
    if (mask & Qt.AltModifier) modifiers.push("ALT")
    if (mask & Qt.ShiftModifier) modifiers.push("SHIFT")
    return modifiers
  }

  function capture(event) {
    if (event.key === Qt.Key_Escape) {
      root.capturing = false
      root.draft = ""
      return true
    }

    var token = root.keyTokens[event.key]
    if (!token) return true

    var combination = Keybind.combo(root.modifiersOf(event.modifiers), token)
    if (!combination) return true

    root.draft = combination
    root.capturing = false
    return true
  }

  function commit() {
    if (!root.draft) return
    root.overview.applyShortcut(root.draft)
    root.draft = ""
  }

  function discard() {
    root.draft = ""
    root.capturing = false
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.6)

    MouseArea {
      anchors.fill: parent
      onClicked: root.overview.settingsOpen = false
    }
  }

  Rectangle {
    id: sheet
    anchors.centerIn: parent
    width: Math.min(Style.space(560), root.width - Style.spacing.panelPadding * 2)
    height: Math.min(rows.implicitHeight + Style.spacing.panelPadding * 2,
      root.height - Style.spacing.panelPadding * 2)
    radius: Style.cornerRadius > 0 ? Style.cornerRadius + 2 : 4
    color: Color.menu.background
    border.width: 1
    border.color: Util.alpha(root.surface.surfaceAccent, 0.6)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
    }

    Column {
      id: rows
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.lg

      Item {
        width: parent.width
        height: heading.implicitHeight

        Text {
          id: heading
          text: "Overview settings"
          color: root.surface.surfaceText
          font.family: root.surface.fontFamily
          font.pixelSize: Style.font.title
        }

        IconButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          glyph: "󰅖"
          fontFamily: root.surface.fontFamily
          foreground: root.surface.surfaceText
          accent: root.surface.surfaceAccent
          onActivated: root.overview.settingsOpen = false
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Util.alpha(root.surface.surfaceText, 0.12)
      }

      Column {
        width: parent.width
        spacing: Style.spacing.sm

        Item {
          width: parent.width
          height: Style.spacing.controlHeight

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Shortcut"
            color: root.surface.surfaceText
            font.family: root.surface.fontFamily
            font.pixelSize: Style.font.body
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(Style.space(150), shortcutLabel.implicitWidth + Style.spacing.rowPaddingX * 2)
              height: Style.spacing.controlHeight
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 3
              color: root.capturing ? Util.alpha(root.surface.surfaceAccent, 0.16) : "transparent"
              border.width: 1
              border.color: root.capturing
                ? root.surface.surfaceAccent
                : Util.alpha(root.surface.surfaceText, 0.16)

              Text {
                id: shortcutLabel
                anchors.centerIn: parent
                text: root.capturing
                  ? "Press keys…"
                  : (root.activeShortcut ? Keybind.label(root.activeShortcut) : "Not set")
                color: root.capturing || root.draft ? root.surface.surfaceAccent : root.surface.surfaceText
                opacity: root.capturing || root.activeShortcut ? 1 : 0.55
                font.family: root.surface.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              HoverHandler {
                cursorShape: Qt.PointingHandCursor
              }

              TapHandler {
                onTapped: {
                  root.capturing = true
                  keyCatcher.forceActiveFocus()
                }
              }
            }

            IconButton {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.draft !== ""
              label: "Apply"
              fontFamily: root.surface.fontFamily
              foreground: root.surface.surfaceText
              accent: root.surface.surfaceAccent
              active: true
              onActivated: root.commit()
            }

            IconButton {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.draft !== ""
              label: "Cancel"
              fontFamily: root.surface.fontFamily
              foreground: root.surface.surfaceText
              accent: root.surface.surfaceAccent
              onActivated: root.discard()
            }

            IconButton {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.draft === "" && root.overview.shortcut !== ""
              label: "Clear"
              fontFamily: root.surface.fontFamily
              foreground: root.surface.surfaceText
              accent: root.surface.surfaceAccent
              onActivated: root.overview.clearShortcut()
            }
          }
        }

        Text {
          width: parent.width
          text: root.capturing
            ? "Hold a modifier and press a key. Esc cancels."
            : (root.conflict
              ? "Replaces “" + root.conflict + "”. Applying overrides it."
              : "Writes a managed block into ~/.config/hypr/bindings.lua.")
          color: root.conflict ? Color.urgent : root.surface.surfaceText
          opacity: root.conflict ? 0.9 : 0.5
          font.family: root.surface.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Util.alpha(root.surface.surfaceText, 0.12)
      }

      Repeater {
        model: [
          { key: "previews", title: "Window previews", options: [
            { value: "live", label: "Live" }, { value: "icons", label: "Icons" }] },
          { key: "titles", title: "Window titles", options: [
            { value: true, label: "Show" }, { value: false, label: "Hide" }] },
          { key: "wallpaper", title: "Wallpaper backdrop", options: [
            { value: true, label: "On" }, { value: false, label: "Off" }] },
          { key: "empty", title: "Empty spaces", options: [
            { value: true, label: "Show" }, { value: false, label: "Hide" }] },
          { key: "special", title: "Special spaces", options: [
            { value: true, label: "Show" }, { value: false, label: "Hide" }] },
          { key: "density", title: "Card size", options: [
            { value: "compact", label: "Compact" }, { value: "comfortable", label: "Regular" },
            { value: "large", label: "Large" }] },
          { key: "dim", title: "Backdrop dim", options: [
            { value: "subtle", label: "Subtle" }, { value: "medium", label: "Medium" },
            { value: "strong", label: "Strong" }] },
          { key: "slots", title: "Minimum spaces", options: [
            { value: 3, label: "3" }, { value: 5, label: "5" }, { value: 10, label: "10" }] }
        ]

        Item {
          required property var modelData

          width: rows.width
          height: Style.spacing.controlHeight

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.title
            color: root.surface.surfaceText
            font.family: root.surface.fontFamily
            font.pixelSize: Style.font.body
          }

          Segmented {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: modelData.options
            current: root.overview.setting(modelData.key)
            fontFamily: root.surface.fontFamily
            foreground: root.surface.surfaceText
            accent: root.surface.surfaceAccent
            onSelected: function(value) { root.overview.updateSetting(modelData.key, value) }
          }
        }
      }
    }
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (root.capturing) {
        event.accepted = root.capture(event)
        return
      }

      if (event.key === Qt.Key_Escape) {
        root.overview.settingsOpen = false
        event.accepted = true
      }
    }
  }

  Component.onCompleted: keyCatcher.forceActiveFocus()
}