# Caps Lock Remap — Omarchy bar widget

Pick what the Caps Lock key does from a menu on the bar. Every choice comes
with a line saying what it does, applies the moment you click it, and survives
a restart.

![The panel, listing the Caps Lock mappings](preview.png)

Each mapping is a stock XKB option that Hyprland hands to the keymap, so there
is no remapping daemon. No Hyprland config file is edited: the widget sets the
option on the running compositor and keeps the choice as its own bar setting.

## Install

```sh
omarchy plugin add https://github.com/zamia/omarchy-caps-lock-remap.git --enable
```

The ⇪ icon lands in the right section of the bar. Move it from the panel
itself (see below) or with:

```sh
omarchy bar move io.github.zamia.caps-lock-remap --section left
```

## Usage

Click the icon, then click a mapping. The chosen one is ticked, and hovering
the icon names what Caps Lock does right now.

The first row, **Use my Hyprland config**, is the default: the widget changes
nothing and Caps Lock does whatever `kb_options` in your own config says. Pick
it again at any time to hand the key back.

| Mapping | Caps Lock becomes | XKB option |
|---|---|---|
| Caps Lock | The normal key | `caps:capslock` |
| Control | An extra Ctrl | `ctrl:nocaps` |
| Control, Shift for Caps Lock | An extra Ctrl; Shift + Caps Lock still locks uppercase | `caps:ctrl_shifted_capslock` |
| Escape | An extra Esc | `caps:escape` |
| Escape, Shift for Caps Lock | An extra Esc; Shift + Caps Lock still locks uppercase | `caps:escape_shifted_capslock` |
| Compose | The Compose key (Omarchy's default) | `compose:caps` |
| Backspace | An extra Backspace | `caps:backspace` |
| Super | An extra Super | `caps:super` |
| Swap with Escape | Esc, and the Esc key becomes Caps Lock | `caps:swapescape` |
| Swap with Left Control | Ctrl, and Left Ctrl becomes Caps Lock | `ctrl:swapcaps` |
| Disabled | Nothing | `caps:none` |

The row at the bottom of the panel moves the icon between the left, center,
and right sections of the bar.

In the panel:

| Key | Does |
|---|---|
| `↑` `↓`, `j` `k` | Move the cursor |
| `←` `→`, `h` `l` | Choose a section on the icon-position row |
| `enter`, `space` | Select the highlighted row |
| `esc` | Close |

The panel header shows what Hyprland is using right now, not what was last
clicked, so it stays correct when `kb_options` changes some other way.

## What it changes on your system

Nothing in your Hyprland config, ever. `hyprland.lua`, `input.lua`, and the
rest of `~/.config/hypr/` are only read by Hyprland, never written by this
widget.

- **The choice** is saved as this widget's own setting (`mapping`) on its entry
  in `~/.config/omarchy/shell.json`, the file where bar widgets keep their
  settings.
- **The mapping** is set on the running compositor with `hyprctl eval`. A
  config reload puts your own `kb_options` back, so the widget sets it again
  after every reload and when the bar starts.

Only the option that binds Caps Lock is swapped. Any other option in your
`kb_options` (layout switching, for example) is kept as it is.

## IPC

```sh
omarchy-shell io.github.zamia.caps-lock-remap toggle
omarchy-shell io.github.zamia.caps-lock-remap set caps:escape
omarchy-shell io.github.zamia.caps-lock-remap set config
omarchy-shell io.github.zamia.caps-lock-remap current
```

`set` takes any option from the table above, or `config` to hand the key back,
so a Hyprland bind can switch mapping without opening the menu.

## Limits

- The widget applies the mapping, so it needs to be on the bar. For the moment
  between login and the bar loading, and for an instant after a config reload,
  Caps Lock is whatever your own config says.
- XKB has no tap-versus-hold, so "Esc on tap, Ctrl on hold" is not possible
  here. That needs a remapper such as keyd or kanata.
- A `kb_options` set for one keyboard with `hl.device` wins over this for
  that keyboard.
- Hyprland's Lua config is required, because the option is set through
  `hl.config`. The legacy `hyprland.conf` is not supported.

## Requirements

Omarchy 4 with the Omarchy shell. It uses `hyprctl`, which Omarchy ships. No
other dependencies.

## Removal

```sh
omarchy plugin remove io.github.zamia.caps-lock-remap
hyprctl reload
```

Removing the plugin removes its bar entry, and the saved choice with it. The
reload (or your next login) returns Caps Lock to your own config. Nothing else
is left behind.

## License

MIT. See [LICENSE](LICENSE).
