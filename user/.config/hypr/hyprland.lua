-- ─────────────────────────────────────────────────
-- Hyprland Configuration — archcore
-- RTX 5070 (DP-5, 3440x1440) + AMD iGPU (DP-3, 3840x2160)
-- ─────────────────────────────────────────────────
--
-- File layout:
-- - monitors: physical display arrangement and refresh rates
-- - environment: Wayland / NVIDIA compatibility knobs
-- - look and feel: gaps, opacity, blur, animation
-- - keybindings: app launch, workspace movement, screenshots, media keys
-- - window/workspace rules: force specific apps onto specific monitors/workspaces

-- The portrait display scans out on AMD while NVIDIA renders the desktop.
-- Use implicit synchronization for cross-GPU buffers after DPMS wake.
-- Aquamarine caches this setting; log out/in after first applying it.
hl.env("AQ_MGPU_NO_EXPLICIT", "1")
hl.env("AQ_FORCE_LINEAR_BLIT", "0")

--###############
--## MONITORS ###
--###############

-- Ultrawide main display.
-- Coordinates start at 0x0 because every other monitor is positioned relative to this one.
hl.monitor({ ["output"] = "DP-5", ["mode"] = "3440x1440@159.96", ["position"] = "0x0", ["scale"] = 1.0 })

-- Vertical 4K side monitor.
-- `transform, 3` means rotate 270 degrees.
-- Use exact 5/3 scale so the rotated logical size is exactly 1296x2304.
-- x=-1296 is Hyprland's auto-left placement: adjacent with no gap or overlap.
hl.monitor({ ["output"] = "DP-3", ["mode"] = "3840x2160@60", ["position"] = "-1296x0", ["scale"] = 1.666667, ["transform"] = 3, ["vrr"] = 0, ["bitdepth"] = 8, ["cm"] = "srgb" })

-- Fallback for any other/hotplugged monitor
hl.monitor({ ["output"] = "", ["mode"] = "preferred", ["position"] = "auto", ["scale"] = 1 })

-- hyprmoncfg writes the active monitor profile here.
-- Keep the static monitor lines above as a fallback; this sourced file can override them
-- when a saved profile or the daemon applies a layout.
--##################
--## MY PROGRAMS ###
--##################

hl.layer_rule({ ["name"] = "migrated-1", ["blur"] = true, ["match"] = { ["namespace"] = "waybar" } })
hl.layer_rule({ ["name"] = "migrated-2", ["ignore_alpha"] = 0, ["match"] = { ["namespace"] = "waybar" } })
hl.layer_rule({ ["name"] = "workspace-strip-blur", ["blur"] = true, ["match"] = { ["namespace"] = "waybar-workspaces" } })
hl.layer_rule({ ["name"] = "workspace-strip-alpha", ["ignore_alpha"] = 0, ["match"] = { ["namespace"] = "waybar-workspaces" } })
hl.layer_rule({ ["name"] = "migrated-3", ["blur"] = true, ["match"] = { ["namespace"] = "rofi" } })
hl.layer_rule({ ["name"] = "migrated-4", ["ignore_alpha"] = 0, ["match"] = { ["namespace"] = "rofi" } })
hl.layer_rule({ ["name"] = "migrated-5", ["blur"] = true, ["match"] = { ["namespace"] = "hyprlock" } })
hl.layer_rule({ ["name"] = "migrated-6", ["ignore_alpha"] = 0, ["match"] = { ["namespace"] = "hyprlock" } })

--############################
--## ENVIRONMENT VARIABLES ###
--############################

-- NVIDIA-on-Wayland compatibility flags.
-- These make Electron/VA-API/GBM and GL stacks choose the discrete NVIDIA path consistently.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("NVD_BACKEND", "direct")

-- Toolkit/session hints.
-- These tell GTK/Qt/Mozilla/Electron to prefer native Wayland where possible.
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "Breeze")
hl.env("GTK_THEME", "Adwaita:dark")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Cursor theme shared by both XWayland and native Hyprland cursor handling.
hl.env("XCURSOR_THEME", "macOS")
hl.env("HYPRCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")

