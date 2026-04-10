--- @since 25.5.31

local get_cwd = ya.sync(function()
	return cx.active.current.cwd
end)

local function entry()
	while true do
		local cwd = get_cwd()
		local files, err = fs.read_dir(cwd, { limit = 2 })

		if err or not files or #files ~= 1 then
			break
		end

		local only = files[1]
		if not only.cha.is_dir then
			break
		end

		ya.emit("cd", { Url(tostring(only.url)) })

		ya.sleep(0.05)
	end
end

return { entry = entry }
