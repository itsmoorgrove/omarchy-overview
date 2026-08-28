.pragma library

var BEGIN_MARKER = "-- omarchy-overview:begin"
var END_MARKER = "-- omarchy-overview:end"

var MODIFIER_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"]

var MODMASK = { SHIFT: 1, CTRL: 4, ALT: 8, SUPER: 64 }

var DIGIT_CODES = { "1": 10, "2": 11, "3": 12, "4": 13, "5": 14, "6": 15, "7": 16, "8": 17, "9": 18, "0": 19 }

var KEY_TOKENS = [
  "Tab", "space", "Return", "Escape", "BackSpace", "Delete", "Insert",
  "Home", "End", "Prior", "Next", "Left", "Right", "Up", "Down", "Print",
  "comma", "period", "slash", "semicolon", "apostrophe", "backslash",
  "bracketleft", "bracketright", "minus", "equal", "grave",
  "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
]

var KEY_LABELS = {
  space: "Space", Return: "Enter", BackSpace: "Backspace", Prior: "PageUp", Next: "PageDown",
  comma: ",", period: ".", slash: "/", semicolon: ";", apostrophe: "'", backslash: "\\",
  bracketleft: "[", bracketright: "]", minus: "-", equal: "=", grave: "`"
}

function isKeyToken(token) {
  return KEY_TOKENS.indexOf(String(token)) !== -1
}

function isModifier(token) {
  return MODIFIER_ORDER.indexOf(String(token)) !== -1
}

function sortModifiers(modifiers) {
  var out = []
  for (var i = 0; i < MODIFIER_ORDER.length; i++) {
    if (modifiers.indexOf(MODIFIER_ORDER[i]) !== -1) out.push(MODIFIER_ORDER[i])
  }
  return out
}

function combo(modifiers, key) {
  if (!isKeyToken(key)) return ""
  var mods = sortModifiers(modifiers || [])
  if (mods.length === 0) return ""
  return mods.concat([key]).join(" + ")
}

function parse(text) {
  var parts = String(text || "").split("+")
  var modifiers = []
  var key = ""

  for (var i = 0; i < parts.length; i++) {
    var token = parts[i].replace(/^\s+|\s+$/g, "")
    if (!token) return null
    if (i === parts.length - 1) key = token
    else if (isModifier(token.toUpperCase())) modifiers.push(token.toUpperCase())
    else return null
  }

  if (!isKeyToken(key) || modifiers.length === 0) return null
  return { modifiers: sortModifiers(modifiers), key: key }
}

function isValid(text) {
  return parse(text) !== null
}

function label(text) {
  var parsed = parse(text)
  if (!parsed) return ""
  var key = KEY_LABELS[parsed.key] || parsed.key
  return parsed.modifiers.concat([key]).join(" + ")
}

function hyprCombo(text) {
  var parsed = parse(text)
  if (!parsed) return ""
  var code = DIGIT_CODES[parsed.key]
  var key = code === undefined ? parsed.key : "code:" + code
  return parsed.modifiers.concat([key]).join(" + ")
}

function maskModifiers(mask) {
  var value = Number(mask) || 0
  var out = []
  for (var i = 0; i < MODIFIER_ORDER.length; i++) {
    var name = MODIFIER_ORDER[i]
    if (value & MODMASK[name]) out.push(name)
  }
  return out
}

function sameKey(left, right) {
  return String(left || "").toLowerCase() === String(right || "").toLowerCase()
}

function conflict(binds, text) {
  var parsed = parse(text)
  if (!parsed || !Array.isArray(binds)) return null

  var code = DIGIT_CODES[parsed.key]
  var wanted = parsed.modifiers.join(" + ")

  for (var i = 0; i < binds.length; i++) {
    var bind = binds[i]
    if (!bind || bind.submap) continue
    if (maskModifiers(bind.modmask).join(" + ") !== wanted) continue

    var key = String(bind.key || "")
    var matches = sameKey(key, parsed.key)
      || (code !== undefined && sameKey(key, "code:" + code))
      || (code !== undefined && Number(bind.keycode) === code)
    if (!matches) continue

    return String(bind.description || "an existing binding")
  }

  return null
}

function stripBlock(text) {
  var source = String(text || "")
  var start = source.indexOf(BEGIN_MARKER)
  if (start === -1) return source

  var end = source.indexOf(END_MARKER, start)
  if (end === -1) return source.slice(0, start).replace(/\n+$/, "\n")

  var head = source.slice(0, start)
  var tail = source.slice(end + END_MARKER.length)
  return (head.replace(/\n+$/, "\n") + tail.replace(/^\n+/, "")).replace(/\n{3,}/g, "\n\n")
}

function readBlock(text) {
  var source = String(text || "")
  var start = source.indexOf(BEGIN_MARKER)
  if (start === -1) return ""

  var end = source.indexOf(END_MARKER, start)
  var block = end === -1 ? source.slice(start) : source.slice(start, end)
  var match = block.match(/o\.bind\("([^"\\]{1,64})"/)
  if (!match) return ""

  var parsed = parse(match[1])
  return parsed ? combo(parsed.modifiers, parsed.key) : ""
}

function buildBlock(text, description, command) {
  var hypr = hyprCombo(text)
  if (!hypr) return ""

  return BEGIN_MARKER + "\n"
    + 'hl.unbind("' + hypr + '")\n'
    + 'o.bind("' + hypr + '", "' + description + '", "' + command + '")\n'
    + END_MARKER + "\n"
}

function withBinding(text, combination, description, command) {
  var stripped = stripBlock(text).replace(/\n+$/, "")
  var block = buildBlock(combination, description, command)
  if (!block) return null
  return (stripped ? stripped + "\n\n" : "") + block
}

function withoutBinding(text) {
  return stripBlock(text).replace(/\n+$/, "") + "\n"
}