hl.config({ ["cursor"] = { ["no_hardware_cursors"] = true } })

--################
--## AUTOSTART ###
--################

-- Session startup itself is centralized in `scripts/session-start.sh`.
-- Keep most launch ordering there instead of stacking many `exec-once` lines in this file.
-- exec-once = hyprctl output create headless SUNSHINE (disabled - causes race condition with Sunshine)
-- Notification daemon (swaync replaces dunst)
-- exec-once = nm-applet --indicator  # disabled — no tray icon needed
-- Clipboard: cliphist (persistent, with large item limit to handle ~1GB history)
-- EWW widget daemon
-- Focus tracking daemon (digital well-being)
-- TUI Dashboard on secondary display (delayed to let other apps settle)

--####################
--## LOOK AND FEEL ###
--####################

-- Inner/outer gaps are the spaces between windows and between windows + screen edges.
-- Keep side-by-side tiled windows just a touch tighter without collapsing the layout.
hl.config({ ["general"] = { ["gaps_in"] = 2 } })
hl.config({ ["general"] = { ["gaps_out"] = 4 } })

-- Border size and colors define focused vs unfocused window outlines.
hl.config({ ["general"] = { ["border_size"] = 0 } })
hl.config({ ["general"] = { ["col"] = { ["active_border"] = { colors = {"rgba(33ccff88)", "rgba(00ff9988)"}, angle = 45 } } } })
hl.config({ ["general"] = { ["col"] = { ["inactive_border"] = "rgba(59595944)" } } })
hl.config({ ["general"] = { ["resize_on_border"] = true } })
hl.config({ ["general"] = { ["allow_tearing"] = false } })

-- `dwindle` is the tiling algorithm currently used for normal windows.
hl.config({ ["general"] = { ["layout"] = "dwindle" } })

-- Opacity only affects non-fullscreen windows. Fullscreen remains fully opaque.
hl.config({ ["decoration"] = { ["rounding"] = 10 } })
hl.config({ ["decoration"] = { ["rounding_power"] = 2 } })
-- Push non-fullscreen windows into visibly translucent territory so the blur actually reads.
hl.config({ ["decoration"] = { ["active_opacity"] = 0.95 } })
hl.config({ ["decoration"] = { ["inactive_opacity"] = 0.75 } })
hl.config({ ["decoration"] = { ["fullscreen_opacity"] = 1.0 } })

-- Shadow is intentionally subtle because blur/opacities already provide depth.
hl.config({ ["decoration"] = { ["shadow"] = { ["enabled"] = true } } })
hl.config({ ["decoration"] = { ["shadow"] = { ["range"] = 8 } } })
hl.config({ ["decoration"] = { ["shadow"] = { ["render_power"] = 3 } } })
hl.config({ ["decoration"] = { ["shadow"] = { ["color"] = "rgba(1a1a1aee)" } } })

-- Blur strength controls the "frosted glass" effect on translucent windows/layers.
hl.config({ ["decoration"] = { ["blur"] = { ["enabled"] = true } } })
-- Stronger blur keeps the wallpaper from bleeding through as hard edges.
hl.config({ ["decoration"] = { ["blur"] = { ["size"] = 10 } } })
hl.config({ ["decoration"] = { ["blur"] = { ["passes"] = 2 } } })
hl.config({ ["decoration"] = { ["blur"] = { ["new_optimizations"] = true } } })
hl.config({ ["decoration"] = { ["blur"] = { ["vibrancy"] = 0.6 } } })

hl.config({ ["animations"] = { ["enabled"] = true } })

