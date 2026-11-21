#!/usr/bin/env python3
# Render the existing workspace-strip desktop integration. See workspace-strip.py(1) for source and integration details.
"""Interactive Hyprland workspace strip for Waybar's center pill."""

if __name__ == "__main__":
    import sys as _ops_sys
    if _ops_sys.argv[1:] == ["--help"]:
        print('Render the existing workspace-strip desktop integration.\nUsage: workspace-strip.py \n\nSource: hosts/tensor/files/.config/waybar/workspace-strip.py in ~/ops\nSee man workspace-strip.py for the existing call sites and argument handling.')
        raise SystemExit(0)

import fcntl
import json
import os
import socket
import sys
import subprocess
import threading
import time
from pathlib import Path

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell


STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "waybar-workspaces"
ORDER_FILE = STATE_DIR / "order.json"
LOCK_FILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "waybar-workspace-strip.lock"
OUTPUT = os.environ.get("WAYBAR_PRIMARY_OUTPUT", "")
ICONS = {"1": "", "2": "󱞁", "3": "", "4": "", "9":"",}
TARGET = Gtk.TargetEntry.new("application/x-waybar-workspace", Gtk.TargetFlags.SAME_APP, 0)


def run_hypr(args):
    return subprocess.run(["hyprctl", *args], check=True, capture_output=True, text=True, timeout=3).stdout


def preferred_output(monitors):
    available = [m for m in monitors if m.get("name") != "FALLBACK" and not m.get("disabled")]
    if not available:
        raise RuntimeError("No physical monitor available yet")
    target = next((m for m in available if m.get("name") == OUTPUT), None)
    target = target or next((m for m in available if (m.get("width"), m.get("height")) == (3440, 1440)), None)
    target = target or next((m for m in available if m.get("focused")), available[0])
    return target


def dispatch(expression):
    result = subprocess.run(
        ["hyprctl", "eval", "hl.dispatch(" + expression + ")"],
        capture_output=True, text=True, timeout=3, check=True,
    )
    if "error" in result.stdout.lower():
        raise RuntimeError(result.stdout.strip())


def numeric_key(workspace):
    try:
        return (0, int(workspace.get("id", 0)))
    except (TypeError, ValueError):
        return (1, workspace.get("name", ""))


# workspace-strip interaction pass v2

def merge_visible_order(saved_order, visible_order):
    """Reorder only visible IDs; retain hidden IDs at their saved positions."""
    # GTK drag reorder has unique visible IDs, but reject duplicates defensively.
    visible = list(dict.fromkeys(visible_order))
    visible_ids = set(visible)
    incoming = iter(visible)
    result = []
    for key in saved_order:
        if key in visible_ids:
            result.append(next(incoming))
        else:
            result.append(key)
    result.extend(incoming)
    return list(dict.fromkeys(result))


def next_workspace_id(workspaces):
    used = {ws["id"] for ws in workspaces if isinstance(ws, dict) and type(ws.get("id")) is int and ws["id"] > 0}
    return next(i for i in range(1, 1000) if i not in used and i != 10)


