-- Kiro CLI in a toggleable right-side terminal split, mirroring the Claude Code UX.
-- There is no official Kiro nvim plugin, so we just spawn `kiro` in a snacks terminal.

---@module 'lazy'
---@type LazySpec
return {
  'folke/snacks.nvim',
  keys = {
    { '<leader>k', '', desc = 'AI/Kiro' },
    {
      '<leader>kk',
      function()
        require('snacks').terminal.toggle('kiro', {
          win = {
            position = 'right',
            width = 0.40,
          },
        })
      end,
      desc = 'Toggle Kiro',
    },
  },
}
