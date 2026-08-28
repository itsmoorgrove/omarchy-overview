pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Model.js" as Model
import "Keybind.js" as Keybind

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: root.manifest && root.manifest.id
    ? String(root.manifest.id)
    : "moorgrove.overview"
  readonly property string bindingsPath: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"
  readonly property string toggleCommand: "omarchy-shell shell toggle " + root.pluginId

  property bool opened: false
  property bool settingsOpen: false
  property bool filtering: false
  property string filterText: ""
  property string shortcut: ""
  property bool bindingsMissing: false
  property bool shortcutInitialized: false
  property var binds: []

  readonly property var entry: {
    var config = root.shell ? root.shell.shellConfig : null
    if (!config) return null

    var layout = config.bar && config.bar.layout ? config.bar.layout : null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = layout ? layout[sections[s]] : null
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) {
        if (list[i] && String(list[i].id) === root.pluginId) return list[i]
      }
    }

    var plugins = Array.isArray(config.plugins) ? config.plugins : []
    for (var p = 0; p < plugins.length; p++) {
      if (plugins[p] && String(plugins[p].id) === root.pluginId) return plugins[p]
    }

    return null
  }

  readonly property string previews: root.setting("previews")
  readonly property bool showTitles: root.setting("titles") === true
  readonly property bool showEmpty: root.setting("empty") === true
  readonly property bool showSpecial: root.setting("special") === true
  readonly property bool showWallpaper: root.setting("wallpaper") === true
  readonly property string density: root.setting("density")
  readonly property string dim: root.setting("dim")
  readonly property int minSlots: Number(root.setting("slots"))

  function setting(key) {
    var value = root.entry ? root.entry[key] : undefined
    return value === undefined || value === null ? Model.defaultFor(key) : value
  }

  function updateSetting(key, value) {
    if (!root.shell || typeof root.shell.updateEntryInline !== "function") return

    var next = { id: root.pluginId }
    if (root.entry) {
      for (var existing in root.entry) if (existing !== "id") next[existing] = root.entry[existing]
    }
    next[key] = value
    root.shell.updateEntryInline(root.pluginId, next)
  }

  function open(payloadJson) {
    var payload = null
    try {
      payload = payloadJson ? JSON.parse(payloadJson) : null
    } catch (error) {
      payload = null
    }

    Hyprland.refreshMonitors()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()

    root.filtering = false
    root.filterText = ""
    root.settingsOpen = payload !== null && payload.settings === true
    root.opened = true
  }

  function close() {
    root.opened = false
    root.settingsOpen = false
    root.filtering = false
    root.filterText = ""
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function openSettings() {
    if (!root.opened) root.open("{}")
    root.settingsOpen = true
  }

  function dispatch(command) {
    if (!command) return
    Hyprland.dispatch(command)
  }

  function activateWorkspace(slot) {
    if (!slot) return
    root.dismiss()
    if (slot.special) root.dispatch(Model.focusSpecialCommand(slot.label))
    else root.dispatch(Model.focusWorkspaceCommand(slot.id))
  }

  function activateWindow(address) {
    var command = Model.focusWindowCommand(address)
    if (!command) return
    root.dismiss()
    root.dispatch(command)
  }

  function closeWindow(address) {
    root.dispatch(Model.closeWindowCommand(address))
    root.refreshLater()
  }

  function moveWindow(address, slot) {
    if (!slot) return
    var command = slot.special
      ? Model.moveWindowToSpecialCommand(address, slot.label)
      : Model.moveWindowCommand(address, slot.id)
    if (!command) return
    root.dispatch(command)
    root.refreshLater()
  }

  function refreshLater() {
    Qt.callLater(function() {
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
    })
  }

  function conflictFor(combination) {
    return Keybind.conflict(root.binds, combination)
  }

  function ensureDefaultShortcut() {
    if (root.shortcutInitialized) return
    if (!root.shell || root.entry === null) return
    if (root.bindingsText() === null) return

    root.shortcutInitialized = true
    if (root.entry.shortcut !== undefined) return

    root.applyShortcut(Model.defaultShortcut())
  }

  function bindingsText() {
    if (bindingsFile.loaded) return bindingsFile.text()
    if (root.bindingsMissing) return ""
    return null
  }

  function applyShortcut(combination) {
    if (!Keybind.isValid(combination)) return

    var current = root.bindingsText()
    if (current === null) return

    var next = Keybind.withBinding(current, combination, "Workspace overview", root.toggleCommand)
    if (next === null) return

    bindingsFile.setText(next)
    root.shortcut = combination
    root.updateSetting("shortcut", combination)
    bindsProcess.running = true
  }

  function clearShortcut() {
    var current = root.bindingsText()
    if (current === null) return

    bindingsFile.setText(Keybind.withoutBinding(current))
    root.shortcut = ""
    root.updateSetting("shortcut", "")
    bindsProcess.running = true
  }

  onEntryChanged: root.ensureDefaultShortcut()
  onOpenedChanged: if (root.opened) bindsProcess.running = true
  onSettingsOpenChanged: if (root.settingsOpen) bindsProcess.running = true

  FileView {
    id: bindingsFile
    path: root.bindingsPath
    preload: true
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onFileChanged: bindingsFile.reload()

    onLoaded: {
      root.bindingsMissing = false
      root.shortcut = Keybind.readBlock(bindingsFile.text())
      root.ensureDefaultShortcut()
    }

    onLoadFailed: {
      root.bindingsMissing = true
      root.shortcut = ""
      root.ensureDefaultShortcut()
    }
  }

  Process {
    id: bindsProcess
    command: ["hyprctl", "-j", "binds"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.binds = Array.isArray(parsed) ? parsed : []
        } catch (error) {
          root.binds = []
        }
      }
    }
  }

  IpcHandler {
    target: root.pluginId

    function open(): void {
      if (root.shell && typeof root.shell.summon === "function") root.shell.summon(root.pluginId, "{}")
      else root.open("{}")
    }

    function close(): void { root.dismiss() }

    function toggle(): void {
      if (root.shell && typeof root.shell.toggle === "function") root.shell.toggle(root.pluginId, "{}")
      else root.toggle()
    }

    function settings(): void { root.openSettings() }
  }

  Variants {
    model: Quickshell.screens

    Surface {
      required property var modelData
      screen: modelData
      overview: root
    }
  }
}