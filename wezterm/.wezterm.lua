local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- ---------- Platform detection ----------
-- target_triple example: "aarch64-apple-darwin", "x86_64-unknown-linux-gnu",
-- "x86_64-pc-windows-msvc". Use CMD on macOS to mimic iTerm; CTRL elsewhere
-- so shortcuts don't collide with the system meta key.
local target = wezterm.target_triple
local is_mac = target:find("darwin") ~= nil
local mod = is_mac and "CMD" or "CTRL"
local mod_shift = mod .. "|SHIFT"
local pane_mod = is_mac and "CMD|OPT" or "CTRL|ALT"

-- ---------- Responsiveness ----------
-- WebGpu uses Metal on macOS and is noticeably snappier than the default OpenGL backend.
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- Match the display's refresh rate. 120 is correct for ProMotion MacBooks; harmless on 60Hz.
config.max_fps = 120
config.animation_fps = 60

-- Avoid unnecessary redraws.
config.cursor_blink_rate = 0
config.enable_scroll_bar = false

-- Don't re-lay-out the window when font size changes (cheaper + less jitter).
config.adjust_window_size_when_changing_font_size = false

-- Native macOS fullscreen is laggier than wezterm's own; prefer the native-titlebar-less style.
if is_mac then
	config.native_macos_fullscreen_mode = false
end

-- ---------- Appearance ----------
config.font_size = 13.0
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.window_padding = { left = 6, right = 6, top = 4, bottom = 2 }
config.tab_max_width = 32
config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_duration_ms = 75,
	fade_out_duration_ms = 75,
	target = "CursorColor",
}
config.colors = { visual_bell = "#d97706" }
config.notification_handling = "AlwaysShow"

-- ---------- Scrollback / behavior ----------
config.scrollback_lines = 50000
config.exit_behavior = "CloseOnCleanExit"
config.window_close_confirmation = "NeverPrompt"

-- ---------- Hyperlinks / quick select ----------
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- ---------- Tab coloring: highlight tabs running Claude Code ----------
-- Claude Code spawns subshells for its Bash tool, so the foreground process
-- frequently changes from "claude" to "bash"/"node"/whatever — making naive
-- foreground-name detection blink. Instead, walk the pane's full process
-- tree (via the mux Pane, which is richer than the PaneInformation passed
-- to format-tab-title) and check whether *any* descendant is "claude".

-- Recursively scan a process info tree for a process whose basename matches
-- `name`. wezterm.procinfo trees expose `name` (basename) and `children` (a
-- map keyed by pid).
local function tree_has_process(info, name)
	if info == nil then
		return false
	end
	if info.name == name then
		return true
	end
	if info.children then
		for _, child in pairs(info.children) do
			if tree_has_process(child, name) then
				return true
			end
		end
	end
	return false
end

-- pane_id -> bool. Refreshed by update-status (throttled), read by
-- format-tab-title. A module-level table is the simplest sticky cache.
local claude_panes = {}
local last_claude_scan = 0
local CLAUDE_SCAN_INTERVAL_S = 3 -- claude start/stop is rare; no need to scan every tick

local HOME = os.getenv("HOME") or ""

local function cwd_path(pane)
	local cwd = pane.current_working_dir
	if not cwd then
		return nil
	end
	local path = cwd.file_path or tostring(cwd)
	path = path:gsub("/$", "")
	if path == "" then
		return "/"
	end
	return path
end

