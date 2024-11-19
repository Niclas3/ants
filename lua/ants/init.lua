local M = {}
local util = require("ants.util")

---comment
---@param config table | nil
function M.setup(_) end

local augroup = vim.api.nvim_create_augroup("test_group", { clear = false })

local function _create_tmp_win(buf_id, row, col, width, height)
	local win = vim.api.nvim_open_win(buf_id, false, {
		relative = "cursor",
		row = row,
		col = col,
		width = width,
		height = height,
		border = "double",
		zindex = 250,
	})
	return win
end

--- @param str table | nil
local function create_win_with_text(str)
	if str then
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, str)
		local row_rel_cursor = #str + 2
		local col_rel_cursor = 4
		local wid = _create_tmp_win(buf, -row_rel_cursor, -col_rel_cursor, 50, #str)
		vim.wo[wid].number = false
		vim.wo[wid].relativenumber = false
		vim.bo[buf].modifiable = false
		return wid
	end
	return nil
end

local macro_fn_status = {
	MACRO_STATUS_START = 0,
	MACRO_STATUS_ERROR = 1,
	MACRO_STATUS_END = 2,
	MACRO_STATUS_SYMBOL = 3,
	MACRO_STATUS_PARAMS_START = 4,
	MACRO_STATUS_PARAMS_END = 5,
}

local function is_alph(c)
	return string.match(c, "%a") ~= nil
end

local function make_position(row, col)
	local pos = {} --- row , col
	table.insert(pos, row)
	table.insert(pos, col)
	return pos
end

local function macro_fn_parser(str)
	local status = macro_fn_status.MACRO_STATUS_SYMBOL
	local node = {}
	local params = {}
	for i = 1, #str, 1 do
		local char = str:sub(i, i)
		if status == macro_fn_status.MACRO_STATUS_SYMBOL then
			if is_alph(char) or char == "_" then
				goto continue
			elseif char == "(" then
				status = macro_fn_status.MACRO_STATUS_PARAMS_START
				goto continue
			elseif char == ")" then
			elseif char == "," then
			elseif char == " " then
				goto continue
			else
				return {} -- not a macro function
			end
		elseif status == macro_fn_status.MACRO_STATUS_PARAMS_START then
			if is_alph(char) or char == "_" then
				--add to node
				local pos = make_position(0, i)
				table.insert(node, pos)
			elseif char == ")" then
				table.insert(params, node)
				node = {}
				status = macro_fn_status.MACRO_STATUS_END
			elseif char == "," then
				table.insert(params, node)
				node = {}
			elseif char == " " then
				goto continue
			end
		elseif status == macro_fn_status.MACRO_STATUS_END then
			break
		end
		::continue::
	end
	return params
end

local function is_macro_function(str_array)
	local params_poses = macro_fn_parser(table.concat(str_array))
	if #params_poses ~= 0 then
		return true, params_poses
	end
end

local function create_float_window(str)
	-- filter all things but Macro function
	local cwin = vim.api.nvim_get_current_win()
	local has_win = util.safe_get_win_var("tp_win", cwin)
	local status, _ = is_macro_function(str)
	if has_win ~= nil then
		vim.api.nvim_win_close(has_win, true)
		util.safe_del_win_var("tp_win", cwin)
		has_win = nil
	end
	if status then
		local win = create_win_with_text(str)
		if win == nil then
			return nil
		else
			util.safe_set_win_var("tp_win", win, cwin)
		end
	end
end

local function request_ccls_definition()
	local function handler(err, res, _, _)
		print(vim.inspect(res), vim.inspect(err))
		if not err then
			local obj = res[1]
			if obj then
				-- just for ccls
				local range = obj["targetRange"] or {}
				local uri = obj["targetUri"] or ""
				local tmp_buf = vim.uri_to_bufnr(uri)
				local start_p = range["start"]
				local end_p = range["end"]
				local code = vim.api.nvim_buf_get_text(
					tmp_buf,
					start_p["line"],
					start_p["character"],
					end_p["line"],
					end_p["character"],
					{}
				)
				local str = table.concat(code)
				-- show string at tmp win
				local win = create_float_window(code)
			end
		else
			print(vim.inspect(err))
		end
	end
	local pos_params = vim.lsp.util.make_position_params()
	pos_params.position.character = pos_params.position.character - 2
	print(vim.inspect(pos_params))

	vim.lsp.buf_request(0, "textDocument/definition", pos_params, util.with(handler, { test = true }))
end

vim.api.nvim_create_autocmd("InsertLeave", {
	group = augroup,
	pattern = "*.c, *.h",
	callback = function(_)
		local cwin = vim.api.nvim_get_current_win()
		local win = util.safe_get_win_var_once("tp_win", cwin)
		if win then
			vim.api.nvim_win_close(win, false)
		end
	end,
})

vim.api.nvim_create_autocmd("TextChangedI", {
	group = augroup,
	pattern = "*.c",
	callback = function(_)
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local char = line:sub(col, col)
		if char == "(" then
			request_ccls_definition()
		end
	end,
})
vim.api.nvim_create_autocmd("InsertEnter", {
	group = augroup,
	pattern = "*.c",
	callback = function(_)
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local char = line:sub(col, col)
		if char == "(" then
			request_ccls_definition()
		end
	end,
})

return M
