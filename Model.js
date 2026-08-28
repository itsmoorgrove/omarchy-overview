.pragma library

var ADDRESS_PATTERN = /^0x[0-9a-f]{1,16}$/
var WORKSPACE_PATTERN = /^-?[0-9]{1,4}$/
var SPECIAL_PATTERN = /^[A-Za-z0-9_-]{1,32}$/

var DEFAULTS = {
  previews: "live",
  titles: true,
  wallpaper: true,
  empty: true,
  special: true,
  density: "comfortable",
  dim: "medium",
  slots: 5
}

var DENSITIES = {
  compact: 400,
  comfortable: 560,
  large: 760
}

var DIMS = {
  subtle: 0.62,
  medium: 0.85,
  strong: 0.97
}

function defaultFor(key) {
  var value = DEFAULTS[String(key)]
  return value === undefined ? null : value
}

function isAddress(value) {
  return ADDRESS_PATTERN.test(String(value === undefined ? "" : value).toLowerCase())
}

function isWorkspaceId(value) {
  return WORKSPACE_PATTERN.test(String(value))
}

function isSpecialName(value) {
  return SPECIAL_PATTERN.test(String(value === undefined ? "" : value))
}

function normalizeAddress(value) {
  var text = String(value === undefined ? "" : value).toLowerCase()
  if (text.indexOf("0x") !== 0) text = "0x" + text
  return isAddress(text) ? text : ""
}

function densityWidth(name) {
  var value = DENSITIES[String(name)]
  return value === undefined ? DENSITIES.comfortable : value
}

function dimAlpha(name) {
  var value = DIMS[String(name)]
  return value === undefined ? DIMS.medium : value
}

function reservedInsets(monitor) {
  var none = { left: 0, top: 0, right: 0, bottom: 0 }
  if (!monitor || !monitor.lastIpcObject) return none

  var reserved = monitor.lastIpcObject.reserved
  if (!reserved || reserved.length < 4) return none

  return {
    left: Math.max(0, Number(reserved[0]) || 0),
    top: Math.max(0, Number(reserved[1]) || 0),
    right: Math.max(0, Number(reserved[2]) || 0),
    bottom: Math.max(0, Number(reserved[3]) || 0)
  }
}

function monitorFrame(monitor) {
  if (!monitor) return null
  var scale = Number(monitor.scale) || 1
  var width = Number(monitor.width) / scale
  var height = Number(monitor.height) / scale
  if (!(width > 0) || !(height > 0)) return null
  return { x: Number(monitor.x) || 0, y: Number(monitor.y) || 0, width: width, height: height }
}

function clamp01(value) {
  if (!isFinite(value)) return 0
  return value < 0 ? 0 : (value > 1 ? 1 : value)
}

function windowRect(ipcObject, frame) {
  if (!ipcObject || !frame) return null
  var at = ipcObject.at
  var size = ipcObject.size
  if (!at || !size || at.length < 2 || size.length < 2) return null

  var left = clamp01((Number(at[0]) - frame.x) / frame.width)
  var top = clamp01((Number(at[1]) - frame.y) / frame.height)
  var right = clamp01((Number(at[0]) + Number(size[0]) - frame.x) / frame.width)
  var bottom = clamp01((Number(at[1]) + Number(size[1]) - frame.y) / frame.height)

  if (right <= left || bottom <= top) return null
  return { x: left, y: top, width: right - left, height: bottom - top }
}

function toplevelEntry(toplevel, frame) {
  if (!toplevel) return null
  var ipcObject = toplevel.lastIpcObject
  if (!ipcObject) return null
  if (ipcObject.mapped === false || ipcObject.hidden === true) return null

  var address = normalizeAddress(ipcObject.address)
  if (!address) return null

  var rect = windowRect(ipcObject, frame)
  if (!rect) return null

  return {
    address: address,
    appId: String(ipcObject["class"] || ""),
    title: String(toplevel.title || ipcObject.title || ""),
    floating: ipcObject.floating === true,
    fullscreen: Number(ipcObject.fullscreen) > 0,
    pinned: ipcObject.pinned === true,
    order: Number(ipcObject.focusHistoryID),
    rect: rect,
    toplevel: toplevel
  }
}

function stackOrder(left, right) {
  if (left.floating !== right.floating) return left.floating ? 1 : -1
  var leftOrder = isFinite(left.order) ? left.order : 1e6
  var rightOrder = isFinite(right.order) ? right.order : 1e6
  return rightOrder - leftOrder
}

function windowsOf(workspace, frame) {
  var entries = []
  if (!workspace || !workspace.toplevels) return entries

  var values = workspace.toplevels.values || []
  for (var i = 0; i < values.length; i++) {
    var entry = toplevelEntry(values[i], frame)
    if (entry) entries.push(entry)
  }

  entries.sort(stackOrder)
  return entries
}

