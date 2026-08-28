pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "moorgrove.overview"

  readonly property var host: root.bar ? root.bar.shell : null
  readonly property bool opened: host !== null && host.openPanelIds !== undefined
    && host.openPanelIds[root.moduleName] === true

  function togglePanel() {
    if (!host || typeof host.toggle !== "function") return
    host.toggle(root.moduleName, "{}")
  }

  function openSettings() {
    if (!host || typeof host.summon !== "function") return
    host.summon(root.moduleName, JSON.stringify({ settings: true }))
    if (typeof host.invokeIfLoaded === "function") {
      Qt.callLater(function() { host.invokeIfLoaded(root.moduleName, "openSettings", null) })
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰕰"
    active: root.opened
    tooltipText: "Workspace overview"

    onPressed: function(button) {
      if (button === Qt.RightButton) root.openSettings()
      else root.togglePanel()
    }
  }
}