hl.curve("easeOutQuart", { type = "bezier", points = { {0.25, 1}, {0.5, 1} } })
hl.curve("easeOutCubic", { type = "bezier", points = { {0.33, 1}, {0.68, 1} } })
hl.curve("easeInCubic", { type = "bezier", points = { {0.32, 0}, {0.67, 0} } })
hl.curve("smooth", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.curve("gentleOvershot", { type = "bezier", points = { {0.16, 1}, {0.3, 1.08} } })

hl.animation({ ["leaf"] = "global", ["enabled"] = true, ["speed"] = 1, ["bezier"] = "default" })

hl.animation({ ["leaf"] = "border", ["enabled"] = true, ["speed"] = 5, ["bezier"] = "easeOutQuart" })
hl.animation({ ["leaf"] = "windows", ["enabled"] = true, ["speed"] = 4, ["bezier"] = "smooth" })
hl.animation({ ["leaf"] = "windowsIn", ["enabled"] = true, ["speed"] = 4, ["bezier"] = "smooth", ["style"] = "popin 82%" })
hl.animation({ ["leaf"] = "windowsOut", ["enabled"] = true, ["speed"] = 3, ["bezier"] = "easeInCubic", ["style"] = "popin 82%" })

hl.animation({ ["leaf"] = "fadeIn", ["enabled"] = true, ["speed"] = 3, ["bezier"] = "easeOutCubic" })
hl.animation({ ["leaf"] = "fadeOut", ["enabled"] = true, ["speed"] = 2.5, ["bezier"] = "easeInCubic" })
hl.animation({ ["leaf"] = "fade", ["enabled"] = true, ["speed"] = 3, ["bezier"] = "easeOutCubic" })

hl.animation({ ["leaf"] = "layers", ["enabled"] = true, ["speed"] = 4, ["bezier"] = "smooth" })
hl.animation({ ["leaf"] = "layersIn", ["enabled"] = true, ["speed"] = 4, ["bezier"] = "smooth", ["style"] = "fade" })
hl.animation({ ["leaf"] = "layersOut", ["enabled"] = true, ["speed"] = 3, ["bezier"] = "easeInCubic", ["style"] = "fade" })

hl.animation({ ["leaf"] = "fadeLayersIn", ["enabled"] = true, ["speed"] = 3, ["bezier"] = "easeOutCubic" })
hl.animation({ ["leaf"] = "fadeLayersOut", ["enabled"] = true, ["speed"] = 2.5, ["bezier"] = "easeInCubic" })

hl.animation({ ["leaf"] = "workspaces", ["enabled"] = true, ["speed"] = 3.5, ["bezier"] = "smooth", ["style"] = "slide" })

-- Hyprland 0.55 removed the old dwindle:pseudotile config key.
-- Keep pseudo control on the keybind instead: Command+P still uses the `pseudo` dispatcher.
hl.config({ ["dwindle"] = { ["preserve_split"] = true } })

hl.config({ ["master"] = { ["new_status"] = "master" } })

-- Disable stock Hyprland branding/wallpaper so the session looks custom instead of default.
hl.config({ ["misc"] = {
    ["force_default_wallpaper"] = 0,
    ["disable_hyprland_logo"] = true,
    ["disable_splash_rendering"] = true,
    ["background_color"] = "0x000000",
} })
hl.config({ ["misc"] = { ["disable_hyprland_logo"] = true } })

-- explicit_sync = 1

-- Hyprland 0.55 moved VFR from misc:vfr to debug:vfr.
hl.config({ ["debug"] = { ["vfr"] = true } })

--############
--## INPUT ###
--############

-- Dual keyboard layout without a modifier-only layout toggle.
hl.config({ ["input"] = { ["kb_layout"] = "us,ru" } })
hl.config({ ["input"] = { ["kb_options"] = "altwin:swap_alt_win" } })
hl.config({ ["input"] = { ["follow_mouse"] = 1 } })
hl.config({ ["input"] = { ["sensitivity"] = 0 } })
-- Distinguish a wheel click from a wheel drag on a window.
hl.config({ binds = { drag_threshold = 10 } })
-- Hyprland's native floating-window edge and window snapping.
hl.config({ general = { snap = { enabled = true, monitor_gap = 18, window_gap = 12, respect_gaps = true } } })

hl.config({ ["input"] = { ["touchpad"] = { ["natural_scroll"] = false } } })

-- Bind every absolute tablet tool to the ultrawide. The vendor's saved
-- screen work area alone did not keep its virtual pen and eraser off DP-3.
-- The XP-Pen virtual mouse is relative input and has no tablet output mapping.
hl.device({ name = "ugtablet-deco-01-v3-pen", output = "DP-5" })
-- The v4 driver reports a larger ABS range than it emits in this XWayland
-- session. Measured maximum pen travel is about 119 x 58 mm at 200 units/mm.
hl.device({ name = "xp-pen-pen", output = "DP-5", active_area_size = { 119, 58.3 } })
hl.device({ name = "xp-pen-eraser", output = "DP-5", active_area_size = { 119, 58.3 } })
--##################
--## KEYBINDINGS ###
--##################

-- macOS Keyboard Layout Mapping:
-- - Control (Ctrl) → Ctrl (already standard)
-- - Option (Alt) → Alt
-- - Command (⌘) → Super key
-- All binds use $mainMod = SUPER for Command key behavior


-- Session-start script launches wallpaper, Waybar, Hypridle, startup apps, etc.

--######################
--## APPLICATION KEYS ###
--######################

-- Command+Space = App launcher (macOS Spotlight equivalent)
hl.bind("SUPER + space", hl.dsp.exec_cmd("walker"))

-- Command+T = Open terminal (macOS convention)
hl.bind("SUPER + T", hl.dsp.exec_cmd("ghostty"))

-- Command+N = File manager (new window in macOS, but we'll use for file manager)
hl.bind("SUPER + N", hl.dsp.exec_cmd("dolphin"))

-- Only these shortcuts wake standby. Super+L still locks while awake.
hl.config({ misc = { mouse_move_enables_dpms = false, key_press_enables_dpms = false } })
hl.bind("SUPER + L", hl.dsp.exec_cmd("~/.local/bin/tensor-standby-key super"), { locked = true })
hl.bind("CTRL + L", hl.dsp.exec_cmd("~/.local/bin/tensor-standby-key ctrl"), { locked = true, non_consuming = true })
-- Command+Shift+T = Theme switcher

--#########################
--## WINDOW MANAGEMENT  ###
--#########################

-- Command+Q = Kill focused app
hl.bind("SUPER + Q", hl.dsp.window.close())

-- Command+Shift+Q = Quit Hyprland (dangerous, like Command+Q quits apps in macOS)

-- Command+M = Minimize (Hyprland doesn't have native minimize, hide window instead)

-- Command+F = Fullscreen (macOS equivalent)
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Command+Shift+F = Fullscreen (all monitors)
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Command+C/V/X use native Ghostty shortcuts in terminals and Ctrl+C/V/X in GUI apps.
local function clipboard_shortcut(key)
    return function()
        local window = hl.get_active_window()
        if not window then return end
        if window.class == "com.mitchellh.ghostty" then
            hl.dispatch(hl.dsp.pass({ window = "activewindow" }))
        else
            hl.dispatch(hl.dsp.send_shortcut({ mods = "CTRL", key = key, window = "activewindow" }))
        end
    end
end
hl.bind("SUPER + C", clipboard_shortcut("C"))
hl.bind("SUPER + V", clipboard_shortcut("V"))
hl.bind("SUPER + X", clipboard_shortcut("X"))

-- macOS-style text editing shortcuts
hl.bind("SUPER + left", hl.dsp.send_shortcut({ mods = "", key = "Home", window = "activewindow" }))
hl.bind("SUPER + right", hl.dsp.send_shortcut({ mods = "", key = "End", window = "activewindow" }))
hl.bind("SUPER + A", hl.dsp.send_shortcut({ mods = "CTRL", key = "A", window = "activewindow" }))
hl.bind("SUPER + Z", hl.dsp.send_shortcut({ mods = "CTRL", key = "Z", window = "activewindow" }))

-- macOS-style text selection
hl.bind("SUPER + SHIFT + left", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Home", window = "activewindow" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.send_shortcut({ mods = "SHIFT", key = "End", window = "activewindow" }))

-- Option-style word navigation and deletion
hl.bind("ALT + left", hl.dsp.send_shortcut({ mods = "CTRL", key = "Left", window = "activewindow" }))
hl.bind("ALT + right", hl.dsp.send_shortcut({ mods = "CTRL", key = "Right", window = "activewindow" }))
hl.bind("ALT + SHIFT + left", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "Left", window = "activewindow" }))
hl.bind("ALT + SHIFT + right", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "Right", window = "activewindow" }))
hl.bind("ALT + Backspace", hl.dsp.send_shortcut({ mods = "CTRL", key = "BackSpace", window = "activewindow" }))

