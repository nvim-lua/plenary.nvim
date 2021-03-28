-- Don't edit this file, it was generated. See scripts/update_nvim_objects.lua


local tbl = require('plenary.tbl')



local Buffer = {}
Buffer.__index = Buffer

function Buffer.new(id)
  return setmetatable({id = id}, Buffer)
end

function Buffer.is_buffer(object)
  return getmetatable(object) == Buffer
end

function Buffer.prefix()
  return "nvim_buf_"
end



local Tabpage = {}
Tabpage.__index = Tabpage

function Tabpage.new(id)
  return setmetatable({id = id}, Tabpage)
end

function Tabpage.is_tabpage(object)
  return getmetatable(object) == Tabpage
end

function Tabpage.prefix()
  return "nvim_tabpage_"
end



local Window = {}
Window.__index = Window

function Window.new(id)
  return setmetatable({id = id}, Window)
end

function Window.is_window(object)
  return getmetatable(object) == Window
end

function Window.prefix()
  return "nvim_win_"
end



local Nvim = {
  Buffer = Buffer,
  Tabpage = Tabpage,
  Window = Window,
}



function Buffer:line_count(...)
  return vim.api.nvim_buf_line_count(self.id, ...)
end



function Buffer:attach(...)
  return vim.api.nvim_buf_attach(self.id, ...)
end



function Buffer:detach(...)
  return vim.api.nvim_buf_detach(self.id, ...)
end



function Buffer:get_lines(...)
  return vim.api.nvim_buf_get_lines(self.id, ...)
end



function Buffer:set_lines(...)
  return vim.api.nvim_buf_set_lines(self.id, ...)
end



function Buffer:set_text(...)
  return vim.api.nvim_buf_set_text(self.id, ...)
end



function Buffer:get_offset(...)
  return vim.api.nvim_buf_get_offset(self.id, ...)
end



function Buffer:get_var(...)
  return vim.api.nvim_buf_get_var(self.id, ...)
end



function Buffer:get_changedtick(...)
  return vim.api.nvim_buf_get_changedtick(self.id, ...)
end



function Buffer:get_keymap(...)
  return vim.api.nvim_buf_get_keymap(self.id, ...)
end



function Buffer:set_keymap(...)
  return vim.api.nvim_buf_set_keymap(self.id, ...)
end



function Buffer:del_keymap(...)
  return vim.api.nvim_buf_del_keymap(self.id, ...)
end



function Buffer:get_commands(...)
  return vim.api.nvim_buf_get_commands(self.id, ...)
end



function Buffer:set_var(...)
  return vim.api.nvim_buf_set_var(self.id, ...)
end



function Buffer:del_var(...)
  return vim.api.nvim_buf_del_var(self.id, ...)
end



function Buffer:get_option(...)
  return vim.api.nvim_buf_get_option(self.id, ...)
end



function Buffer:set_option(...)
  return vim.api.nvim_buf_set_option(self.id, ...)
end



function Buffer:get_name(...)
  return vim.api.nvim_buf_get_name(self.id, ...)
end



function Buffer:set_name(...)
  return vim.api.nvim_buf_set_name(self.id, ...)
end



function Buffer:is_loaded(...)
  return vim.api.nvim_buf_is_loaded(self.id, ...)
end



function Buffer:delete(...)
  return vim.api.nvim_buf_delete(self.id, ...)
end



function Buffer:is_valid(...)
  return vim.api.nvim_buf_is_valid(self.id, ...)
end



function Buffer:get_mark(...)
  return vim.api.nvim_buf_get_mark(self.id, ...)
end



function Buffer:get_extmark_by_id(...)
  return vim.api.nvim_buf_get_extmark_by_id(self.id, ...)
end



function Buffer:get_extmarks(...)
  return vim.api.nvim_buf_get_extmarks(self.id, ...)
end



function Buffer:set_extmark(...)
  return vim.api.nvim_buf_set_extmark(self.id, ...)
end



function Buffer:del_extmark(...)
  return vim.api.nvim_buf_del_extmark(self.id, ...)
end



function Buffer:add_highlight(...)
  return vim.api.nvim_buf_add_highlight(self.id, ...)
end



function Buffer:clear_namespace(...)
  return vim.api.nvim_buf_clear_namespace(self.id, ...)
end



function Buffer:set_virtual_text(...)
  return vim.api.nvim_buf_set_virtual_text(self.id, ...)
end



function Buffer:call(...)
  return vim.api.nvim_buf_call(self.id, ...)
end



function Tabpage:list_wins(...)
  local res = vim.api.nvim_tabpage_list_wins(self.id, ...)
  return tbl.map_inplace(res, Window.new)
end



function Tabpage:get_var(...)
  return vim.api.nvim_tabpage_get_var(self.id, ...)
end



function Tabpage:set_var(...)
  return vim.api.nvim_tabpage_set_var(self.id, ...)
end



function Tabpage:del_var(...)
  return vim.api.nvim_tabpage_del_var(self.id, ...)
end



function Tabpage:get_win(...)
  local res = vim.api.nvim_tabpage_get_win(self.id, ...)
  return Window.new(res)
