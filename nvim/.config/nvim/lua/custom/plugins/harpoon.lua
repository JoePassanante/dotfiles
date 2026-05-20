-- Harpoon 2: pin a handful of files and teleport between them with <C-1>..<C-4>.

---@module 'lazy'
---@type LazySpec
return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  keys = function()
    local h = require 'harpoon'
    return {
      { '<leader>m', '', desc = '[M]arks (Harpoon)' },
      { '<leader>ma', function() h:list():add() end, desc = 'Harpoon [A]dd file' },
      { '<leader>mm', function() h.ui:toggle_quick_menu(h:list()) end, desc = 'Harpoon [M]enu' },
      { '<leader>mn', function() h:list():next() end, desc = 'Harpoon [N]ext' },
      { '<leader>mp', function() h:list():prev() end, desc = 'Harpoon [P]rev' },
      { '<C-1>', function() h:list():select(1) end, desc = 'Harpoon 1' },
      { '<C-2>', function() h:list():select(2) end, desc = 'Harpoon 2' },
      { '<C-3>', function() h:list():select(3) end, desc = 'Harpoon 3' },
      { '<C-4>', function() h:list():select(4) end, desc = 'Harpoon 4' },
    }
  end,
  config = function() require('harpoon'):setup() end,
}