-- Redo and close focused window
hl.bind("SUPER + SHIFT + Z", hl.dsp.send_shortcut({ mods = "CTRL + SHIFT", key = "Z", window = "activewindow" }))
hl.bind("SUPER + W", hl.dsp.window.close())



-- Keep floating toggle on Command+Option+V.
hl.bind("SUPER + ALT + V", hl.dsp.window.float({ action = "toggle" }))


--#########################
--## FOCUS NAVIGATION   ###
--#########################

-- Arrow keys for focus navigation

-- Vim keys (hjkl) for focus navigation
hl.bind("SUPER + k", hl.dsp.focus({ direction = "up" }))

--#########################
--## WINDOW MOVEMENT    ###
--#########################

-- Command+Shift+Arrow = Move window
hl.bind("SUPER + ALT + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + ALT + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + ALT + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + ALT + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Command+Shift+hjkl = Move window (vim style)

--#########################
--## WINDOW RESIZING    ###
--#########################

-- Control+Command+Arrow = Resize window

--#########################
--## WORKSPACE KEYS     ###
--#########################

-- Command+1-9 = Switch workspace (macOS Mission Control alternative)
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = "4" }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = "5" }))
hl.bind("SUPER + 6", hl.dsp.focus({ workspace = "6" }))
hl.bind("SUPER + 7", hl.dsp.focus({ workspace = "7" }))
hl.bind("SUPER + 8", hl.dsp.focus({ workspace = "8" }))
hl.bind("SUPER + 9", hl.dsp.focus({ workspace = "9" }))