end



function Tabpage:get_number(...)
  return vim.api.nvim_tabpage_get_number(self.id, ...)
end



function Tabpage:is_valid(...)
  return vim.api.nvim_tabpage_is_valid(self.id, ...)
end



function Nvim:ui_attach(...)
  return vim.api.nvim_ui_attach(...)
end



function Nvim:ui_detach(...)
  return vim.api.nvim_ui_detach(...)
end



function Nvim:ui_try_resize(...)
  return vim.api.nvim_ui_try_resize(...)
end



function Nvim:ui_set_option(...)
  return vim.api.nvim_ui_set_option(...)
end



function Nvim:ui_try_resize_grid(...)
  return vim.api.nvim_ui_try_resize_grid(...)
end



function Nvim:ui_pum_set_height(...)
  return vim.api.nvim_ui_pum_set_height(...)
end



function Nvim:ui_pum_set_bounds(...)
  return vim.api.nvim_ui_pum_set_bounds(...)
end



function Nvim:exec(...)
  return vim.api.nvim_exec(...)
end



function Nvim:command(...)
  return vim.api.nvim_command(...)
end



function Nvim:get_hl_by_name(...)
  return vim.api.nvim_get_hl_by_name(...)
end



function Nvim:get_hl_by_id(...)
  return vim.api.nvim_get_hl_by_id(...)
end



function Nvim:get_hl_id_by_name(...)
  return vim.api.nvim_get_hl_id_by_name(...)
end



function Nvim:set_hl(...)
  return vim.api.nvim_set_hl(...)
end



function Nvim:feedkeys(...)
  return vim.api.nvim_feedkeys(...)
end



function Nvim:input(...)
  return vim.api.nvim_input(...)
end



function Nvim:input_mouse(...)
  return vim.api.nvim_input_mouse(...)
end



function Nvim:replace_termcodes(...)
  return vim.api.nvim_replace_termcodes(...)
end



function Nvim:eval(...)
  return vim.api.nvim_eval(...)
end



function Nvim:exec_lua(...)
  return vim.api.nvim_exec_lua(...)
end



function Nvim:notify(...)
  return vim.api.nvim_notify(...)
end



function Nvim:call_function(...)
  return vim.api.nvim_call_function(...)
end



function Nvim:call_dict_function(...)
  return vim.api.nvim_call_dict_function(...)
end



function Nvim:strwidth(...)
  return vim.api.nvim_strwidth(...)
end



function Nvim:list_runtime_paths(...)
  return vim.api.nvim_list_runtime_paths(...)
end



function Nvim:get_runtime_file(...)
  return vim.api.nvim_get_runtime_file(...)
end



function Nvim:set_current_dir(...)
  return vim.api.nvim_set_current_dir(...)
end



function Nvim:get_current_line(...)
  return vim.api.nvim_get_current_line(...)
end



function Nvim:set_current_line(...)
  return vim.api.nvim_set_current_line(...)
end



function Nvim:del_current_line(...)
  return vim.api.nvim_del_current_line(...)
end



function Nvim:get_var(...)
  return vim.api.nvim_get_var(...)
end



function Nvim:set_var(...)
  return vim.api.nvim_set_var(...)
end



function Nvim:del_var(...)
  return vim.api.nvim_del_var(...)
end



function Nvim:get_vvar(...)
  return vim.api.nvim_get_vvar(...)
end



function Nvim:set_vvar(...)
  return vim.api.nvim_set_vvar(...)
end



function Nvim:get_option(...)
  return vim.api.nvim_get_option(...)
end



function Nvim:get_all_options_info(...)
  return vim.api.nvim_get_all_options_info(...)
end



function Nvim:get_option_info(...)
  return vim.api.nvim_get_option_info(...)
end



function Nvim:set_option(...)
  return vim.api.nvim_set_option(...)
end



function Nvim:echo(...)
  return vim.api.nvim_echo(...)
end



function Nvim:out_write(...)
  return vim.api.nvim_out_write(...)
end



function Nvim:err_write(...)
  return vim.api.nvim_err_write(...)
end



function Nvim:err_writeln(...)
  return vim.api.nvim_err_writeln(...)
end



function Nvim:list_bufs(...)
  local res = vim.api.nvim_list_bufs(...)
  return tbl.map_inplace(res, Buffer.new)
end



function Nvim:get_current_buf(...)
  local res = vim.api.nvim_get_current_buf(...)
  return Buffer.new(res)
end



function Nvim:set_current_buf(...)
  return vim.api.nvim_set_current_buf(...)
end



function Nvim:list_wins(...)
  local res = vim.api.nvim_list_wins(...)
  return tbl.map_inplace(res, Window.new)
end



function Nvim:get_current_win(...)
  local res = vim.api.nvim_get_current_win(...)
  return Window.new(res)
end



function Nvim:set_current_win(...)
  return vim.api.nvim_set_current_win(...)
end



function Nvim:create_buf(...)
  local res = vim.api.nvim_create_buf(...)
  return Buffer.new(res)
end



function Nvim:open_term(...)
  return vim.api.nvim_open_term(...)
