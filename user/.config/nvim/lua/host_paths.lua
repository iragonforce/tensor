local M = {}
local mac = vim.fn.has("macunix") == 1
M.project_root = vim.fn.expand("~/project")

-- Nexus stores projects on its fast storage pool.
local hostname = (vim.uv.os_gethostname() or ""):match("^[^.]+")
if hostname == "nexus" then
  M.project_root = "/mnt/fast/project"
end
-- Prefer a local vault when present, otherwise use the platform default.
local local_vault = vim.fn.expand("~/secondBrain")
local default_vault = mac
    and vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/secondBrain")
    or vim.fn.expand("~/obsidian/obsidian-vault")

M.obsidian_root = vim.fn.isdirectory(local_vault) == 1
    and local_vault
    or default_vault
function M.cl_lsp_command()
  local roswell = vim.fn.expand("~/.roswell/bin/cl-lsp")
  if mac and vim.fn.executable(roswell) == 1 then
    return { "/usr/bin/env", "DYLD_LIBRARY_PATH=" .. vim.fn.expand("~/.local/lib"), roswell }
  end
  return { "cl-lsp" }
end
return M