-- Command+Shift+1-9 = Move window to workspace
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1", follow = true }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = "2", follow = true }))
hl.bind("SUPER + ALT + SHIFT + 3", hl.dsp.window.move({ workspace = "3", follow = true }))
hl.bind("SUPER + ALT + SHIFT + 4", hl.dsp.window.move({ workspace = "4", follow = true }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = "5", follow = true }))
hl.bind("SUPER + SHIFT + 6", hl.dsp.window.move({ workspace = "6", follow = true }))
hl.bind("SUPER + SHIFT + 7", hl.dsp.window.move({ workspace = "7", follow = true }))
hl.bind("SUPER + SHIFT + 8", hl.dsp.window.move({ workspace = "8", follow = true }))
hl.bind("SUPER + SHIFT + 9", hl.dsp.window.move({ workspace = "9", follow = true }))

-- Command+Tab = Next workspace (macOS Command+Tab app switcher equivalent)
hl.bind("SUPER + Tab", function()
    hl.dispatch(hl.dsp.focus({ monitor = "DP-5" }))
    hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
end)
hl.bind("SUPER + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.focus({ monitor = "DP-5" }))
    hl.dispatch(hl.dsp.focus({ workspace = "m-1" }))
end)
--#########################
--## SCREENSHOT & PASTE ###
--#########################

-- Print = region screenshot with grim + slurp.
-- Screenshots are saved to ~/screenshots as "Screenshot YYYY-MM-DD at H.MM.SS AM.png".
hl.bind("Print", hl.dsp.exec_cmd("bash -lc 'mkdir -p \"$HOME/screenshots\"; grim -g \"$(slurp)\" \"$HOME/screenshots/$(date \"+Screenshot %Y-%m-%d at %-I.%M.%S %p\").png\"'"))
hl.bind("SUPER + SHIFT + 3", hl.dsp.exec_cmd("bash -lc 'mkdir -p \"$HOME/screenshots\"; grim \"$HOME/screenshots/$(date \"+Screenshot %Y-%m-%d at %-I.%M.%S %p\").png\"'"))
hl.bind("SUPER + SHIFT + 4", hl.dsp.exec_cmd("bash -lc 'mkdir -p \"$HOME/screenshots\"; grim -g \"$(slurp)\" \"$HOME/screenshots/$(date \"+Screenshot %Y-%m-%d at %-I.%M.%S %p\").png\"'"))

