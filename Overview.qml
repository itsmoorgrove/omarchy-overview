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
  readonly property string toggleCommand: "omarchy-shell shell toggle " + root.pluginId

  // Helper scripts live next to this file. __sourceDir is the plugin's own
  // source directory as resolved by the shell's PluginRegistry; the literal
  // fallback covers a manifest handed over without it.
  readonly property string helperDir: (root.manifest && root.manifest.__sourceDir
    ? String(root.manifest.__sourceDir).replace(/\/$/, "")
    : Quickshell.env("HOME") + "/.config/omarchy/plugins/" + root.pluginId) + "/bin"

  property bool opened: false
  property bool settingsOpen: false
  property bool filtering: false
  property string filterText: ""
  property string shortcut: ""
  property var binds: []

  // Last snapshot returned by the read helper, and why it is unusable if so.
  property string bindingsText: ""
  property bool bindingsReadable: false
  property bool bindingsPresent: false
  property string bindingsProblem: ""

  readonly property bool canBindShortcut: root.bindingsReadable && root.bindingsPresent

  // Set only by an explicit Apply/Clear in the settings sheet. The write is
  // issued from the completion of the read it is paired with, so the block is
  // always rebuilt from a fresh snapshot rather than a stale one.
  property string pendingAction: ""
  property string pendingShortcut: ""

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

  // The plugin ships unbound. Nothing here writes to the user's Hyprland
  // configuration until Apply or Clear is pressed in the settings sheet; the
  // overview is reachable from its bar icon and over IPC in the meantime.
  function refreshBindings() {
    if (readProcess.running) return
    readProcess.running = true
  }

  function applyShortcut(combination) {
    if (!Keybind.isValid(combination)) return
    if (writeProcess.running) return

    root.pendingAction = "apply"
    root.pendingShortcut = combination
    root.refreshBindings()
  }

  function clearShortcut() {
    if (writeProcess.running) return

    root.pendingAction = "clear"
    root.pendingShortcut = ""
    root.refreshBindings()
  }

  function runPendingWrite() {
    var action = root.pendingAction
    root.pendingAction = ""

    if (!action) return
    if (!root.canBindShortcut) {
      root.pendingShortcut = ""
      return
    }

    var next = action === "clear"
      ? Keybind.withoutBinding(root.bindingsText)
      : Keybind.withBinding(root.bindingsText, root.pendingShortcut,
        "Workspace overview", root.toggleCommand)

    if (next === null) {
      root.pendingShortcut = ""
      return
    }

    writeProcess.pendingResult = action === "clear" ? "" : root.pendingShortcut
    root.pendingShortcut = ""

    // Re-enabled per write: the helper reads until EOF, so stdin has to be
    // closed after the content goes out or the process never finishes.
    writeProcess.stdinEnabled = true
    writeProcess.running = true
    writeProcess.write(next)
    writeProcess.stdinEnabled = false
  }

  onOpenedChanged: if (root.opened) { root.refreshBindings(); bindsProcess.running = true }
  onSettingsOpenChanged: if (root.settingsOpen) { root.refreshBindings(); bindsProcess.running = true }

  // Reading and writing the bindings file both go through descriptor-safe
  // helpers rather than a FileView. FileView resolves the pathname itself and
  // hands back the whole file, so a size or file-type check in QML would only
  // run after the persistent shell had already opened and allocated it.
  Process {
    id: readProcess
    command: [root.helperDir + "/omarchy-overview-bindings-read"]
    stdout: StdioCollector {
      onStreamFinished: {
        var result = null
        try {
          result = JSON.parse(text)
        } catch (error) {
          result = null
        }

        if (result && result.status === "ok") {
          root.bindingsText = String(result.text)
          root.bindingsReadable = true
          root.bindingsPresent = true
          root.bindingsProblem = ""
        } else if (result && result.status === "missing") {
          // Omarchy always ships this file. Its absence means a layout this
          // plugin does not understand, so it declines to invent one rather
          // than dropping a lone binding block into an unknown setup.
          root.bindingsText = ""
          root.bindingsReadable = true
          root.bindingsPresent = false
          root.bindingsProblem = "No ~/.config/hypr/bindings.lua to add a shortcut to."
        } else {
          root.bindingsText = ""
          root.bindingsReadable = false
          root.bindingsPresent = false
          root.bindingsProblem = result && result.reason
            ? String(result.reason)
            : "The bindings file could not be read safely."
        }

        root.shortcut = root.bindingsPresent ? Keybind.readBlock(root.bindingsText) : ""
        root.runPendingWrite()
      }
    }
  }

  Process {
    id: writeProcess

    // The shortcut this write is establishing, adopted only once it lands.
    property string pendingResult: ""

    command: [root.helperDir + "/omarchy-overview-bindings-write"]
    stdout: StdioCollector {
      onStreamFinished: {
        var result = null
        try {
          result = JSON.parse(text)
        } catch (error) {
          result = null
        }

        if (result && result.status === "ok") {
          root.shortcut = writeProcess.pendingResult
          root.updateSetting("shortcut", writeProcess.pendingResult)
          root.bindingsProblem = ""
        } else {
          root.bindingsProblem = result && result.reason
            ? String(result.reason)
            : "The shortcut could not be written."
        }

        writeProcess.pendingResult = ""
        bindsProcess.running = true
      }
    }
  }

  Process {
    id: bindsProcess
    command: [root.helperDir + "/omarchy-overview-binds"]
    stdout: StdioCollector {
      onStreamFinished: {
        var result = null
        try {
          result = JSON.parse(text)
        } catch (error) {
          result = null
        }

        root.binds = result && result.status === "ok" && Array.isArray(result.binds)
          ? result.binds
          : []
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