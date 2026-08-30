local backends = require('fuzzy_nvim.backends')

local home = vim.loop.os_homedir() or os.getenv('HOME') or '~'

local defaults = {
	dirs = {
		'.claude/skills',
		'.agents/skills',
	},
	absolute_dirs = {
		home .. '/.cursor/skills-cursor',
		home .. '/.cursor/skills',
	},
	roots = nil, -- list of root paths to scan, nil = auto-detect via git
	trigger = '/',
	fuzzy_backend = nil,
	max_items = 15,
	fuzzy_extra_arg = 0,
}

local source = {}

source.new = function(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = vim.tbl_deep_extend('keep', opts or {}, defaults)
	self.skills = {} -- { name = string, description = string, path = string }
	self.skill_names = {} -- flat list for fuzzy matching
	self:_scan()
	return self
end

local function parse_frontmatter(content)
	local fm = content:match('^%-%-%-\r?\n(.-)\r?\n%-%-%-')
	if not fm then
		return nil, nil
	end
	local name = fm:match('name:%s*(.-)%s*\n')
	local desc = fm:match('description:%s*["\']?(.-)["\']?%s*\n')
	if desc then
		desc = desc:gsub('^["\']', ''):gsub('["\']$', '')
	end
	return name, desc
end

function source:_scan()
	local seen = {}
	self.skills = {}
	self.skill_names = {}

	local roots = self.opts.roots
	if not roots then
		local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
		if vim.v.shell_error == 0 and git_root and #git_root > 0 then
			roots = { git_root }
		else
			roots = { vim.fn.getcwd() }
		end
	end

	local function scan_dir(skills_dir, dir_label)
		local handle = vim.loop.fs_scandir(skills_dir)
		if not handle then
			return
		end
		while true do
			local entry_name, entry_type = vim.loop.fs_scandir_next(handle)
			if not entry_name then
				break
			end
			if entry_type == 'directory' and not seen[entry_name] then
				local skill_file = skills_dir .. '/' .. entry_name .. '/SKILL.md'
				local fd = vim.loop.fs_open(skill_file, 'r', 438)
				if fd then
					local stat = vim.loop.fs_fstat(fd)
					local content = vim.loop.fs_read(fd, stat.size, 0)
					vim.loop.fs_close(fd)

					local name, desc = parse_frontmatter(content)
					name = name or entry_name

					seen[name] = true
					self.skills[#self.skills + 1] = {
						name = name,
						description = desc or '',
						path = skill_file,
						dir = dir_label,
					}
					self.skill_names[#self.skill_names + 1] = name
				end
			end
		end
	end

	for _, root in ipairs(roots) do
		for _, dir in ipairs(self.opts.dirs) do
			scan_dir(root .. '/' .. dir, dir)
		end
	end

	for _, abs_dir in ipairs(self.opts.absolute_dirs) do
		scan_dir(abs_dir, abs_dir)
	end
end

function source:get_trigger_characters()
	return { self.opts.trigger }
end

function source:get_keyword_pattern()
	local t = vim.pesc(self.opts.trigger)
	return t .. [[[[:keyword:]-]*]]
end

function source:complete(params, callback)
	local before = params.context.cursor_before_line
	local trigger = self.opts.trigger

	-- Find the last trigger character and extract everything after it
	local trigger_pos = before:find(trigger .. '[%w_-]*$')
	if not trigger_pos then
		callback({ items = {}, isIncomplete = false })
		return
	end
	local pattern = before:sub(trigger_pos + #trigger)

	if #self.skill_names == 0 then
		callback({ items = {}, isIncomplete = false })
		return
	end

	vim.schedule(function()
		local matcher = backends.get(self.opts.fuzzy_backend)
		local items

		if #pattern == 0 then
			-- No filter yet, return all skills
			items = {}
			for i, name in ipairs(self.skill_names) do
				if i > self.opts.max_items then break end
				local skill
				for _, s in ipairs(self.skills) do
					if s.name == name then skill = s; break end
				end
				items[#items + 1] = {
					label = trigger .. name,
					detail = skill and skill.description or nil,
					filterText = trigger .. name,
					sortText = name,
					data = { score = 0, path = skill and skill.path, description = skill and skill.description },
					dup = 0,
				}
			end
			callback({ items = items, isIncomplete = true })
			return
		end

		local matches = matcher:filter(pattern, self.skill_names, self.opts.fuzzy_extra_arg)

		local completions = {}
		local set = {}

		for _, result in ipairs(matches) do
			local name, _, score = unpack(result)
			if not set[name] then
				set[name] = true
				local skill
				for _, s in ipairs(self.skills) do
					if s.name == name then
						skill = s
						break
					end
				end
				table.insert(completions, {
					label = trigger .. name,
					detail = skill and skill.description or nil,
					filterText = trigger .. name,
					sortText = name,
					data = {
						score = score,
						path = skill and skill.path or nil,
						description = skill and skill.description or nil,
					},
					dup = 0,
				})
			end
		end

		table.sort(completions, function(a, b)
			return a.data.score > b.data.score
		end)
		completions = { unpack(completions, 1, self.opts.max_items) }

		callback({
			items = completions,
			isIncomplete = true,
		})
	end)
end

function source.resolve(_, completion_item, callback)
	local data = completion_item.data
	if data and data.path then
		local fd = vim.loop.fs_open(data.path, 'r', 438)
		if fd then
			local stat = vim.loop.fs_fstat(fd)
			local content = vim.loop.fs_read(fd, stat.size, 0)
			vim.loop.fs_close(fd)

			local doc = content:match('^%-%-%-\r?\n.-\r?\n%-%-%-\r?\n(.*)') or content
			completion_item.documentation = {
				kind = 'markdown',
				value = doc,
			}
		end
	end
	callback(completion_item)
end

source.rescan = function(self, opts)
	self.opts = vim.tbl_deep_extend('force', self.opts, opts or {})
	self:_scan()
end

return source
