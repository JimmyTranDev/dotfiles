--- @since 25.5.31
--- @sync entry

local function setup(self, opts) self.open_multi = opts.open_multi end

local function entry(self)
	local h = cx.active.current.hovered
	if h and h.cha.is_dir then
		ya.emit("enter", {})
		ya.emit("plugin", { "skip-single" })
	else
		ya.emit("open", { hovered = not self.open_multi })
	end
end

return { entry = entry, setup = setup }
