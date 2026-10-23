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
  property var settingsCache: null
  property var pendingSettings: ({})

  readonly property var entry: {
    if (!root.shell) return null

    // Third-party plugins receive a scoped shell API. Current Omarchy exposes
    // the bar through barConfig; older/full shell APIs expose shellConfig.bar.
    var config = root.shell.shellConfig || null
    var bar = config && config.bar ? config.bar : root.shell.barConfig
    if (!bar) return null

    var layout = bar.layout || null
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = layout ? layout[sections[s]] : null
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) {
        if (list[i] && String(list[i].id) === root.pluginId) return list[i]
      }
    }

    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    for (var p = 0; p < plugins.length; p++) {
      if (plugins[p] && String(plugins[p].id) === root.pluginId) return plugins[p]
    }

    return null
  }

  property string previews: "live"
  property bool showTitles: true
  property bool showEmpty: true
  property bool showSpecial: true
  property bool showWallpaper: true
  property string density: "comfortable"
  property string dim: "medium"
  property int minSlots: 5

  function copyEntry(source) {
    var copy = { id: root.pluginId }
    if (!source) return copy
    for (var key in source) if (key !== "id") copy[key] = source[key]
    return copy
  }

  function syncSettingsCache() {
    var incoming = root.copyEntry(root.entry)
    var waiting = ({})
    var hasPending = false
    // Acknowledge individual choices so unrelated external changes remain visible.
    for (var key in root.pendingSettings) {
      if (incoming[key] !== root.pendingSettings[key]) {
        waiting[key] = root.pendingSettings[key]
        incoming[key] = waiting[key]
        hasPending = true
      }
    }
    root.pendingSettings = waiting
    root.settingsCache = incoming
    root.applySettingsCache()
    if (!hasPending) settingsSyncTimeout.stop()
  }

  function expirePendingSettings() {
    // The published config is authoritative if a write is never acknowledged.
    root.pendingSettings = ({})
    root.syncSettingsCache()
  }

  Timer {
    id: settingsSyncTimeout
    interval: 2000
    repeat: false
    onTriggered: root.expirePendingSettings()
  }

  function cachedSetting(key) {
    var value = root.settingsCache ? root.settingsCache[key] : undefined
    return value === undefined || value === null ? Model.defaultFor(key) : value
  }

  function applySettingsCache() {
    root.previews = String(root.cachedSetting("previews"))
    root.showTitles = root.cachedSetting("titles") === true
    root.showWallpaper = root.cachedSetting("wallpaper") === true
    root.showEmpty = root.cachedSetting("empty") === true
    root.showSpecial = root.cachedSetting("special") === true
    root.density = String(root.cachedSetting("density"))
    root.dim = String(root.cachedSetting("dim"))
    root.minSlots = Number(root.cachedSetting("slots"))
  }

  function setting(key) {
    switch (String(key)) {
    case "previews": return root.previews
    case "titles": return root.showTitles
    case "wallpaper": return root.showWallpaper
    case "empty": return root.showEmpty
    case "special": return root.showSpecial
    case "density": return root.density
    case "dim": return root.dim
    case "slots": return root.minSlots
    default: return null
    }
  }

  function updateSetting(key, value) {
    if (!root.shell || typeof root.shell.updateEntryInline !== "function") return
    if (key === "shortcut") {
      if (typeof value !== "string" || (value !== "" && !Keybind.isValid(value))) return
    } else if (!Model.isSettingValue(key, value)) {
      return
    }

    root.syncSettingsCache()
    var next = root.copyEntry(root.settingsCache)
    next[key] = value
    var waiting = root.copyEntry(root.pendingSettings)
    delete waiting.id
    waiting[key] = value
    root.pendingSettings = waiting
    root.settingsCache = next
    root.applySettingsCache()
    settingsSyncTimeout.restart()

    try {
      if (!root.shell.updateEntryInline(root.pluginId, next)) {
        settingsSyncTimeout.stop()
        root.expirePendingSettings()
      }
    } catch (error) {
      settingsSyncTimeout.stop()
      root.expirePendingSettings()
      console.warn("Overview settings could not be saved:", String(error))
    }
  }

  onEntryChanged: root.syncSettingsCache()
  Component.onCompleted: {
    root.syncSettingsCache()
    rulesProcess.running = true
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
    if (!rulesProcess.running) rulesProcess.running = true

    root.filtering = false
    root.filterText = ""
    root.settingsOpen = payload !== null && payload.settings === true
    root.opened = true
  }

  function close() {
    root.cancelDrag()
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

  // Drag state lives here rather than on a surface: every monitor has its own
  // layer surface, and a drag picked up on one screen has to be able to land
  // on a workspace card of another. Hyprland keeps delivering pointer motion
  // to the surface that took the press, so positions arrive local to the
  // source surface and are lifted into compositor layout coordinates.
  property var surfaces: []
  property bool dragActive: false
  property var dragAddresses: []
  property string dragLabel: ""
  property var dragFrom: null
  property var dropSurface: null
  property int dropIndex: -1
  property real dropX: 0
  property real dropY: 0

  function registerSurface(surface) {
    if (root.surfaces.indexOf(surface) !== -1) return
    var next = root.surfaces.slice()
    next.push(surface)
    root.surfaces = next
  }

  function unregisterSurface(surface) {
    root.surfaces = root.surfaces.filter(function(item) { return item !== surface })
    if (root.dropSurface === surface) root.cancelDrag()
  }

  function isDragged(address) {
    return root.dragActive && root.dragAddresses.indexOf(address) !== -1
  }

  function beginDrag(surface, addresses, label, from, point) {
    var valid = (addresses || []).filter(function(address) { return Model.isAddress(address) })
    if (!surface || valid.length === 0) return
    // Freeze which surface holds the keyboard before the drag flag flips, so
    // the focus never bounces while the pointer crosses screens.
    for (var i = 0; i < root.surfaces.length; i++)
      root.surfaces[i].primaryAtDragStart = root.surfaces[i].focusedMonitor
    root.dragAddresses = valid
    root.dragLabel = label
    root.dragFrom = from
    root.dragActive = true
    root.updateDrag(surface, point)
  }

  function updateDrag(surface, point) {
    if (!root.dragActive || !surface || !surface.frame) return
    var x = surface.frame.x + point.x
    var y = surface.frame.y + point.y
    var frames = root.surfaces.map(function(item) { return item.frame })
    var index = Model.frameIndexAt(frames, x, y)
    var target = index >= 0 ? root.surfaces[index] : null

    root.dropSurface = target
    if (!target) {
      root.dropIndex = -1
      return
    }
    root.dropX = x - target.frame.x
    root.dropY = y - target.frame.y
    root.dropIndex = target.cardIndexAt(Qt.point(root.dropX, root.dropY))
  }

  function cancelDrag() {
    root.dragActive = false
    root.dragAddresses = []
    root.dragLabel = ""
    root.dragFrom = null
    root.dropSurface = null
    root.dropIndex = -1
  }

  function endDrag() {
    if (!root.dragActive) return
    var surface = root.dropSurface
    var target = surface && root.dropIndex >= 0 && root.dropIndex < surface.slots.length
      ? surface.slots[root.dropIndex]
      : null
    var commands = Model.moveCommands(root.dragAddresses, root.dragFrom, target)

    root.cancelDrag()
    for (var i = 0; i < commands.length; i++) root.dispatch(commands[i])
    if (commands.length > 0) root.refreshLater()
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

  // Workspace numbers that Hyprland rules pin to each monitor, so every
  // screen offers its own empty workspaces (Model.boundWorkspaceIds). Read on
  // each open; rules only change with the Hyprland config.
  property var boundIds: ({})

  Process {
    id: rulesProcess
    command: ["hyprctl", "-j", "workspacerules"]
    stdout: StdioCollector {
      onStreamFinished: {
        var rules = null
        try {
          rules = text.length <= 1048576 ? JSON.parse(text) : null
        } catch (error) {
          rules = null
        }
        root.boundIds = Model.boundWorkspaceIds(rules)
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
