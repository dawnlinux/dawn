return {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    filters = {
      ignore_qt_compiler_arg = function(item, enabled)
        if not enabled then
          return true
        end

        local message = item.item and item.item.message or ""
        return not message:match("^Unknown argument:%s*['\"]?%-mno%-direct%-extern%-access['\"]?")
      end,
    },
    modes = {
      diagnostics = {
        filter = {
          ["not"] = {
            ignore_qt_compiler_arg = true,
          },
        },
      },
    },
  },
}
