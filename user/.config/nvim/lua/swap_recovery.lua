-- Discover abandoned, modified swap files without changing them.
-- Recovery actions and dashboard integration are separate.

local M = {}

local function original_path(name)
  if not name or name == "" then
    return nil
  end

  local passwd = vim.uv.os_get_passwd()
  local username = passwd and passwd.username or ""
  local prefix = "~" .. username

  if username ~= "" and
      (name == prefix or name:sub(1, #prefix + 1) == prefix .. "/") then
    return vim.fn.expand("~") .. name:sub(#prefix + 1)
  end

  local expanded = vim.fn.expand(name)
  if expanded:sub(1, 1) == "/" then
    return expanded
  end

  return nil
end

function M.list()
  local dir = vim.fn.stdpath("state") .. "/swap"
  local results = {}

  if vim.fn.isdirectory(dir) ~= 1 then
    return results
  end

  local passwd = vim.uv.os_get_passwd()
  local username = passwd and passwd.username or ""
  local hostname = vim.uv.os_gethostname()

  for _, name in ipairs(vim.fn.readdir(dir)) do
    if name:match("%.s[uvw]%a$") then
      local swap = vim.fs.joinpath(dir, name)
      local stat = vim.uv.fs_stat(swap)

      if stat and stat.type == "file" then
        local ok, info = pcall(vim.fn.swapinfo, swap)

        if ok and type(info) == "table"
            and (info.error == nil or info.error == "")
            and tonumber(info.dirty or 0) == 1
            and tonumber(info.pid or 0) == 0
            and info.host == hostname
            and info.user == username then

          local original = original_path(info.fname)
          local file_stat = original and vim.uv.fs_stat(original)
          local mtime = tonumber(info.mtime or 0)

          table.insert(results, {
            swap = swap,
            original = original,
            original_raw = info.fname,
            original_exists = file_stat ~= nil,
            swap_mtime = mtime > 0 and mtime or nil,
            original_mtime = file_stat
                and file_stat.mtime.sec or nil,
            host = info.host,
            active = false,
          })
        end
      end
    end
  end

  table.sort(results, function(a, b)
    local ta = a.swap_mtime or 0
    local tb = b.swap_mtime or 0

    if ta == tb then
      return a.swap < b.swap
    end

    return ta > tb
  end)

  return results
end

function M.count()
  return #M.list()
end



-- Inspect a candidate without modifying files.
function M.inspect(item)
  local date = item.swap_mtime
      and os.date("%Y-%m-%d %H:%M:%S", item.swap_mtime)
      or "Unknown"

  vim.notify(table.concat({
    "Original: " .. (item.original or item.original_raw),
    "Original exists: " .. tostring(item.original_exists),
    "Swap: " .. item.swap,
    "Modified: " .. date,
    "",
    "No recovery or deletion performed.",
  }, "\n"), vim.log.levels.INFO, {
    title = "Swap Recovery Candidate",
  })
end

-- Recover into a new, separately named review buffer.
-- Never write to the original document or remove the source swap.
function M.review(item)
  if type(item) ~= "table" or type(item.swap) ~= "string" then
    return nil, "Invalid recovery candidate"
  end

  local stat = vim.uv.fs_stat(item.swap)
  if not stat or stat.type ~= "file" then
    return nil, "Swap file no longer exists"
  end

  local info = vim.fn.swapinfo(item.swap)
  local passwd = vim.uv.os_get_passwd()

  if (info.error and info.error ~= "")
      or tonumber(info.dirty or 0) ~= 1
      or tonumber(info.pid or -1) ~= 0
      or info.host ~= vim.uv.os_gethostname()
      or info.user ~= passwd.username then
    return nil, "Candidate is no longer eligible for recovery"
  end

  local original = original_path(info.fname)
  if not original then
    return nil, "Cannot resolve original filename"
  end

  local dir = vim.fn.stdpath("state") .. "/recovery-reviews"
  local dir_stat = vim.uv.fs_lstat(dir)

  if not dir_stat then
    local created, err = vim.uv.fs_mkdir(dir, 448) -- 0700
    if not created then
      return nil, "Cannot create review directory: " .. tostring(err)
    end
    dir_stat = vim.uv.fs_lstat(dir)
  end

  if not dir_stat or dir_stat.type ~= "directory" then
    return nil, "Unsafe review directory"
  end

  local basename = vim.fn.fnamemodify(original, ":t")
  basename = basename:gsub("[^%w%._%-]", "_"):sub(1, 80)

  local review = vim.fs.joinpath(
    dir,
    os.date("%Y%m%d-%H%M%S")
      .. "-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
      .. "-" .. basename
  )

  if vim.uv.fs_lstat(review) or vim.fn.bufnr(review) ~= -1 then
    return nil, "Review filename collision"
  end

  -- A fresh tab prevents recovery from replacing an existing buffer.
  vim.cmd("noautocmd tabnew")
  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = "hide"

  local ok, err = pcall(
    vim.cmd,
    "recover " .. vim.fn.fnameescape(item.swap)
  )

  local warning = not ok
      and tostring(err):find("E308:", 1, true) ~= nil

  if not ok and not warning then
    vim.bo[buf].readonly = true
    return nil, "Recovery error: " .. tostring(err)
  end

  -- Never leave the recovered buffer named after the original.
  local named, name_err = pcall(
    vim.api.nvim_buf_set_name, buf, review
  )

  if not named then
    vim.bo[buf].readonly = true
    return nil, "Could not assign safe review name: "
        .. tostring(name_err)
  end

  vim.bo[buf].readonly = false
  vim.bo[buf].modified = true
  vim.bo[buf].swapfile = false

  local ft = vim.filetype.match({ filename = original })
  if ft then
    vim.bo[buf].filetype = ft
  end

  vim.b[buf].recovery_original = original
  vim.b[buf].recovery_swap = item.swap

  vim.notify(table.concat({
    "Recovered into a separate review tab.",
    "Original: " .. original,
    "Review: " .. review,
    warning and "E308: Compare against the original file." or "",
    "Use :w to save the review copy.",
    "Original document and swap were not changed.",
  }, "\n"), vim.log.levels.INFO, {
    title = "Recovery Review",
  })

  return {
    buffer = buf,
    review = review,
    warning = warning,
  }
end

function M.open()
  local candidates = M.list()

  if #candidates == 0 then
    vim.notify("No abandoned modified swap files found")
    return
  end

  vim.ui.select(candidates, {
    prompt = "Recovery candidates:",
    format_item = function(item)
      local file = item.original or item.original_raw or "Unknown"
      local date = item.swap_mtime
          and os.date("%Y-%m-%d %H:%M", item.swap_mtime)
          or "Unknown date"

      return string.format(
        "%s | %s | %s",
        vim.fn.fnamemodify(file, ":~"),
        date,
        item.original_exists and "Original exists"
          or "Original missing"
      )
    end,
  }, function(item)
    if not item then
      return
    end

    vim.ui.select({
      "Inspect metadata",
      "Recover into review tab",
    }, {
      prompt = "Recovery action:",
    }, function(action)
      if action == "Inspect metadata" then
        M.inspect(item)
      elseif action == "Recover into review tab" then
        local result, err = M.review(item)
        if not result then
          vim.notify(err, vim.log.levels.ERROR)
        end
      end
    end)
  end)
end

return M