-- Command+Shift+V = Clipboard history paste (using cliphist and wofi)
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu -p \"Clipboard\" | cliphist decode | wl-copy"))

-- Command+Backspace = delete from cursor to start-of-line (Ctrl+U)
hl.bind("SUPER + Backspace", hl.dsp.exec_cmd("wtype -M ctrl -k u -m ctrl"))

--#########################
--## MOUSE BINDINGS     ###
--#########################

-- Super + right mouse button resizes the focused window.
-- Left-drag move is intentionally absent to avoid conflicts with fullscreen apps/games.
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { ["mouse"] = true })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { ["mouse"] = true })

--#########################
--## MEDIA KEYS         ###
--#########################

-- Volume keys show a top-screen OSD and control the current default PipeWire sink.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise --max-volume 100"), { ["repeating"] = true, ["locked"] = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower --max-volume 100"), { ["repeating"] = true, ["locked"] = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle --max-volume 100"), { ["repeating"] = true, ["locked"] = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), { ["repeating"] = true, ["locked"] = true })

-- Mac keyboard function-row fallback. Keep these explicit because this keyboard reports F11/F12.
hl.bind("F11", hl.dsp.exec_cmd("swayosd-client --output-volume lower --max-volume 100"), { ["repeating"] = true, ["locked"] = true })
hl.bind("F12", hl.dsp.exec_cmd("swayosd-client --output-volume raise --max-volume 100"), { ["repeating"] = true, ["locked"] = true })

-- Playback control
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { ["locked"] = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { ["locked"] = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { ["locked"] = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { ["locked"] = true })


-- Function keys: F1-F12

local function bind_cmd(key, cmd, flags)
    hl.unbind(key)
    hl.bind(key, hl.dsp.exec_cmd(cmd), flags or {})
end

-- F1: Brightness UP
bind_cmd("F1", "~/.local/bin/brightness down")
bind_cmd("XF86MonBrightnessUp", "~/.local/bin/brightness down")

-- F2: Brightness DOWN
bind_cmd("F2", "~/.local/bin/brightness up")
bind_cmd("XF86MonBrightnessDown", "~/.local/bin/brightness up")

-- F3: Mission Control via Hyprspace
-- Requires the Hyprspace plugin.
hl.unbind("F3")
hl.bind("F3", function()
    hl.plugin.overview.toggle("all")
end)

-- F4: Application search
bind_cmd("F4", "walker")
bind_cmd("XF86Search", "walker")


-- F6: Toggle microphone mute
local mic = "swayosd-client --input-volume mute-toggle"
bind_cmd("F6", mic)

-- F7: Previous track
local prev = "swayosd-client --playerctl prev"
bind_cmd("F7", prev)
bind_cmd("XF86AudioPrev", prev)

-- F8: Play / Pause
local toggle = "swayosd-client --playerctl play-pause"
bind_cmd("F8", toggle)
bind_cmd("XF86AudioPlay", toggle)
bind_cmd("XF86AudioPause", toggle)

-- F9: Next track
local next = "swayosd-client --playerctl next"
bind_cmd("F9", next)
bind_cmd("XF86AudioNext", next)

-- F10: Mute speaker audio
local mute = "swayosd-client --output-volume mute-toggle --max-volume 100"
bind_cmd("F10", mute)
bind_cmd("XF86AudioMute", mute)

-- F11: Volume DOWN, repeating
local down = "swayosd-client --output-volume lower --max-volume 100"
bind_cmd("F11", down, { repeating = true })
bind_cmd("XF86AudioLowerVolume", down, { repeating = true })

-- F12: Volume UP, max 100%, repeating
local up = "swayosd-client --output-volume raise --max-volume 100"
bind_cmd("F12", up, { repeating = true })
bind_cmd("XF86AudioRaiseVolume", up, { repeating = true })
--#########################
--## LAYER RULES        ###
--#########################

-- Do not blur the whole Waybar layer. The layer spans the full monitor width, so compositor
-- layer blur creates a visible full-width strip behind the three bubbles.
-- The bubbles themselves are rendered by Waybar CSS.
-- layerrule = match:namespace ^(waybar)$, blur 1, ignore_alpha 0.01

--#############################
--## WINDOWS AND WORKSPACES ###
--#############################

-- Ignore maximize requests from apps that assume a traditional stacking WM.
hl.window_rule({ ["name"] = "migrated-8", ["suppress_event"] = "maximize", ["match"] = { ["class"] = ".*" } })
hl.window_rule({ ["name"] = "migrated-9", ["no_initial_focus"] = true, ["match"] = { ["class"] = "^$", ["title"] = "^$", ["xwayland"] = true, ["float"] = true, ["fullscreen"] = false, ["pin"] = false } })

-- Force utility dialogs to float instead of joining the tiling layout.
hl.window_rule({ ["name"] = "migrated-10", ["float"] = true, ["match"] = { ["class"] = "^(pavucontrol)$" } })
hl.window_rule({ ["name"] = "migrated-11", ["float"] = true, ["match"] = { ["class"] = "^(nm-connection-editor)$" } })
hl.window_rule({ ["name"] = "migrated-12", ["float"] = true, ["match"] = { ["class"] = "^(nwg-look)$" } })
hl.window_rule({ ["name"] = "migrated-13", ["float"] = true, ["match"] = { ["title"] = "^(Open File)$" } })
hl.window_rule({ ["name"] = "migrated-14", ["float"] = true, ["match"] = { ["title"] = "^(Save As)$" } })

--#########################
--## WORKSPACE ASSIGNMENTS ##
--#########################

-- Workspace routing:
-- - 1..5 live on the ultrawide
-- - 10 lives on the vertical 4K monitor
-- - `default:true` keeps unassigned/new workspaces on the ultrawide by default
hl.workspace_rule({ ["workspace"] = "1", ["monitor"] = "DP-5", ["default"] = true })
hl.workspace_rule({ ["workspace"] = "2", ["monitor"] = "DP-5" })
hl.workspace_rule({ ["workspace"] = "3", ["monitor"] = "DP-5" })
hl.workspace_rule({ ["workspace"] = "4", ["monitor"] = "DP-5" })
hl.workspace_rule({ ["workspace"] = "5", ["monitor"] = "DP-5" })
hl.workspace_rule({ ["workspace"] = "10", ["monitor"] = "DP-3", ["default"] = true, ["persistent"] = true })

-- Headless outputs for Sunshine remote streaming (modeline for 1800x1169@60Hz MacBook Pro 14")
-- These rules apply to any headless output created via sunshine-remote.sh

-- Other app windows default to workspace 5; specific rules below override this.
hl.window_rule({
    name = "other-apps-workspace",
    match = {
        class = "negative:com[.]moonlight_stream[.]Moonlight"
    },
    workspace = "5 silent",
    monitor = "DP-5"
})

hl.window_rule({
    name = "moonlight-workspace",
    match = {
        class = "com[.]moonlight_stream[.]Moonlight"
    },
    workspace = "9 silent",
    monitor = "DP-5"
})
-- App placement rules for startup + recurring windows.
hl.window_rule({ ["name"] = "migrated-22", ["workspace"] = "10 silent", ["monitor"] = "DP-3", ["match"] = { ["class"] = "^(com\\.btop\\.term)$" } })
hl.window_rule({ ["name"] = "migrated-23", ["workspace"] = "1 silent", ["match"] = { ["class"] = "^(com\\.mitchellh\\.ghostty)$" } })
hl.window_rule({ ["name"] = "migrated-24", ["workspace"] = "3 silent", ["match"] = { ["class"] = "^(zen)$" } })
hl.window_rule({ ["name"] = "migrated-25", ["workspace"] = "2 silent", ["match"] = { ["class"] = "^(obsidian|md\\.obsidian\\.Obsidian)$" } })
hl.window_rule({ name = "obsidian-fullscreen", match = { class = "^(obsidian|md\\.obsidian\\.Obsidian)$" }, fullscreen = true })
hl.window_rule({ ["name"] = "migrated-26", ["workspace"] = "4 silent", ["fullscreen"] = true, ["match"] = { ["class"] = "steam" } })
-- Steam child game windows open on workspace 5 and force fullscreen/immediate mode.
hl.window_rule({ ["name"] = "migrated-27", ["workspace"] = "5 silent", ["match"] = { ["class"] = "^(steam_app_.*)$" } })
hl.window_rule({ ["name"] = "migrated-28", ["fullscreen"] = true, ["match"] = { ["class"] = "^(steam_app_.*)$" } })
hl.window_rule({ ["name"] = "migrated-29", ["immediate"] = true, ["match"] = { ["class"] = "^(steam_app_.*)$" } })
hl.window_rule({ ["name"] = "migrated-30", ["workspace"] = "5 silent", ["match"] = { ["class"] = "^(PenTablet)$" } })
hl.window_rule({ name = "xppen-floating", match = { class = "^(PenTablet)$" }, float = true, size = "900 650", center = true })

-- Let modal child windows follow their parent workspace and retain their own size.
hl.window_rule({ name = "child-dialog-floating", match = { modal = true }, workspace = "unset", float = true, center = true })

-- Browser child windows (including extensions) should float over Zen, not take a tile.
-- Adapted from Hyprland's official "Float browsers' extension windows" snippet.
hl.on("window.open", function(w)
    if w.class ~= "zen" or w.initial_title ~= "Zen Browser" then return end
    if #hl.get_windows({ class = "zen" }) <= 1 then return end
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
    local sub
    sub = hl.on("window.title", function(tw)
        if tw.address ~= w.address then return end
        if tw.title == "" or tw.title == "Zen Browser" or tw.title == "about:blank" then return end
        sub:remove()
        if tw.title:match("^Extension:") then
            hl.dispatch(hl.dsp.window.resize({ x = 600, y = 650, window = tw }))
            hl.dispatch(hl.dsp.window.center({ window = tw }))
            hl.dispatch(hl.dsp.focus({ window = tw }))
        else
            hl.dispatch(hl.dsp.window.float({ action = "disable", window = tw }))
        end
    end)
end)

-- Dashboard/utility placement helpers.
hl.window_rule({ ["name"] = "migrated-31", ["workspace"] = "5 silent", ["match"] = { ["class"] = "^(tui\\..*)$" } })
hl.window_rule({ ["name"] = "migrated-32", ["workspace"] = "5 silent", ["match"] = { ["class"] = "^(org.openrgb.OpenRGB)$" } })
hl.window_rule({ name = "openrgb-floating", match = { class = "^(org\\.openrgb\\.OpenRGB)$" }, float = true, size = "900 650", center = true })

-- Keep utility windows movable, unpinned and free of compositor decorations.
-- Override the general Steam fullscreen rule for the actual picker only;
-- Wallpaper Engine's blank Wine desktop window has an empty title.
hl.window_rule({ name = "wallpaper-picker-floating", match = { class = "^(steam_app_431960)$", initial_title = "^(Wallpaper UI)$" }, fullscreen = false, float = true, pin = false, size = "1400 900", center = true, decorate = false, border_size = 0, no_shadow = true })
hl.window_rule({ name = "blueman-manager-floating", match = { class = "^(blueman-manager)$" }, float = true, pin = false, size = "900 650", center = true, decorate = false, border_size = 0, no_shadow = true })
hl.window_rule({ name = "solaar-floating", match = { class = "^(solaar)$" }, float = true, pin = false, size = "900 650", center = true, decorate = false, border_size = 0, no_shadow = true })

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/scripts/audio-start.sh")
    hl.exec_cmd("~/.config/hypr/scripts/session-start.sh")
end)

hl.config({ render = { cm_auto_hdr = 0 } })

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