local function tilde_shorten(path)
	if HOME ~= "" and (path == HOME or path:sub(1, #HOME + 1) == HOME .. "/") then
		return "~" .. path:sub(#HOME + 1)
	end
	return path
end

local function cwd_short(path)
	-- Show last two segments: parent/leaf. Special-case root-level dirs.
	local parent, leaf = path:match("^.*/([^/]+)/([^/]+)$")
	if parent and leaf then
		return parent .. "/" .. leaf
	end
	return path:match("([^/]+)$") or path
end

local function process_basename(pane)
	local proc = pane.foreground_process_name or ""
	local base = proc:match("([^/\\]+)$") or proc
	if base == "" then
		return nil
	end
	return base
end

wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, hover, max_width)
	local title = tab.tab_title
	if not title or #title == 0 then
		local path = cwd_path(tab.active_pane)
		title = path and cwd_short(path) or (tab.active_pane.title or "")
	end
	-- All tabs cap at max_width; the full path lives in the right-status area.
	if #title > max_width - 2 then
		if title:find("/", 1, true) then
			title = "…" .. wezterm.truncate_left(title, max_width - 3)
		else
			title = wezterm.truncate_right(title, max_width - 2)
		end
	end
	local padded = " " .. title .. " "

	-- Read the cached value set by update-status. Lookup is keyed by pane_id;
	-- format-tab-title is hot so we avoid the process-tree walk here.
	if claude_panes[tab.active_pane.pane_id] then
		-- Claude tab: warm orange background, dark text.
		local bg = tab.is_active and "#d97706" or "#92400e"
		if hover and not tab.is_active then
			bg = "#b45309"
		end
		return {
			{ Background = { Color = bg } },
			{ Foreground = { Color = "#1c1917" } },
			{ Attribute = { Intensity = "Bold" } },
			{ Text = padded },
		}
	end

	-- Default: let wezterm's normal tab colors apply.
	return padded
end)

-- update-status fires roughly once per second per window. We use it for two
-- things: (1) re-scan every pane's process tree and stash whether claude is
-- running anywhere in it (used by format-tab-title), (2) render the left
-- status bar with the active pane's cwd + process.
wezterm.on("update-status", function(window, pane)
	-- (1) Refresh claude_panes for every pane in every window, but throttle
	-- the scan since claude start/stop is rare. update-status itself fires
	-- per-window per-second; this gates the actual process-tree walk.
	local now = os.time()
	if now - last_claude_scan >= CLAUDE_SCAN_INTERVAL_S then
		last_claude_scan = now
		local seen = {}
		for _, mux_window in ipairs(wezterm.mux.all_windows()) do
			for _, mux_tab in ipairs(mux_window:tabs()) do
				for _, mux_pane in ipairs(mux_tab:panes()) do
					local pid = mux_pane:pane_id()
					seen[pid] = true
					local info = mux_pane:get_foreground_process_info()
					if tree_has_process(info, "claude") then
						claude_panes[pid] = true
					else
						claude_panes[pid] = nil
					end
				end
			end
		end
		-- Drop entries for panes that no longer exist.
		for pid in pairs(claude_panes) do
			if not seen[pid] then
				claude_panes[pid] = nil
			end
		end
	end

	-- (2) Left status: cwd + process of the active pane.
	local path = cwd_path(pane)
	local text = ""
	if path then
		text = tilde_shorten(path)
		local proc = process_basename(pane)
		if proc and proc ~= "zsh" and proc ~= "bash" and proc ~= "fish" then
			text = text .. " [" .. proc .. "]"
		end
	end
	window:set_left_status(wezterm.format({
		{ Foreground = { Color = "#94a3b8" } },
		{ Text = " " .. text .. " " },
	}))
end)

-- ---------- Session restore (resurrect.wezterm) ----------
-- Saves window/tab/pane layout + cwd + (optionally) scrollback to disk so
-- after a crash or reboot you can fuzzy-load the last session. Lazy-cloned
-- on first launch; subsequent launches load from cache.
local resurrect_ok, resurrect = pcall(function()
	return wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
end)

if resurrect_ok then
	-- Periodic auto-save every 5 minutes. Workspaces only — saving windows
	-- and tabs separately mostly produces noise in the fuzzy picker.
	resurrect.state_manager.periodic_save({
		interval_seconds = 5 * 60,
		save_workspaces = true,
		save_windows = false,
		save_tabs = false,
	})
	-- Cap scrollback per pane so save files don't balloon.
	resurrect.state_manager.set_max_nlines(2000)

	-- Auto-restore the most recent "current" workspace on GUI startup.
	-- This requires that a current state exists on disk; periodic_save plus
	-- the workspace-focus hook below keep it fresh.
	wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)
	wezterm.on("window-focus-changed", function(_, _)
		local ws = wezterm.mux.get_active_workspace()
		if ws and ws ~= "" then
			resurrect.state_manager.write_current_state(ws, "workspace")
		end
	end)
end

local restore_opts = {
	relative = true,
	restore_text = true,
	resize_window = false, -- safer with our custom window_decorations/padding
	on_pane_restore = resurrect_ok and resurrect.tab_state.default_on_pane_restore or nil,
}

-- ---------- iTerm2-style key bindings ----------
-- On macOS the modifier is CMD; on Linux/Windows it's CTRL. The same shortcut
-- mappings apply on both, so muscle memory transfers across platforms.
config.keys = {
	-- Splits
	{ key = "d", mods = mod, action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = mod_shift, action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Close current pane
	{ key = "w", mods = mod, action = act.CloseCurrentPane({ confirm = false }) },

	-- Pane navigation
	{ key = "LeftArrow", mods = pane_mod, action = act.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = pane_mod, action = act.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = pane_mod, action = act.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = pane_mod, action = act.ActivatePaneDirection("Down") },

	-- Tab navigation
	{ key = "LeftArrow", mods = mod, action = act.ActivateTabRelative(-1) },
	{ key = "RightArrow", mods = mod, action = act.ActivateTabRelative(1) },

	-- Clear buffer
	{ key = "k", mods = mod, action = act.ClearScrollback("ScrollbackAndViewport") },

	-- Quick select: type letters to copy any visible token (URL, hash, path)
	{ key = "Space", mods = mod_shift, action = act.QuickSelect },

	-- Command palette
	{ key = "p", mods = mod_shift, action = act.ActivateCommandPalette },

	-- Broadcast input toggle
	{ key = "i", mods = pane_mod, action = act.PaneSelect({ mode = "Activate" }) },

	-- Rename tab
	{
		key = "e",
		mods = mod_shift,
		action = act.PromptInputLine({
			description = "Tab name:",
			action = wezterm.action_callback(function(window, _, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},

	-- Session save / fuzzy restore (resurrect.wezterm)
	{
		key = "s",
		mods = mod_shift,
		action = wezterm.action_callback(function(_, _)
			if not resurrect_ok then
				return
			end
			resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
		end),
	},
	{
		key = "r",
		mods = mod_shift,
		action = wezterm.action_callback(function(win, pane)
			if not resurrect_ok then
				return
			end
			resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, _)
				local kind = string.match(id, "^([^/]+)")
				local name = string.match(id, "([^/]+)$")
				name = string.match(name, "(.+)%..+$")
				if kind == "workspace" then
					local state = resurrect.state_manager.load_state(name, "workspace")
					resurrect.workspace_state.restore_workspace(state, restore_opts)
				elseif kind == "window" then
					local state = resurrect.state_manager.load_state(name, "window")
					resurrect.window_state.restore_window(pane:window(), state, restore_opts)
				elseif kind == "tab" then
					local state = resurrect.state_manager.load_state(name, "tab")
					resurrect.tab_state.restore_tab(pane:tab(), state, restore_opts)
				end
			end)
		end),
	},
}

return config