class WorkspaceStrip:
    def __init__(self):
        # workspace-strip quality pass v1
        self._refresh_source = 0
        self._close_event = False
        self._last_refresh_warning = 0.0
        self._previous_occupied_ids = set()
        self._all_workspaces = []
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        self.order = self.load_order()
        self.workspace_by_id = {}
        self.buttons = {}
        self.occupied_ids = set()
        self.fresh_ids = set()
        self.dragging = False
        self.ignore_click_until = 0
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title("Waybar workspaces")
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.window.set_app_paintable(True)
        self.window.set_name("workspace-strip-window")
        self.window.set_size_request(-1, 49)
        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, "waybar-workspaces")
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.TOP, 8)
        GtkLayerShell.set_exclusive_zone(self.window, -1)
        self.select_monitor()

        self.strip = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.strip.set_name("workspaces")
        self.strip.set_halign(Gtk.Align.CENTER)
        self.strip.set_valign(Gtk.Align.CENTER)
        self.add_button = Gtk.Button(label="+")
        self.add_button.set_name("workspace-create")
        self.add_button.set_size_request(32, 33)
        self.add_button.set_valign(Gtk.Align.CENTER)
        self.add_button.set_can_focus(False)
        self.add_button.get_style_context().add_class("workspace-add")
        # Separate compact control with a stable hover target.
        self.add_button.set_tooltip_text("Create workspace")
        self.add_button.connect("clicked", self.create_workspace)
        self.add_button.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK | Gdk.EventMask.POINTER_MOTION_MASK)
        self.add_button.connect("enter-notify-event", self.add_hover, True)
        self.add_button.connect("motion-notify-event", self.add_hover, True)
        self.add_button.connect("leave-notify-event", self.add_hover, False)
        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=7)
        workspace_pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        workspace_pill.get_style_context().add_class("modules-center")
        workspace_pill.add(self.strip)
        outer.pack_start(workspace_pill, False, False, 0)
        outer.pack_start(self.add_button, False, False, 0)
        self.window.add(outer)
        self.install_css()
        self.refresh()
        self.window.show_all()
        self.window.connect("destroy", Gtk.main_quit)

        threading.Thread(target=self.watch_events, daemon=True).start()
        display = Gdk.Display.get_default()
        display.connect("monitor-added", self.monitors_changed)
        display.connect("monitor-removed", self.monitors_changed)
        # DPMS can expose only FALLBACK without a useful later refresh event.
        GLib.timeout_add_seconds(2, self.periodic_refresh)

    def schedule_refresh(self, closed=False):
        self._close_event = self._close_event or bool(closed)
        if not self._refresh_source:
            self._refresh_source = GLib.timeout_add(140, self._flush_refresh)
        return False

    def _flush_refresh(self):
        self._refresh_source = 0
        self.refresh()
        return False

    def periodic_refresh(self):
        if not self._refresh_source:
            self.refresh()
        return True

    def add_hover(self, _widget, _event, visible):
        if not visible and _event.detail == Gdk.NotifyType.INFERIOR:
            return False
        context = self.add_button.get_style_context()
        if visible and not context.has_class("plus-visible"):
            context.add_class("plus-visible")
        elif not visible and context.has_class("plus-visible"):
            context.remove_class("plus-visible")
        return False

    def create_workspace(self, _button):
        workspace_id = next_workspace_id(json.loads(run_hypr(["-j", "workspaces"])))
        self.fresh_ids.add(str(workspace_id))
        dispatch('hl.dsp.focus({monitor=' + json.dumps(self.visible_output) + '})')
        dispatch('hl.dsp.focus({workspace=' + json.dumps(str(workspace_id)) + '})')
        if str(workspace_id) not in self.order:
            self.order.append(str(workspace_id))
            self.save_order()
        self.refresh()

    def workspace_hover(self, button, event, workspace_id, visible):
        if event.detail == Gdk.NotifyType.INFERIOR:
            return False
        context = button.get_style_context()
        if visible:
            button.set_label(workspace_id)
            context.add_class("workspace-number")
        else:
            button.set_label(ICONS.get(workspace_id, "•"))
            context.remove_class("workspace-number")
        return False

    def monitors_changed(self, *_args):
        GLib.timeout_add(350, self.rebind_monitor)

    def rebind_monitor(self):
        self.select_monitor()
        self.refresh()
        return False

    def select_monitor(self):
        display = Gdk.Display.get_default()
        if not display:
            return
        fallback = display.get_monitor_at_point(100, 100)
        try:
            monitors = json.loads(run_hypr(["-j", "monitors"]))
            target = preferred_output(monitors)
            if target:
                scale = target.get("scale", 1)
                fallback = display.get_monitor_at_point(
                    int(target["x"] + target["width"] / scale / 2),
                    int(target["y"] + target["height"] / scale / 2),
                )
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
            pass
        if fallback:
            GtkLayerShell.set_monitor(self.window, fallback)

    def install_css(self):
        shared = Gtk.CssProvider()
        shared.load_from_path(str(Path(__file__).with_name("style.css")))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), shared, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        css = b"""
        window#workspace-strip-window { background: transparent; color: #EAF4FF; }
        #workspaces button { min-width: 30px; min-height: 33px; padding: 0 5px; margin: 0 1px; }
        #workspaces button label { font-size: 22px; }
        #workspaces button.workspace-number label { font-size: 16px; font-weight: 600; }
        /* Drop indicators use inset shadows to avoid changing button dimensions. */
        #workspaces button.dragging { opacity: 0.50; }
        #workspaces button.drop-before {
          box-shadow: inset 4px 0 0 rgba(166,205,255,0.95);
          background: rgba(166,205,255,0.11);
        }
        #workspaces button.drop-after {
          box-shadow: inset -4px 0 0 rgba(166,205,255,0.95);
          background: rgba(166,205,255,0.11);
        }
        #workspace-strip-window .modules-center { margin: 0; }
        button#workspace-create {
          min-width: 30px; min-height: 31px; padding: 0; margin: 0;
          border-radius: 16px; border: 1px solid rgba(255,255,255,0.14);
          background: rgba(190,190,190,0.10); color: #EAF4FF; box-shadow: none;
        }
        button#workspace-create label { font-size: 20px; font-weight: 400; opacity: 0.65; }
        button#workspace-create:hover { background: rgba(255,255,255,0.17); border-color: rgba(255,255,255,0.30); }
        button#workspace-create.plus-visible label { opacity: 1; }
        popover.workspace-confirm { color: #EAF4FF; }
        popover.workspace-confirm > contents {
          background: rgba(30,32,38,0.98);
          border: 1px solid rgba(255,255,255,0.2);
          border-radius: 12px; padding: 12px;
        }
        .confirm-title { font-size: 14px; font-weight: 700; }
        .confirm-detail { font-size: 12px; color: #c5ced8; }
        .confirm-actions button { font-size: 13px; min-height: 30px; padding: 0 12px; }
        .confirm-close { background: rgba(210,55,65,0.72); color: white; }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def load_order(self):
        try:
            value = json.loads(ORDER_FILE.read_text())
            return [str(workspace_id) for workspace_id in value if str(workspace_id).isdigit()]
        except (OSError, ValueError, TypeError):
            return []

    def save_order(self):
        temporary = ORDER_FILE.with_suffix(".tmp")
        temporary.write_text(json.dumps(self.order, indent=2) + "\n")
        temporary.replace(ORDER_FILE)

    def get_workspaces(self):
        workspaces = json.loads(run_hypr(["-j", "workspaces"]))
        # Filter special workspaces without numeric IDs.
        workspaces = [
            ws for ws in workspaces
            if isinstance(ws, dict)
            and type(ws.get('id')) is int
            and ws['id'] > 0
        ]
        monitors = json.loads(run_hypr(["-j", "monitors"]))
        output = preferred_output(monitors)["name"]
        if output != getattr(self, "visible_output", None):
            self.select_monitor()
        self.visible_output = output
        self.active_by_output = {
            monitor.get("name"): monitor.get("activeWorkspace", {}).get("id") for monitor in monitors
        }
        self.fresh_ids = {str(ws["id"]) for ws in workspaces
                          if str(ws["id"]) in self.fresh_ids and not ws.get("windows", 0)
                          and self.active_by_output.get(ws.get("monitor")) == ws.get("id")}
        self._previous_occupied_ids = set(self.occupied_ids)
        self._all_workspaces = workspaces
        self.occupied_ids = {str(ws["id"]) for ws in workspaces if ws.get("windows", 0) > 0}
        result = [ws for ws in workspaces if ws.get("id", -1) > 0
                  and ws.get("monitor") == output
                  and (ws.get("windows", 0) > 0 or
                       (ws.get("monitor") == output and str(ws.get("id")) in self.fresh_ids))]
        self.workspace_by_id = {str(ws["id"]): ws for ws in result}
        # Invisible workspaces do not erase the saved drag-and-drop order.
        self.urgent_ids = set()
        try:
            for client in json.loads(run_hypr(["-j", "clients"])):
                if client.get("urgent"):
                    self.urgent_ids.add(str(client.get("workspace", {}).get("id")))
        except (subprocess.SubprocessError, ValueError):
            pass
        return result

    def recover_empty_workspace(self):
        """Run only after a closewindow IPC event, never on ordinary refresh."""
        output = self.visible_output
        active_id = self.active_by_output.get(output)
        if type(active_id) is not int or str(active_id) not in self._previous_occupied_ids:
            return
        current = next((w for w in self._all_workspaces
                        if w["id"] == active_id and w.get("monitor") == output), None)
        if current is None or current.get("windows", 0) != 0:
            return
        alternatives = [w for w in self.ordered(self._all_workspaces)
                        if w["id"] != active_id and w.get("monitor") == output
                        and w.get("windows", 0) > 0]
        if alternatives:
            chosen = alternatives[0]["id"]
            dispatch('hl.dsp.focus({workspace=' + json.dumps(str(chosen)) + '})')
            self.active_by_output[output] = chosen

    def ordered(self, workspaces):
        by_id = {str(ws.get("id")): ws for ws in workspaces}
        order = [workspace_id for workspace_id in self.order if workspace_id in by_id]
        remaining = sorted((ws for key, ws in by_id.items() if key not in order), key=numeric_key)
        order.extend(str(ws.get("id")) for ws in remaining)
        if not self.order:
            order.sort(key=lambda workspace_id: numeric_key(by_id[workspace_id]))
            if "10" in order:
                order.insert(0, order.pop(order.index("10")))
        return [by_id[workspace_id] for workspace_id in order]

    def refresh(self):
        if self.dragging:
            return False
        try:
            visible = self.get_workspaces()
            if self._close_event:
                self._close_event = False
                self.recover_empty_workspace()
            workspaces = self.ordered(visible)
        except (subprocess.SubprocessError, ValueError, OSError, RuntimeError,
                KeyError, TypeError, AttributeError, IndexError) as error:
            now = time.monotonic()
            if now - self._last_refresh_warning >= 30:
                print(f"Workspace strip refresh: {type(error).__name__}: {error}",
                      file=sys.stderr, flush=True)
                self._last_refresh_warning = now
            return False
        wanted = [str(ws.get("id")) for ws in workspaces]
        if wanted != list(self.buttons):
            print(f"Workspace strip output={self.visible_output} workspaces={','.join(wanted)}", flush=True)
            for child in self.strip.get_children():
                self.strip.remove(child)
            self.buttons.clear()
            for workspace in workspaces:
                workspace_id = str(workspace.get("id"))
                button = Gtk.Button(label=ICONS.get(workspace_id, "•"))
                if workspace_id == "9":
                    button.get_child().set_markup(
                        '<span font_desc="Symbols Nerd Font 20">&#xF179;</span>'
                    )
                button.set_relief(Gtk.ReliefStyle.NONE)
                button.set_can_focus(False)
                button.workspace_id = workspace_id
                button.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
                button.connect("enter-notify-event", self.workspace_hover, workspace_id, True)
                button.connect("leave-notify-event", self.workspace_hover, workspace_id, False)
                button.connect("clicked", self.activate, workspace_id)
                button.connect("button-press-event", self.button_press, workspace_id)
                button.drag_source_set(Gdk.ModifierType.BUTTON1_MASK, [TARGET], Gdk.DragAction.MOVE)
                button.drag_dest_set(Gtk.DestDefaults.ALL, [TARGET], Gdk.DragAction.MOVE)
                button.connect("drag-data-get", self.drag_data_get, workspace_id)
                button.connect("drag-data-received", self.drag_data_received, workspace_id)
                button.connect("drag-begin", self.drag_begin)
                button.connect("drag-end", self.drag_end)
                button.connect("drag-motion", self.drag_motion)
                button.connect("drag-leave", self.drag_leave)
                self.strip.pack_start(button, False, False, 0)
                self.buttons[workspace_id] = button
            self.strip.show_all()
        for workspace in workspaces:
            workspace_id = str(workspace.get("id"))
            button = self.buttons[workspace_id]
            active = self.active_by_output.get(workspace.get("monitor")) == workspace.get("id")
            context = button.get_style_context()
            for css_class in ("active", "urgent"):
                context.remove_class(css_class)
            if active:
                context.add_class("active")
            if workspace_id in self.urgent_ids:
                context.add_class("urgent")
            name = workspace.get("name", workspace_id)
            window_count = workspace.get("windows", 0)
            status = "Active" if active else "Inactive"
            if workspace_id in self.urgent_ids:
                status += " · Needs attention"
            action = ("Reserved for secondary-monitor btop"
                      if workspace_id == "10" else
                      ("Right/middle click: confirm window relocation" if window_count
                       else "Right/middle click: remove empty workspace"))
            button.set_tooltip_text(
                f"Workspace {name} · {status} · {window_count} window(s) · {workspace.get('monitor', '?')}\n"
                f"Left click: switch · Drag: reorder · {action}"
            )
        return False

    def activate(self, _button, workspace_id):
        if self.dragging or time.monotonic() < self.ignore_click_until:
            return
        dispatch(f'hl.dsp.focus({{ workspace = "{workspace_id}" }})')

    def button_press(self, button, event, workspace_id):
        if event.button in (Gdk.BUTTON_SECONDARY, Gdk.BUTTON_MIDDLE):
            if workspace_id == "10":
                return True
            count = self.workspace_by_id.get(workspace_id, {}).get("windows", 0)
            if count > 0:
                self.confirm_close_workspace(button, workspace_id, count)
            else:
                self.close_workspace(workspace_id)
            return True
        return False

    def confirm_close_workspace(self, button, workspace_id, count):
        popover = Gtk.Popover.new(button)
        popover.get_style_context().add_class("workspace-confirm")
        layout = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        layout.set_border_width(12)
        title = Gtk.Label(label=f"Remove workspace {workspace_id}?")
        title.get_style_context().add_class("confirm-title")
        title.set_xalign(0)
        detail = Gtk.Label(label=f"Move {count} window(s) to another workspace.\nAll applications remain open. Cancel makes no changes.")
        detail.get_style_context().add_class("confirm-detail")
        detail.set_xalign(0)
        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        cancel = Gtk.Button(label="Cancel")
        remove = Gtk.Button(label="Move windows & remove")
        remove.get_style_context().add_class("confirm-close")
        def dismiss(_button):
            popover.popdown()
        def approve(_button):
            popover.popdown()
            self.close_workspace(workspace_id)
        cancel.connect("clicked", dismiss)
        remove.connect("clicked", approve)
        actions.pack_start(cancel, True, True, 0)
        actions.pack_start(remove, True, True, 0)
        layout.pack_start(title, False, False, 0)
        layout.pack_start(detail, False, False, 0)
        layout.pack_start(actions, False, False, 0)
        popover.add(layout)
        popover.show_all()
        popover.popup()

    def close_workspace(self, workspace_id):
        if workspace_id == "10":
            return
        try:
            workspaces = json.loads(run_hypr(["-j", "workspaces"]))
            # Exclude special workspaces without numeric IDs.
            workspaces = [
                ws for ws in workspaces
                if isinstance(ws, dict)
                and type(ws.get("id")) is int
                and ws["id"] > 0
            ]
            monitors = json.loads(run_hypr(["-j", "monitors"]))
            clients = json.loads(run_hypr(["-j", "clients"]))
        except (subprocess.SubprocessError, json.JSONDecodeError, OSError, RuntimeError):
            return
        target = next((ws for ws in workspaces if str(ws.get("id")) == workspace_id), None)
        if not target:
            return
        windows = [client for client in clients if str(client.get("workspace", {}).get("id")) == workspace_id]
        target_monitor = target.get("monitor")
        alternate = next(
            (ws for ws in self.ordered(workspaces) if ws.get("monitor") == target_monitor
             and str(ws.get("id")) not in (workspace_id, "10") and ws.get("id", -1) > 0
             and ws.get("windows", 0) > 0), None,
        )
        # The secondary monitor may have only one desktop. Use another occupied
        # desktop rather than leaving application windows stranded in a hidden one.
        if alternate is None:
            alternate = next((ws for ws in self.ordered(workspaces) if str(ws.get("id")) not in (workspace_id, "10")
                              and ws.get("id", -1) > 0 and ws.get("windows", 0) > 0), None)
        destination = str(alternate["id"]) if alternate else str(next_workspace_id(workspaces))
        for client in windows:
            address = client.get("address")
            if address:
                dispatch('hl.dsp.window.move({workspace=' + json.dumps(destination)
                         + ',window=' + json.dumps('address:' + address) + ',follow=false})')
        dispatch('hl.dsp.focus({workspace=' + json.dumps(destination) + '})')
        self.order = [i for i in self.order if i != workspace_id]
        self.save_order()
        print(f"Removed workspace {workspace_id}; moved {len(windows)} windows to {destination}", flush=True)
        GLib.timeout_add(350, self.refresh)

    def drag_data_get(self, _widget, _context, selection, _info, _time, workspace_id):
        # Custom MIME targets must use raw data, not GTK's text conversion.
        selection.set(selection.get_target(), 8, workspace_id.encode("utf-8"))

    def clear_drag_hint(self, widget):
        for name in ("drop-before", "drop-after"):
            widget.get_style_context().remove_class(name)

    def drag_begin(self, widget, context):
        self.dragging = True
        widget.get_style_context().add_class("dragging")
        print(f"Dragging workspace {widget.workspace_id}", flush=True)

    def drag_end(self, widget, _context):
        self.dragging = False
        self.ignore_click_until = time.monotonic() + 0.25
        for button in self.buttons.values():
            self.clear_drag_hint(button)
            button.get_style_context().remove_class("dragging")
        GLib.idle_add(self.refresh)

    def drag_motion(self, widget, context, x, _y, timestamp):
        for button in self.buttons.values():
            self.clear_drag_hint(button)
        widget.get_style_context().add_class("drop-before" if x < widget.get_allocated_width() / 2 else "drop-after")
        Gdk.drag_status(context, Gdk.DragAction.MOVE, timestamp)
        return True

    def drag_leave(self, widget, _context, _timestamp):
        self.clear_drag_hint(widget)
        return False

    def drag_data_received(self, widget, context, x, _y, selection, _info, timestamp, target_id):
        data = selection.get_data()
        try:
            source_id = bytes(data).decode("utf-8").rstrip("\0") if data else None
        except (UnicodeError, TypeError, ValueError):
            source_id = None
        accepted = False
        current = [str(ws.get("id")) for ws in self.ordered(list(self.workspace_by_id.values()))]
        if source_id in current and target_id in current and source_id != target_id:
            current.remove(source_id)
            insert_at = current.index(target_id)
            if x >= widget.get_allocated_width() / 2:
                insert_at += 1
            current.insert(insert_at, source_id)
            # Reorder the visible strip without discarding temporarily hidden IDs.
            self.order = merge_visible_order(self.order, current)
            self.save_order()
            print("Workspace order: " + ", ".join(current), flush=True)
            accepted = True
        self.clear_drag_hint(widget)
        Gtk.drag_finish(context, accepted, False, timestamp)
        # Finish the transfer before rebuilding widgets, or GTK cancels its drag.
        GLib.idle_add(self.refresh)

    def watch_events(self):
        signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        if not signature:
            print("Workspace strip: missing Hyprland instance signature", file=sys.stderr)
            return
        path = Path(runtime) / "hypr" / signature / ".socket2.sock"
        interesting = {"workspace", "workspacev2", "focusedmon", "activewindow",
                       "activewindowv2", "openwindow", "closewindow", "movewindow",
                       "movewindowv2", "urgent", "monitoradded", "monitorremoved",
                       "createworkspace", "destroyworkspace", "moveworkspace",
                       "moveworkspacev2", "renameworkspace", "fullscreen"}
        while True:
            try:
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
                    connection.connect(str(path))
                    pending = b""
                    while True:
                        block = connection.recv(4096)
                        if not block:
                            break
                        pending += block
                        if len(pending) > 65536:
                            pending = pending[-65536:]
                        *lines, pending = pending.split(b"\n")
                        names = {line.partition(b">>")[0].decode("utf-8", "replace")
                                 for line in lines if b">>" in line}
                        if names & interesting:
                            GLib.idle_add(self.schedule_refresh, "closewindow" in names)
            except OSError:
                pass
            try:
                result = subprocess.run(["hyprctl", "instances"],
                                        capture_output=True, text=True, timeout=3)
                instances = {line[9:-1] for line in result.stdout.splitlines()
                             if line.startswith("instance ") and line.endswith(":" )}
                if result.returncode == 0 and instances and signature not in instances:
                    print("Workspace strip: compositor instance changed; restarting", flush=True)
                    GLib.idle_add(Gtk.main_quit)
                    return
            except (OSError, subprocess.SubprocessError):
                pass
            time.sleep(1)


def main():
    lock_handle = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock_handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    WorkspaceStrip()
    Gtk.main()


if __name__ == "__main__":
    main()
