if vim.g.loaded_cmp_agents_skills then
	return
end
vim.g.loaded_cmp_agents_skills = true

local mod = require('cmp_agents_skills')
local source = mod.new()
require('cmp').register_source('agents_skills', source)

mod.rescan = function(opts)
	source:rescan(opts)
end
