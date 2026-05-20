local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- ---------- Responsiveness on macOS ----------
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
config.native_macos_fullscreen_mode = false

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
local function pane_is_running_claude(pane)
	if not pane then
		return false
	end
	local proc = pane.foreground_process_name or ""
	-- foreground_process_name is the full path; take the basename.
	local basename = proc:match("([^/\\]+)$") or proc
	if basename == "claude" then
		return true
	end
	-- Fallback: pane title often reflects the running command (e.g. node-based CLIs
	-- report "node" as the process name but set the title to "claude").
	local title = pane.title or ""
	if title:lower():find("claude", 1, true) then
		return true
	end
	return false
end

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

	if pane_is_running_claude(tab.active_pane) then
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

-- Status bar: full ~/path [proc] of the active pane, on the left side of the
-- (now always-visible, bottom) tab bar. Never truncated.
wezterm.on("update-status", function(window, pane)
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

-- ---------- iTerm2-style key bindings ----------
-- WezTerm already ships CMD+T (new tab), CMD+W (close), CMD+1..9 (switch),
-- CMD+SHIFT+[ / ] (prev/next tab), CMD+N (new window), CMD+F (search), CMD+C/V.
-- These additions fill in the iTerm shortcuts that aren't default.
config.keys = {
	-- Splits (iTerm: Cmd+D vertical, Cmd+Shift+D horizontal)
	{ key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Close current pane (iTerm: Cmd+W closes the focused pane, then tab)
	{ key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },

	-- Pane navigation (iTerm: Cmd+Opt+Arrow)
	{ key = "LeftArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Down") },

	-- Tab navigation
	{ key = "LeftArrow", mods = "CMD", action = act.ActivateTabRelative(-1) },
	{ key = "RightArrow", mods = "CMD", action = act.ActivateTabRelative(1) },

	-- Clear buffer (iTerm: Cmd+K)
	{ key = "k", mods = "CMD", action = act.ClearScrollback("ScrollbackAndViewport") },

	-- Quick select: type letters to copy any visible token (URL, hash, path)
	{ key = "Space", mods = "CMD|SHIFT", action = act.QuickSelect },

	-- Command palette
	{ key = "p", mods = "CMD|SHIFT", action = act.ActivateCommandPalette },

	-- Broadcast input toggle — iTerm's Cmd+Opt+I
	{ key = "i", mods = "CMD|OPT", action = act.PaneSelect({ mode = "Activate" }) },

	-- Rename tab (iTerm: not standard, but handy)
	{
		key = "e",
		mods = "CMD|SHIFT",
		action = act.PromptInputLine({
			description = "Tab name:",
			action = wezterm.action_callback(function(window, _, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
}

return config