end



function Nvim:chan_send(...)
  return vim.api.nvim_chan_send(...)
end



function Nvim:open_win(...)
  local res = vim.api.nvim_open_win(...)
  return Window.new(res)
end



function Nvim:list_tabpages(...)
  local res = vim.api.nvim_list_tabpages(...)
  return tbl.map_inplace(res, Tabpage.new)
end



function Nvim:get_current_tabpage(...)
  local res = vim.api.nvim_get_current_tabpage(...)
  return Tabpage.new(res)
end



function Nvim:set_current_tabpage(...)
  return vim.api.nvim_set_current_tabpage(...)
end



function Nvim:create_namespace(...)
  return vim.api.nvim_create_namespace(...)
end



function Nvim:get_namespaces(...)
  return vim.api.nvim_get_namespaces(...)
end



function Nvim:paste(...)
  return vim.api.nvim_paste(...)
end



function Nvim:put(...)
  return vim.api.nvim_put(...)
end



function Nvim:subscribe(...)
  return vim.api.nvim_subscribe(...)
end



function Nvim:unsubscribe(...)
  return vim.api.nvim_unsubscribe(...)
end



function Nvim:get_color_by_name(...)
  return vim.api.nvim_get_color_by_name(...)
end



function Nvim:get_color_map(...)
  return vim.api.nvim_get_color_map(...)
end



function Nvim:get_context(...)
  return vim.api.nvim_get_context(...)
end



function Nvim:load_context(...)
  return vim.api.nvim_load_context(...)
end



function Nvim:get_mode(...)
  return vim.api.nvim_get_mode(...)
end



function Nvim:get_keymap(...)
  return vim.api.nvim_get_keymap(...)
end



function Nvim:set_keymap(...)
  return vim.api.nvim_set_keymap(...)
end



function Nvim:del_keymap(...)
  return vim.api.nvim_del_keymap(...)
end



function Nvim:get_commands(...)
  return vim.api.nvim_get_commands(...)
end



function Nvim:get_api_info(...)
  return vim.api.nvim_get_api_info(...)
end



function Nvim:set_client_info(...)
  return vim.api.nvim_set_client_info(...)
end



function Nvim:get_chan_info(...)
  return vim.api.nvim_get_chan_info(...)
end



function Nvim:list_chans(...)
  return vim.api.nvim_list_chans(...)
end



function Nvim:call_atomic(...)
  return vim.api.nvim_call_atomic(...)
end



function Nvim:parse_expression(...)
  return vim.api.nvim_parse_expression(...)
end



function Nvim:list_uis(...)
  return vim.api.nvim_list_uis(...)
end



function Nvim:get_proc_children(...)
  return vim.api.nvim_get_proc_children(...)
end



function Nvim:get_proc(...)
  return vim.api.nvim_get_proc(...)
end



function Nvim:select_popupmenu_item(...)
  return vim.api.nvim_select_popupmenu_item(...)
end



function Nvim:set_decoration_provider(...)
  return vim.api.nvim_set_decoration_provider(...)
end



function Window:get_buf(...)
  local res = vim.api.nvim_win_get_buf(self.id, ...)
  return Buffer.new(res)
end



function Window:set_buf(...)
  return vim.api.nvim_win_set_buf(self.id, ...)
end



function Window:get_cursor(...)
  return vim.api.nvim_win_get_cursor(self.id, ...)
end



function Window:set_cursor(...)
  return vim.api.nvim_win_set_cursor(self.id, ...)
end



function Window:get_height(...)
  return vim.api.nvim_win_get_height(self.id, ...)
end



function Window:set_height(...)
  return vim.api.nvim_win_set_height(self.id, ...)
end



function Window:get_width(...)
  return vim.api.nvim_win_get_width(self.id, ...)
end



function Window:set_width(...)
  return vim.api.nvim_win_set_width(self.id, ...)
end



function Window:get_var(...)
  return vim.api.nvim_win_get_var(self.id, ...)
end



function Window:set_var(...)
  return vim.api.nvim_win_set_var(self.id, ...)
end



function Window:del_var(...)
  return vim.api.nvim_win_del_var(self.id, ...)
end



function Window:get_option(...)
  return vim.api.nvim_win_get_option(self.id, ...)
end



function Window:set_option(...)
  return vim.api.nvim_win_set_option(self.id, ...)
end



function Window:get_position(...)
  return vim.api.nvim_win_get_position(self.id, ...)
end



function Window:get_tabpage(...)
  local res = vim.api.nvim_win_get_tabpage(self.id, ...)
  return Tabpage.new(res)
end



function Window:get_number(...)
  return vim.api.nvim_win_get_number(self.id, ...)
end



function Window:is_valid(...)
  return vim.api.nvim_win_is_valid(self.id, ...)
end



function Window:set_config(...)
  return vim.api.nvim_win_set_config(self.id, ...)
end



function Window:get_config(...)
  return vim.api.nvim_win_get_config(self.id, ...)
end



function Window:close(...)
  return vim.api.nvim_win_close(self.id, ...)
end

return Nvim