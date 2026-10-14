-- Claude Code integration: terminal split on the right, plus selection/diff tooling.
-- See https://github.com/coder/claudecode.nvim
--
-- Also adds "inline comments": leave a review-style note on a line or visual
-- range and it is sent to the running Claude Code terminal as an @-mention of
-- that range plus your note, and shown as virtual text at the end of the line
-- so you can see what you've already asked about. Only available while the
-- Claude terminal is open — otherwise the keymap tells you to open it first.

local ns = vim.api.nvim_create_namespace 'claudecode_inline_comments'

-- Returns start_line, end_line (1-indexed, inclusive) for the cursor line in
-- normal mode or the selection in visual mode.
local function current_range()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local s = vim.fn.getpos('v')[2]
    local e = vim.fn.getpos('.')[2]
    if s > e then
      s, e = e, s
    end
    return s, e
  end
  local l = vim.api.nvim_win_get_cursor(0)[1]
  return l, l
end

local function claude_terminal_open()
  local ok, term = pcall(require, 'claudecode.terminal')
  return ok and term.get_active_terminal_bufnr() ~= nil
end

local function add_inline_comment()
  if not claude_terminal_open() then
    vim.notify('Claude Code is not open — <leader>ac to start it first', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then
    vim.notify('Buffer has no file path; save it first', vim.log.levels.WARN)
    return
  end

  local start_line, end_line = current_range()
  -- Leave visual mode before prompting so the input box isn't fighting it.
  if vim.fn.mode() ~= 'n' then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
  end

  local where = start_line == end_line and ('L' .. start_line) or ('L' .. start_line .. '-' .. end_line)
  vim.ui.input({ prompt = 'Claude comment (' .. where .. '): ' }, function(text)
    if not text or text == '' then
      return
    end

    -- Mark the line(s) so you can see what you've already asked about.
    vim.api.nvim_buf_set_extmark(bufnr, ns, start_line - 1, 0, {
      end_row = end_line - 1,
      virt_text = { { '  󰭹 ' .. text, 'Comment' } },
      virt_text_pos = 'eol',
      sign_text = '󰭹',
      sign_hl_group = 'DiagnosticInfo',
    })

    -- @-mention the range (0-indexed lines on the wire), then submit the note.
    local claude = require 'claudecode'
    local ok, err = claude.send_at_mention(path, start_line - 1, end_line - 1, 'inline comment')
    if not ok then
      vim.notify('Claude Code: ' .. tostring(err), vim.log.levels.ERROR)
      return
    end
    require('claudecode.terminal').send_to_terminal(text, { submit = true })
  end)
end

local function clear_inline_comments()
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

---@module 'lazy'
---@type LazySpec
return {
  'coder/claudecode.nvim',
  dependencies = { 'folke/snacks.nvim' },
  cmd = {
    'ClaudeCode',
    'ClaudeCodeFocus',
    'ClaudeCodeSend',
    'ClaudeCodeAdd',
    'ClaudeCodeDiffAccept',
    'ClaudeCodeDiffDeny',
    'ClaudeCodeSelectModel',
  },
  keys = {
    { '<leader>a', '', desc = 'AI/Claude Code' },
    { '<leader>ac', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
    { '<leader>af', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
    { '<leader>ar', '<cmd>ClaudeCode --resume<cr>', desc = 'Resume Claude' },
    { '<leader>aC', '<cmd>ClaudeCode --continue<cr>', desc = 'Continue Claude' },
    { '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', desc = 'Select Claude model' },
    { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = 'Add current buffer' },
    { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send selection to Claude' },
    { '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept Claude diff' },
    { '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny Claude diff' },
    { '<leader>ai', add_inline_comment, mode = { 'n', 'v' }, desc = 'Inline comment for Claude' },
    { '<leader>aI', clear_inline_comments, desc = 'Clear Claude inline comments' },
  },
  opts = {
    terminal = {
      split_side = 'right',
      split_width_percentage = 0.40,
      provider = 'auto',
    },
  },
}
