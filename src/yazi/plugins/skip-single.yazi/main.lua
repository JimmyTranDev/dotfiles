--- @since 25.5.31

local get_cwd = ya.sync(function()
	return cx.active.current.cwd
end)

local function entry()
	local prev_cwd = nil
	while true do
		local cwd = get_cwd()
		if prev_cwd and tostring(cwd) == tostring(prev_cwd) then
			break
		end
		prev_cwd = cwd

		local files, err = fs.read_dir(cwd, { limit = 2 })

		if err or not files or #files ~= 1 then
			break
		end

		local only = files[1]
		if not only.cha.is_dir then
			break
		end

		ya.emit("enter", {})

		ya.sleep(0.05)
	end
end

return { entry = entry }
