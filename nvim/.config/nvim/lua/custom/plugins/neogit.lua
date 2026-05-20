-- neogit: magit-style porcelain for staging hunks/files and driving commits.

---@module 'lazy'
---@type LazySpec
return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
    'nvim-telescope/telescope.nvim',
  },
  cmd = 'Neogit',
  keys = {
    { '<leader>gg', '<cmd>Neogit<cr>', desc = 'Git status ([G]it)' },
    { '<leader>gc', '<cmd>Neogit commit<cr>', desc = 'Git [C]ommit' },
    { '<leader>gp', '<cmd>Neogit pull<cr>', desc = 'Git [P]ull' },
    { '<leader>gP', '<cmd>Neogit push<cr>', desc = 'Git [P]ush' },
  },
  opts = {
    integrations = { diffview = true, telescope = true },
  },
}
