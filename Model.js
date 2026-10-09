.pragma library

// The mapping catalogue. Every entry is one stock XKB option, so nothing here
// needs a remapping daemon: Hyprland hands the option to xkbcommon and the
// keymap does the rest. That is also the limit — XKB has no tap-versus-hold,
// so "Esc on tap, Ctrl on hold" cannot be offered from this list.
var MAPPINGS = [
  {
    option: "caps:capslock",
    label: "Caps Lock",
    detail: "The normal key: letters stay uppercase until pressed again"
  },
  {
    option: "ctrl:nocaps",
    label: "Control",
    detail: "An extra Ctrl key. Caps Lock itself is gone"
  },
  {
    option: "caps:ctrl_shifted_capslock",
    label: "Control, Shift for Caps Lock",
    detail: "An extra Ctrl key. Shift + Caps Lock still locks uppercase"
  },
  {
    option: "caps:escape",
    label: "Escape",
    detail: "An extra Esc key. Caps Lock itself is gone"
  },
  {
    option: "caps:escape_shifted_capslock",
    label: "Escape, Shift for Caps Lock",
    detail: "An extra Esc key. Shift + Caps Lock still locks uppercase"
  },
  {
    option: "compose:caps",
    label: "Compose",
    detail: "Omarchy default. Tap it, then type a sequence: ' e gives é"
  },
  {
    option: "caps:backspace",
    label: "Backspace",
    detail: "An extra Backspace, within reach of the home row"
  },
  {
    option: "caps:super",
    label: "Super",
    detail: "An extra Super key for window and app shortcuts"
  },
  {
    option: "caps:swapescape",
    label: "Swap with Escape",
    detail: "Caps Lock sends Esc, and the Esc key becomes Caps Lock"
  },
  {
    option: "ctrl:swapcaps",
    label: "Swap with Left Control",
    detail: "Caps Lock is Ctrl, and the Left Ctrl key becomes Caps Lock"
  },
  {
    option: "caps:none",
    label: "Disabled",
    detail: "The key does nothing at all"
  }
]

// The first row stands for "no mapping": an empty option means the widget
// leaves Caps Lock to the user's own Hyprland config. Its detail line is
// written by the panel, which knows what that config currently gives.
var FOLLOW_CONFIG = { option: "", label: "Use my Hyprland config", detail: "" }

function rows() {
  return [FOLLOW_CONFIG].concat(MAPPINGS)
}

var SECTIONS = [
  { value: "left", label: "Left" },
  { value: "center", label: "Center" },
  { value: "right", label: "Right" }
]

// Every XKB option that decides what the Caps Lock key does.
var CAPS_PATTERNS = [
  /^caps:/,
  /^ctrl:[a-z_]*caps/,
  /^compose:caps$/,
  /^grp:caps_/,
  /^lv[35]:caps_switch/
]

function bindsCaps(option) {
  for (var i = 0; i < CAPS_PATTERNS.length; i++)
    if (CAPS_PATTERNS[i].test(option)) return true
  return false
}

function tokens(kbOptions) {
  var out = []
  var parts = String(kbOptions || "").split(",")
  for (var i = 0; i < parts.length; i++) {
    var option = parts[i].trim()
    if (option !== "") out.push(option)
  }
  return out
}

function capsOptions(kbOptions) {
  return tokens(kbOptions).filter(bindsCaps)
}

// The option in a kb_options string that binds Caps Lock. An options string
// with none of them leaves the key as XKB ships it, which is plain Caps Lock.
function currentOption(kbOptions) {
  var caps = capsOptions(kbOptions)
  return caps.length > 0 ? caps[0] : "caps:capslock"
}

function satisfies(kbOptions, mapping) {
  var caps = capsOptions(kbOptions)
  return caps.length === 1 && caps[0] === mapping
}

// kb_options with the Caps Lock binding swapped for `mapping`. Every other
// option (layout switching and so on) is kept as it is.
function withMapping(kbOptions, mapping) {
  var kept = tokens(kbOptions).filter(function(option) { return !bindsCaps(option) })
  kept.push(mapping)
  return kept.join(",")
}

// The options string ends up inside a Lua string literal handed to
// `hyprctl eval`, so anything beyond XKB's own alphabet is refused.
function isSafe(kbOptions) {
  return /^[A-Za-z0-9_:+,-]*$/.test(String(kbOptions))
}

// `hyprctl -j getoption input:kb_options` prints {"option":…,"str":…}.
function parseOption(json) {
  try {
    var parsed = JSON.parse(String(json || ""))
    return typeof parsed.str === "string" ? parsed.str : ""
  } catch (e) {
    return ""
  }
}

// The mapping saved on this widget's entry in shell.json. Anything that is
// not one of the offered options counts as no mapping at all; null means the
// file could not be read as JSON, so the caller keeps what it had.
function savedMapping(json, id) {
  try {
    var layout = JSON.parse(String(json || "")).bar.layout
    for (var s = 0; s < SECTIONS.length; s++) {
      var entries = layout[SECTIONS[s].value] || []
      for (var i = 0; i < entries.length; i++) {
        if (!entries[i] || entries[i].id !== id) continue
        var option = String(entries[i].mapping || "")
        return byOption(option) ? option : ""
      }
    }
  } catch (e) {
    return null
  }
  return ""
}

function byOption(option) {
  for (var i = 0; i < MAPPINGS.length; i++)
    if (MAPPINGS[i].option === option) return MAPPINGS[i]
  return null
}

// A mapping set by hand that this list does not offer still gets named,
// rather than the panel pretending nothing is selected.
function labelFor(option) {
  var mapping = byOption(option)
  return mapping ? mapping.label : option
}

// Which bar section holds the widget, read from the bar's layout snapshot.
function sectionOf(layout, id) {
  for (var s = 0; s < SECTIONS.length; s++) {
    var entries = layout ? layout[SECTIONS[s].value] : null
    if (!entries) continue
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if ((entry && typeof entry === "object" ? entry.id : entry) === id) return SECTIONS[s].value
    }
  }
  return ""
}
