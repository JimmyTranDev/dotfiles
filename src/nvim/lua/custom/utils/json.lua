local M = {}

local notified_secrets_missing = false
local missing_files = {}

function M.parse_json_from_file(file_path)
  local file, err = io.open(file_path, 'r')
  if not file then
    if string.match(file_path, 'Programming/JimmyTranDev/secrets') then
      local secrets_path = os.getenv('HOME') .. '/Programming/JimmyTranDev/secrets'
      local stat = vim.uv.fs_stat(secrets_path)
      local secrets_dir_exists = stat and stat.type == 'directory'

      if not secrets_dir_exists then
        if not notified_secrets_missing then
          vim.notify('Secrets directory does not exist. Run: storage-init', vim.log.levels.INFO)
          notified_secrets_missing = true
        end
        return {}
      else
        local filename = vim.fn.fnamemodify(file_path, ':t')
        if not missing_files[filename] then
          vim.notify('Missing secrets file: ' .. filename .. '. Run: storage-init', vim.log.levels.WARN)
          missing_files[filename] = true
        end
      end
    else
      vim.notify('Failed to open file: ' .. file_path .. ' (' .. (err or 'unknown error') .. ')', vim.log.levels.WARN)
    end
    return {}
  end

  local json_string = file:read('*a')
  file:close()

  local ok, result = pcall(vim.json.decode, json_string)
  if ok then
    return result
  else
    vim.notify('Failed to parse JSON from ' .. file_path .. ': ' .. result, vim.log.levels.ERROR)
    return {}
  end
end

function M.write_json_to_file(file_path, data)
  local f = io.open(file_path, 'w')
  if not f then
    vim.notify('Failed to write: ' .. file_path, vim.log.levels.WARN)
    return false
  end
  f:write(vim.json.encode(data))
  f:close()
  return true
end

return M