function workspaceLabel(workspace, id) {
  if (id < 0) {
    var name = String(workspace && workspace.name ? workspace.name : "")
    var marker = name.indexOf("special:")
    return marker === 0 ? name.slice(8) : (name || "special")
  }
  return String(id)
}

function slotsFor(workspaces, screenName, isPrimary, options) {
  var settings = options || {}
  var minimum = Math.max(1, Math.min(10, Number(settings.minSlots) || 5))
  var values = (workspaces && workspaces.values) || []

  var mine = []
  var specials = []
  var usedAnywhere = {}

  for (var i = 0; i < values.length; i++) {
    var workspace = values[i]
    if (!workspace) continue
    var id = Number(workspace.id)
    if (!isFinite(id)) continue

    if (id > 0) usedAnywhere[id] = true

    var monitor = workspace.monitor
    var owner = monitor ? String(monitor.name) : ""
    if (screenName && owner && owner !== screenName) continue

    if (id < 0) {
      if (settings.showSpecial) specials.push({ id: id, label: workspaceLabel(workspace, id), workspace: workspace, special: true })
    } else {
      mine.push({ id: id, label: workspaceLabel(workspace, id), workspace: workspace, special: false })
    }
  }

  if (settings.showEmpty && isPrimary) {
    var highest = 0
    for (var m = 0; m < mine.length; m++) highest = Math.max(highest, mine[m].id)

    var ceiling = Math.min(10, Math.max(minimum, highest + 1))
    for (var slot = 1; slot <= ceiling; slot++) {
      if (usedAnywhere[slot]) continue
      mine.push({ id: slot, label: String(slot), workspace: null, special: false })
    }
  }

  mine.sort(function(left, right) { return left.id - right.id })
  specials.sort(function(left, right) { return right.id - left.id })

  return specials.concat(mine)
}

function bestGrid(count, aspect, areaWidth, areaHeight, gap, maxCardWidth) {
  if (count <= 0 || areaWidth <= 0 || areaHeight <= 0 || aspect <= 0) {
    return { columns: 1, rows: 1, cardWidth: 0, cardHeight: 0 }
  }

  var best = null
  for (var columns = 1; columns <= count; columns++) {
    var rows = Math.ceil(count / columns)
    var cardWidth = (areaWidth - gap * (columns - 1)) / columns
    var cardHeight = cardWidth / aspect

    if (cardHeight * rows + gap * (rows - 1) > areaHeight) {
      cardHeight = (areaHeight - gap * (rows - 1)) / rows
      cardWidth = cardHeight * aspect
    }

    if (cardWidth <= 0 || cardHeight <= 0) continue
    if (maxCardWidth > 0 && cardWidth > maxCardWidth) {
      cardWidth = maxCardWidth
      cardHeight = cardWidth / aspect
    }

    if (!best || cardWidth >= best.cardWidth) {
      best = { columns: columns, rows: rows, cardWidth: cardWidth, cardHeight: cardHeight }
    }
  }

  return best || { columns: 1, rows: 1, cardWidth: 0, cardHeight: 0 }
}

function matches(entry, filter) {
  var needle = String(filter || "").trim().toLowerCase()
  if (!needle) return true
  return (entry.title || "").toLowerCase().indexOf(needle) !== -1
    || (entry.appId || "").toLowerCase().indexOf(needle) !== -1
}

function focusWorkspaceCommand(id) {
  if (!isWorkspaceId(id)) return ""
  return 'hl.dsp.focus({ workspace = "' + id + '" })'
}

function focusSpecialCommand(name) {
  if (!isSpecialName(name)) return ""
  return 'hl.dsp.workspace.toggle_special("' + name + '")'
}

function focusWindowCommand(address) {
  if (!isAddress(address)) return ""
  return 'hl.dsp.focus({ window = "address:' + address + '" })'
}

function closeWindowCommand(address) {
  if (!isAddress(address)) return ""
  return 'hl.dsp.window.close({ window = "address:' + address + '" })'
}

function moveWindowCommand(address, workspaceId) {
  if (!isAddress(address) || !isWorkspaceId(workspaceId)) return ""
  return 'hl.dsp.window.move({ window = "address:' + address + '", workspace = "' + workspaceId
    + '", follow = false })'
}

function moveWindowToSpecialCommand(address, name) {
  if (!isAddress(address) || !isSpecialName(name)) return ""
  return 'hl.dsp.window.move({ window = "address:' + address + '", workspace = "special:' + name
    + '", follow = false })'
}
