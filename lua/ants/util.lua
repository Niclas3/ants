M = {}
function M.str2array(str)
	local name = ""
	local array = {}
	for ch in string.gmatch(str, ".") do
		if ch == "," or ch == "" then
			table.insert(array, name)
			name = ""
		else
			name = name .. ch
		end
	end
	table.insert(array, name)
	return array
end

function M.printf(fmt, ...)
	print(string.format(fmt, ...))
end

function M.print_table(t)
	for key, value in pairs(t) do
		M.printf("%s : %s", key, value)
	end
end

function M.safe_get_win_var(name, win)
	local status, value = pcall(vim.api.nvim_win_get_var, win, name)
	if status then
		return value
	else
		return nil
	end
end

function M.safe_set_win_var(name, value, win)
	local status, _ = pcall(vim.api.nvim_win_set_var, win, name, value)
	if status then
		return true
	else
		return false
	end
end
function M.safe_del_win_var(name, win)
	vim.api.nvim_win_del_var(win, name)
end

function M.safe_get_win_var_once(name, win)
	local value = M.safe_get_win_var(name, win)
	if value then
		M.safe_del_win_var(name, win)
                return value
	end
	return nil
end

function M.with(handler, config)
	return function(e, r, ctx, _)
		handler(e, r, ctx, config)
	end
end

return M
