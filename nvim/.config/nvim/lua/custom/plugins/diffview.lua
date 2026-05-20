-- diffview.nvim: file-tree view of git diffs and file history.

---@module 'lazy'
---@type LazySpec
return {
  'sindrets/diffview.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewToggleFiles', 'DiffviewFileHistory', 'DiffviewRefresh' },
  keys = {
    { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Git [D]iff (Diffview)' },
    { '<leader>gD', '<cmd>DiffviewClose<cr>', desc = 'Git [D]iff close' },
    { '<leader>gh', '<cmd>DiffviewFileHistory<cr>', desc = 'Git file [H]istory (repo)' },
    { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = 'Git [F]ile history (current)' },
  },
  opts = {},
}
