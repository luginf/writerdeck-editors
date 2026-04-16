#!/usr/bin/env lua
--[[
  writerdeck — a minimal TUI writing program for a dedicated writing device.
  Requires: luarocks install lcurses luafilesystem
  or: sudo apt install lua-curses lua-filesystem
  Usage:    lua writerdeck.lua
]]

local curses = require("curses")
local lfs    = require("lfs")

-- ── Config ───────────────────────────────────────────────────────────────────

local HOME        = os.getenv("HOME") or "."
local DOCS_DIR    = HOME .. "/Documents/writerdeck"
local CURSOR_FILE = DOCS_DIR .. "/.cursors.json"
local FILE_EXT    = ".txt"
local TAB_WIDTH   = 4

-- ── Minimal JSON ──────────────────────────────────────────────────────────────

local function json_encode(obj)
  local t = type(obj)
  if t == "number"  then return tostring(obj) end
  if t == "boolean" then return tostring(obj) end
  if t == "string"  then
    return '"' .. obj:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n') .. '"'
  end
  if t == "table" then
    if #obj > 0 then
      local parts = {}
      for _, v in ipairs(obj) do parts[#parts+1] = json_encode(v) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(obj) do
        parts[#parts+1] = '"' .. tostring(k) .. '":' .. json_encode(v)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

local function json_decode(s)
  local pos = 1
  local function skip_ws()
    while pos <= #s and s:sub(pos,pos):match("%s") do pos = pos + 1 end
  end
  local parse_value
  local function parse_string()
    pos = pos + 1  -- skip opening "
    local r = {}
    while pos <= #s do
      local c = s:sub(pos, pos)
      if c == '"' then pos = pos + 1; return table.concat(r) end
      if c == '\\' then
        pos = pos + 1
        local e = s:sub(pos, pos)
        local esc = {['"']='"',['\\']='\\',['n']='\n',['t']='\t',['r']='\r'}
        r[#r+1] = esc[e] or e
      else
        r[#r+1] = c
      end
      pos = pos + 1
    end
    return table.concat(r)
  end
  local function parse_number()
    local i = pos
    while pos <= #s and s:sub(pos,pos):match("[%d%.%+%-%eE]") do pos = pos + 1 end
    return tonumber(s:sub(i, pos-1))
  end
  local function parse_array()
    pos = pos + 1  -- skip [
    local arr = {}
    skip_ws()
    if s:sub(pos,pos) == ']' then pos = pos + 1; return arr end
    while true do
      skip_ws(); arr[#arr+1] = parse_value(); skip_ws()
      local c = s:sub(pos,pos)
      if c == ']' then pos = pos + 1; return arr end
      if c == ',' then pos = pos + 1 end
    end
  end
  local function parse_object()
    pos = pos + 1  -- skip {
    local obj = {}
    skip_ws()
    if s:sub(pos,pos) == '}' then pos = pos + 1; return obj end
    while true do
      skip_ws(); local k = parse_string(); skip_ws(); pos = pos + 1; skip_ws()
      obj[k] = parse_value(); skip_ws()
      local c = s:sub(pos,pos)
      if c == '}' then pos = pos + 1; return obj end
      if c == ',' then pos = pos + 1 end
    end
  end
  parse_value = function()
    skip_ws()
    local c = s:sub(pos,pos)
    if c == '"' then return parse_string()
    elseif c == '[' then return parse_array()
    elseif c == '{' then return parse_object()
    elseif c == 't' then pos = pos + 4; return true
    elseif c == 'f' then pos = pos + 5; return false
    elseif c == 'n' then pos = pos + 4; return nil
    else return parse_number()
    end
  end
  return parse_value()
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ensure_docs_dir()
  os.execute("mkdir -p " .. DOCS_DIR)
end

local function basename(path)
  return path:match("([^/]+)$") or path
end

local function has_ext(name)
  return name:match("%.[^%.]+$") ~= nil
end

local function fattr(path, key)
  local a = lfs.attributes(path)
  return a and a[key]
end

local function file_exists(path)
  return lfs.attributes(path) ~= nil
end

local function list_docs()
  ensure_docs_dir()
  local files = {}
  for fname in lfs.dir(DOCS_DIR) do
    if not fname:match("^%.") then
      local fpath = DOCS_DIR .. "/" .. fname
      local a = lfs.attributes(fpath)
      if a and a.mode == "file" then
        files[#files+1] = {name = fname, mtime = a.modification}
      end
    end
  end
  table.sort(files, function(a, b) return a.mtime > b.mtime end)
  local names = {}
  for _, f in ipairs(files) do names[#names+1] = f.name end
  return names
end

local function word_count(lines)
  local n = 0
  for _, line in ipairs(lines) do
    for _ in line:gmatch("%S+") do n = n + 1 end
  end
  return n
end

local function char_count(lines)
  local n = 0
  for _, line in ipairs(lines) do n = n + #line end
  return n
end

-- ── UTF-8 helpers ─────────────────────────────────────────────────────────────

-- Advance cx (0-based byte offset) past one UTF-8 character.
local function utf8_next_cx(s, cx)
  if cx >= #s then return cx end
  local b = s:byte(cx + 1)
  if     b < 0x80 then return cx + 1
  elseif b < 0xE0 then return cx + 2
  elseif b < 0xF0 then return cx + 3
  else                  return cx + 4
  end
end

-- Retreat cx (0-based byte offset) back one UTF-8 character.
local function utf8_prev_cx(s, cx)
  if cx <= 0 then return 0 end
  cx = cx - 1
  while cx > 0 and s:byte(cx + 1) >= 0x80 and s:byte(cx + 1) < 0xC0 do
    cx = cx - 1
  end
  return cx
end

-- Read one key from stdscr. Returns (keycode, utf8str).
-- For ASCII/special keys: (keycode, nil).
-- For multi-byte UTF-8 input:  (-1, the_utf8_string).
local function read_char(win)
  local b = win:getch()
  if not b or b < 0 or b > 255 then return b, nil end  -- nil or special key
  if b < 0x80 then return b, nil end                   -- plain ASCII
  if b < 0xC0 then return b, nil end                   -- stray continuation byte
  -- Lead byte: collect the right number of continuation bytes
  local nbytes = b < 0xE0 and 1 or b < 0xF0 and 2 or 3
  local s = string.char(b)
  for _ = 1, nbytes do
    local c = win:getch()
    if c and c >= 0x80 and c < 0xC0 then s = s .. string.char(c) end
  end
  return -1, s
end

-- ── Cursor Persistence ────────────────────────────────────────────────────────

-- cy is stored 0-based in the JSON file (compatible with the Python version).
local function load_cursor(filepath)
  local f = io.open(CURSOR_FILE, "r")
  if not f then return 1, 0 end
  local content = f:read("*a"); f:close()
  local ok, data = pcall(json_decode, content)
  if not ok or type(data) ~= "table" then return 1, 0 end
  local p = data[filepath]
  if type(p) == "table" and #p >= 2 then
    return (p[1] or 0) + 1, p[2] or 0  -- cy: 0-based → 1-based
  end
  return 1, 0
end

local function save_cursor(filepath, cy, cx)
  local data = {}
  local f = io.open(CURSOR_FILE, "r")
  if f then
    local content = f:read("*a"); f:close()
    local ok, parsed = pcall(json_decode, content)
    if ok and type(parsed) == "table" then data = parsed end
  end
  data[filepath] = {cy - 1, cx}  -- cy: 1-based → 0-based for storage
  local out = io.open(CURSOR_FILE, "w")
  if out then out:write(json_encode(data)); out:close() end
end

-- ── Word Wrap Engine ──────────────────────────────────────────────────────────

-- Returns list of {scol, ecol} (0-based) for each visual segment of `line`.
local function wrap_line(line, width)
  if width <= 0 then return {{0, #line}} end
  if #line == 0  then return {{0, 0}} end
  local segs = {}
  local pos = 0
  local length = #line
  while pos < length do
    if length - pos <= width then
      segs[#segs+1] = {pos, length}; break
    end
    local chunk_end = pos + width
    -- find last space in line[pos .. chunk_end-1] (0-based range)
    local sub = line:sub(pos+1, chunk_end)
    local last_space = nil
    for i = #sub, 1, -1 do
      if sub:sub(i,i) == ' ' then last_space = i; break end
    end
    -- last_space is 1-based within sub; 0-based in line = pos + last_space - 1
    local break_at = (last_space and last_space > 1) and (pos + last_space - 1) or -1
    if break_at > pos then
      segs[#segs+1] = {pos, break_at}; pos = break_at + 1
    else
      segs[#segs+1] = {pos, chunk_end}; pos = chunk_end
    end
  end
  return segs
end

-- Returns list of {li, scol, ecol}. li is 1-based; scol/ecol are 0-based.
local function build_wrap_map(lines, width)
  local vrows = {}
  for li, line in ipairs(lines) do
    for _, seg in ipairs(wrap_line(line, width)) do
      vrows[#vrows+1] = {li, seg[1], seg[2]}
    end
  end
  return vrows
end

-- Returns (vi, screen_col); vi is 1-based.
local function logical_to_visual(vrows, cy, cx)
  for vi = 1, #vrows do
    local li, scol, ecol = vrows[vi][1], vrows[vi][2], vrows[vi][3]
    if li == cy and scol <= cx and cx <= ecol then
      -- If cx is at the end of a wrapped segment and a next segment on the same
      -- line exists, skip (cursor belongs to the start of the next segment).
      if cx == ecol and ecol > scol and vi < #vrows and vrows[vi+1][1] == li then
        -- continue to next vi
      else
        return vi, cx - scol
      end
    end
  end
  if #vrows > 0 then
    local li, scol, ecol = vrows[#vrows][1], vrows[#vrows][2], vrows[#vrows][3]
    return #vrows, math.max(0, math.min(cx - scol, ecol - scol))
  end
  return 1, 0
end

-- Returns (cy, cx); cy is 1-based.
local function visual_to_logical(vrows, vi, screen_cx)
  if #vrows == 0 then return 1, 0 end
  vi = math.max(1, math.min(vi, #vrows))
  local li, scol, ecol = vrows[vi][1], vrows[vi][2], vrows[vi][3]
  screen_cx = math.max(0, math.min(screen_cx, ecol - scol))
  return li, scol + screen_cx
end

-- ── Status Bar ────────────────────────────────────────────────────────────────

local function draw_status(stdscr, left, right, attr)
  left = left or ""; right = right or ""
  local h, w = stdscr:getmaxyx()
  attr = attr or curses.A_REVERSE
  local gap = math.max(0, w - #left - #right)
  local bar = (left .. string.rep(" ", gap) .. right):sub(1, w)
  stdscr:attron(attr)
  pcall(function() stdscr:mvaddstr(h-1, 0, bar) end)
  stdscr:attroff(attr)
end

local function draw_help_bar(stdscr, text)
  local h, w = stdscr:getmaxyx()
  local line = text:sub(1,w) .. string.rep(" ", math.max(0, w - #text))
  stdscr:attron(curses.A_DIM)
  pcall(function() stdscr:mvaddstr(h-2, 0, line) end)
  stdscr:attroff(curses.A_DIM)
end

-- ── Prompt ────────────────────────────────────────────────────────────────────

local function prompt_input(stdscr, label)
  curses.curs_set(1)
  local h, w = stdscr:getmaxyx()
  local buf = ""
  while true do
    local display = " " .. label .. buf
    local bar = (display .. string.rep(" ", math.max(0, w - #display))):sub(1, w)
    stdscr:attron(curses.A_REVERSE)
    pcall(function() stdscr:mvaddstr(h-1, 0, bar) end)
    stdscr:attroff(curses.A_REVERSE)
    pcall(function() stdscr:move(h-1, #display) end)
    stdscr:refresh()
    local ch, utf8str = read_char(stdscr)
    if ch == 27 then
      curses.curs_set(0); return nil
    elseif ch == curses.KEY_ENTER or ch == 10 or ch == 13 then
      curses.curs_set(0); return buf
    elseif ch == curses.KEY_BACKSPACE or ch == 127 or ch == 8 then
      buf = buf:sub(1, utf8_prev_cx(buf, #buf))
    elseif ch == -1 and utf8str then
      buf = buf .. utf8str
    elseif ch and ch >= 32 and ch < 127 then
      buf = buf .. string.char(ch)
    end
  end
end

local function confirm(stdscr, message)
  local h, w = stdscr:getmaxyx()
  local text = " " .. message .. " (y/n)"
  local bar  = (text .. string.rep(" ", math.max(0, w - #text))):sub(1, w)
  stdscr:attron(curses.A_REVERSE)
  pcall(function() stdscr:mvaddstr(h-1, 0, bar) end)
  stdscr:attroff(curses.A_REVERSE)
  stdscr:refresh()
  while true do
    local ch = stdscr:getch()
    if ch == string.byte('y') or ch == string.byte('Y') then return true end
    if ch == string.byte('n') or ch == string.byte('N') or ch == 27 then return false end
  end
end

-- ── File Browser ──────────────────────────────────────────────────────────────

-- Returns a filepath to edit, or nil to quit.
local function file_browser(stdscr)
  curses.curs_set(0)
  local sel        = 1
  local scroll_off = 0
  local message    = ""

  while true do
    stdscr:erase()
    local h, w = stdscr:getmaxyx()
    local usable = h - 3
    local files  = list_docs()

    -- Header
    local header = " writerdeck"
    stdscr:attron(curses.A_BOLD)
    pcall(function()
      stdscr:mvaddstr(0, 0, header .. string.rep(" ", math.max(0, w - #header)))
    end)
    stdscr:attroff(curses.A_BOLD)

    if #files == 0 then
      local msg = "No documents yet. Press [n] to create one."
      local y = math.floor(h / 2)
      local x = math.max(0, math.floor((w - #msg) / 2))
      stdscr:attron(curses.A_DIM)
      pcall(function() stdscr:mvaddstr(y, x, msg) end)
      stdscr:attroff(curses.A_DIM)
    else
      sel = math.max(1, math.min(sel, #files))
      if sel - 1 < scroll_off then
        scroll_off = sel - 1
      end
      if sel - 1 >= scroll_off + usable then
        scroll_off = sel - 1 - usable + 1
      end

      for i = 0, usable - 1 do
        local idx = scroll_off + i + 1  -- 1-based
        if idx > #files then break end
        local fname = files[idx]
        local fpath = DOCS_DIR .. "/" .. fname
        local a     = lfs.attributes(fpath) or {}
        local size  = a.size or 0
        local mtime = a.modification or 0
        local size_str = size < 1024
            and tostring(size) .. "B"
            or  tostring(math.floor(size / 1024)) .. "K"
        local mtime_str = os.date("%b %d %H:%M", mtime)

        local name_col = 3
        local meta     = string.format("%6s  %s", size_str, mtime_str)
        local max_name = w - name_col - #meta - 2
        local dname    = fname:sub(1, math.max(0, max_name))
        local prefix, attr_flag
        if idx == sel then
          prefix = " \xc2\xbb "   -- UTF-8 for ›
          attr_flag = curses.A_REVERSE
        else
          prefix = "   "
          attr_flag = curses.A_NORMAL
        end
        local gap  = math.max(0, w - name_col - #dname - #meta)
        local line = (prefix .. dname .. string.rep(" ", gap) .. meta):sub(1, w)
        stdscr:attron(attr_flag)
        pcall(function() stdscr:mvaddstr(i + 1, 0, line) end)
        stdscr:attroff(attr_flag)
      end
    end

    draw_help_bar(stdscr, " [enter] open  [n] new  [d] delete  [r] rename  [q] quit")

    if message ~= "" then
      draw_status(stdscr, " " .. message)
      message = ""
    else
      local plural = (#files ~= 1) and "s" or ""
      draw_status(stdscr, " " .. DOCS_DIR,
                  tostring(#files) .. " document" .. plural .. " ")
    end

    stdscr:refresh()
    local ch = stdscr:getch()

    if ch == string.byte('q') then
      return nil

    elseif ch == curses.KEY_UP or ch == string.byte('k') then
      sel = math.max(1, sel - 1)
    elseif ch == curses.KEY_DOWN or ch == string.byte('j') then
      sel = math.min(math.max(1, #files), sel + 1)
    elseif ch == curses.KEY_HOME then
      sel = 1
    elseif ch == curses.KEY_END then
      sel = math.max(1, #files)

    elseif ch == curses.KEY_ENTER or ch == 10 or ch == 13 then
      if #files > 0 then
        return DOCS_DIR .. "/" .. files[sel]
      end

    elseif ch == string.byte('n') then
      local name = prompt_input(stdscr, "new file: ")
      if name then
        name = name:match("^%s*(.-)%s*$")  -- trim
        if name ~= "" and not name:match("^%.") then
          if not has_ext(name) then name = name .. FILE_EXT end
          local fpath = DOCS_DIR .. "/" .. name
          if file_exists(fpath) then
            message = "'" .. name .. "' already exists"
          else
            local nf = io.open(fpath, "w"); if nf then nf:close() end
            return fpath
          end
        end
      end

    elseif ch == string.byte('d') then
      if #files > 0 then
        local fname = files[sel]
        if confirm(stdscr, "delete '" .. fname .. "'?") then
          os.remove(DOCS_DIR .. "/" .. fname)
          message = "deleted '" .. fname .. "'"
          sel = math.max(1, sel - 1)
        end
      end

    elseif ch == string.byte('r') then
      if #files > 0 then
        local fname    = files[sel]
        local new_name = prompt_input(stdscr, "rename '" .. fname .. "' to: ")
        if new_name then
          new_name = new_name:match("^%s*(.-)%s*$")
          if new_name ~= "" then
            if not has_ext(new_name) then new_name = new_name .. FILE_EXT end
            local old_path = DOCS_DIR .. "/" .. fname
            local new_path = DOCS_DIR .. "/" .. new_name
            if file_exists(new_path) then
              message = "'" .. new_name .. "' already exists"
            else
              os.rename(old_path, new_path)
              message = "renamed \xe2\x86\x92 '" .. new_name .. "'"  -- UTF-8 →
            end
          end
        end
      end
    end
  end
end

-- ── Editor ────────────────────────────────────────────────────────────────────

local function editor(stdscr, filepath)
  -- Load file
  local lines
  local f = io.open(filepath, "r")
  if f then
    local content = f:read("*a"); f:close()
    if content and #content > 0 then
      lines = {}
      for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines+1] = line
      end
      -- drop trailing empty line added by the split
      if #lines > 1 and lines[#lines] == "" then
        lines[#lines] = nil
      end
    end
  end
  if not lines or #lines == 0 then lines = {""} end

  -- Restore cursor (cy is 1-based, cx is 0-based)
  local cy, cx = load_cursor(filepath)
  cy = math.max(1, math.min(cy, #lines))
  cx = math.max(0, math.min(cx, #lines[cy]))

  local scroll_y        = 0   -- number of visual rows scrolled (0-based count)
  local target_screen_cx = nil
  local dirty           = false
  local message         = ""
  local msg_time        = 0

  local function save()
    local out = io.open(filepath, "w")
    if out then
      out:write(table.concat(lines, "\n") .. "\n")
      out:close()
    end
    save_cursor(filepath, cy, cx)
    dirty    = false
    message  = "saved"
    msg_time = os.time()
  end

  local function save_and_close()
    save()
    curses.curs_set(0)
  end

  curses.curs_set(1)

  while true do
    stdscr:erase()
    local h, w = stdscr:getmaxyx()
    local text_h = h - 2

    -- Clamp cursor
    cy = math.max(1, math.min(cy, #lines))
    cx = math.max(0, math.min(cx, #lines[cy]))

    -- Build wrap map
    local vrows = build_wrap_map(lines, w)
    local vi_cursor, scx_cursor = logical_to_visual(vrows, cy, cx)

    -- Scroll to keep cursor visible
    if vi_cursor - 1 < scroll_y then
      scroll_y = vi_cursor - 1
    end
    if vi_cursor - 1 >= scroll_y + text_h then
      scroll_y = vi_cursor - 1 - text_h + 1
    end
    scroll_y = math.max(0, math.min(scroll_y, math.max(0, #vrows - text_h)))

    -- Draw wrapped text
    for i = 0, text_h - 1 do
      local vi = scroll_y + i + 1  -- 1-based
      if vi > #vrows then break end
      local li, scol, ecol = vrows[vi][1], vrows[vi][2], vrows[vi][3]
      local segment = lines[li]:sub(scol+1, ecol)
      pcall(function() stdscr:mvaddstr(i, 0, segment) end)
    end

    -- Help bar
    draw_help_bar(stdscr, " ^S save  ^W save+close  ^G goto line ^Q quit")

    -- Status bar
    local fname   = basename(filepath)
    local mod     = dirty and " [+]" or ""
    local left_s  = " " .. fname .. mod
    local wc      = word_count(lines)
    local cc      = char_count(lines)
    local right_s = string.format("ln %d/%d  col %d  %dw %dc ",
                                  cy, #lines, cx + 1, wc, cc)
    if message ~= "" and (os.time() - msg_time < 2) then
      left_s = " " .. message
    end
    draw_status(stdscr, left_s, right_s)

    -- Position cursor on screen
    local screen_row = vi_cursor - 1 - scroll_y
    pcall(function() stdscr:move(screen_row, scx_cursor) end)

    stdscr:refresh()
    local ch, utf8str = read_char(stdscr)
    local continue_sticky = false

    -- ── Navigation ──────────────────────────────────────────────────────────

    if ch == curses.KEY_UP then
      if vi_cursor > 1 then
        if target_screen_cx == nil then target_screen_cx = scx_cursor end
        cy, cx = visual_to_logical(vrows, vi_cursor - 1, target_screen_cx)
      end
      continue_sticky = true

    elseif ch == curses.KEY_DOWN then
      if vi_cursor < #vrows then
        if target_screen_cx == nil then target_screen_cx = scx_cursor end
        cy, cx = visual_to_logical(vrows, vi_cursor + 1, target_screen_cx)
      end
      continue_sticky = true

    elseif ch == curses.KEY_LEFT then
      if cx > 0 then
        cx = utf8_prev_cx(lines[cy], cx)
      elseif cy > 1 then
        cy = cy - 1
        cx = #lines[cy]
      end

    elseif ch == curses.KEY_RIGHT then
      if cx < #lines[cy] then
        cx = utf8_next_cx(lines[cy], cx)
      elseif cy < #lines then
        cy = cy + 1; cx = 0
      end

    elseif ch == curses.KEY_HOME then
      cx = vrows[vi_cursor][2]  -- scol of current visual row

    elseif ch == curses.KEY_END then
      cx = vrows[vi_cursor][3]  -- ecol of current visual row

    elseif ch == curses.KEY_PPAGE then
      local target_vi = math.max(1, vi_cursor - text_h)
      if target_screen_cx == nil then target_screen_cx = scx_cursor end
      cy, cx = visual_to_logical(vrows, target_vi, target_screen_cx)
      continue_sticky = true

    elseif ch == curses.KEY_NPAGE then
      local target_vi = math.min(#vrows, vi_cursor + text_h)
      if target_screen_cx == nil then target_screen_cx = scx_cursor end
      cy, cx = visual_to_logical(vrows, target_vi, target_screen_cx)
      continue_sticky = true

    -- ── Editing ─────────────────────────────────────────────────────────────

    elseif ch == curses.KEY_BACKSPACE or ch == 127 or ch == 8 then
      if cx > 0 then
        local new_cx = utf8_prev_cx(lines[cy], cx)
        lines[cy] = lines[cy]:sub(1, new_cx) .. lines[cy]:sub(cx+1)
        cx = new_cx; dirty = true
      elseif cy > 1 then
        cx = #lines[cy-1]
        lines[cy-1] = lines[cy-1] .. lines[cy]
        table.remove(lines, cy)
        cy = cy - 1; dirty = true
      end

    elseif ch == curses.KEY_DC then
      if cx < #lines[cy] then
        lines[cy] = lines[cy]:sub(1, cx) .. lines[cy]:sub(cx+2)
        dirty = true
      elseif cy < #lines then
        lines[cy] = lines[cy] .. lines[cy+1]
        table.remove(lines, cy+1)
        dirty = true
      end

    elseif ch == curses.KEY_ENTER or ch == 10 or ch == 13 then
      local rest = lines[cy]:sub(cx+1)
      lines[cy]  = lines[cy]:sub(1, cx)
      cy = cy + 1
      table.insert(lines, cy, rest)
      cx = 0; dirty = true

    elseif ch == 9 then  -- Tab
      local spaces = string.rep(" ", TAB_WIDTH)
      lines[cy] = lines[cy]:sub(1, cx) .. spaces .. lines[cy]:sub(cx+1)
      cx = cx + TAB_WIDTH; dirty = true

    -- ── Commands (Ctrl keys) ─────────────────────────────────────────────────

    elseif ch == 19 then  -- Ctrl+S
      save()

    elseif ch == 23 or ch == 17 or ch == 27 then  -- Ctrl+W / Ctrl+Q / Esc
      save_and_close(); return

    elseif ch == 7 then  -- Ctrl+G — goto line
      local num = prompt_input(stdscr, "go to line: ")
      curses.curs_set(1)
      if num then
        num = num:match("^%s*(.-)%s*$")
        if num:match("^%d+$") then
          cy = math.max(1, math.min(tonumber(num), #lines))
          cx = 0
        end
      end

    -- ── Printable characters ─────────────────────────────────────────────────

    elseif ch == -1 and utf8str then   -- multi-byte UTF-8 (accents, etc.)
      lines[cy] = lines[cy]:sub(1, cx) .. utf8str .. lines[cy]:sub(cx+1)
      cx = cx + #utf8str; dirty = true

    elseif ch and ch >= 32 and ch <= 126 then
      lines[cy] = lines[cy]:sub(1, cx) .. string.char(ch) .. lines[cy]:sub(cx+1)
      cx = cx + 1; dirty = true
    end

    if not continue_sticky then target_screen_cx = nil end
  end
end

-- ── Main ──────────────────────────────────────────────────────────────────────

local function main(stdscr)
  curses.raw()
  stdscr:keypad(true)
  curses.use_default_colors()
  pcall(function() curses.set_escdelay(25) end)
  curses.curs_set(0)

  ensure_docs_dir()

  -- If a file was passed as argument, open it directly
  if arg and arg[1] then
    local filepath = arg[1]
    -- Create the file if it doesn't exist yet
    if not file_exists(filepath) then
      local f = io.open(filepath, "w"); if f then f:close() end
    end
    editor(stdscr, filepath)
    return
  end

  while true do
    local filepath = file_browser(stdscr)
    if filepath == nil then break end
    editor(stdscr, filepath)
  end
end

-- Bootstrap
os.setlocale("")          -- must be set before initscr() for UTF-8 display
local stdscr = curses.initscr()
local ok, err = pcall(main, stdscr)
curses.endwin()
if not ok then
  io.stderr:write(tostring(err) .. "\n")
end
print("bye.")
