return function(entry1, entry2)
	local s1 = entry1.completion_item.data and entry1.completion_item.data.score
	local s2 = entry2.completion_item.data and entry2.completion_item.data.score
	if s1 and s2 then
		if s1 ~= s2 then
			return s1 > s2
		end
	end
end
