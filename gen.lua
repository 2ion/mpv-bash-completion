#!/usr/bin/env lua

-- Bash completion generator for the mpv media player
-- Compatible with Lua 5.{1,2,3} and LuaJIT

-- Set the following environment variables to pass parameters. Other
-- ways of interfacing are not supported:
--
--    MPV_BASHCOMPGEN_VERBOSE     Enable debug output on stderr
--    MPV_BASHCOMPGEN_MPV_CMD     mpv binary to use. Defaults to 'mpv',
--                                using the shell's $PATH.
--    MPV_BASHCOMPGEN_MPV_VERSION Marker to place in the generated file.
--                                Normally, this is the mpv version.

local VERBOSE     = not not os.getenv("MPV_BASHCOMPGEN_VERBOSE") or false
local MPV_CMD     = os.getenv("MPV_BASHCOMPGEN_MPV_CMD") or "mpv"
local MPV_VERSION = os.getenv("MPV_BASHCOMPGEN_MPV_VERSION")

-----------------------------------------------------------------------

if _VERSION == "Lua 5.1" then table.unpack = unpack end

-----------------------------------------------------------------------

-- Helper functions

local function log(s, ...)
  if VERBOSE then
    io.stderr:write(string.format(s.."\n", ...))
  end
end

-- Reporting on optionList() result
local function debug_categories(ot)
  if not VERBOSE then return end
  local lines = {}
  local function count(t)
    local n = 0
    for e,_ in pairs(t) do
      n = n + 1
    end
    return n
  end
  local sum = 0
  for cat,t in pairs(ot) do
    local c = count(t)
    table.insert(lines, string.format("      : %s -> %d", cat, count(t)))
    sum = sum + c
  end
  table.sort(lines)
  table.insert(lines, string.format("======: %d", sum))
  log(table.concat(lines, "\n"))
end

local function basename(s)
  return s:match("^.-([^/]+)$")
end

local function run(cmd, softfail, ...)
  local argv = table.concat({...}, " ")
  log("   run: %s %s", cmd, argv)
  if softfail then
    return io.popen(string.format("%s " .. argv, cmd), "r")
  else
    return assert(io.popen(string.format("%s " .. argv, cmd), "r"))
  end
end

local function mpv(...)
  return run(MPV_CMD, false, "--no-config", ...)
end

local function xrandr()
  local r =  run("xrandr", true)
  if not r then
    log("xrandr: failed to run, ignoring")
    return nil
  end
  return r
end

local function assert_read(h, w)
  return assert(h:read(w or "*all"), "can't read from file handle: no data")
end

local function getMpvVersion()
  local h = mpv("--version")
  local s = assert_read(h, "*line")
  h:close()
  return s:match("^%S+ (%S+)")
end

local function oneOf(n, ...)
  for _,v in ipairs{...} do
    if n == v then return true end
  end
  return false
end

local function map(t, f)
  local u = {}
  for _,v in ipairs(t) do
    table.insert(u, f(v))
  end
  return u
end

local function mapcat(t, f, c)
  return table.concat(map(t, f), c)
end

local function mapcats(t, f)
  return mapcat(t, f, " ")
end

local function mapcator(t, f)
  return mapcat(t, f, "|")
end

local function unique(t)
  local u, f = {}, {}
  for _,v in pairs(t) do
    if v and not f[v] then
      table.insert(u, v)
      f[v] = true
    end
  end
  return u
end

local Option = setmetatable({}, {
  __call = function (t, clist)
    local o = {}
    if type(clist)=="table" and #clist > 0 then
      o.clist = unique(clist)
    end
    return setmetatable(o, { __index = t })
  end
})

local function optionList()
  local h = mpv("--list-options")
  local t = {}

  local function expandObject(o)
    local h = mpv(string.format("--%s help", o))
    local clist = {}
    for l in h:lines() do
      local m = l:match("^%s%s(%S+)")
      if m then table.insert(clist, m) end
    end
    h:close()
    return clist
  end

  local function getRawVideoMpFormats()
    local h = mpv("--demuxer-rawvideo-mp-format=help")
    local line = assert_read(h)
    local clist = {}
    line = line:match(": (.*)")
    for f in line:gmatch("%w+") do
      table.insert(clist, f)
    end
    h:close()
    return clist
  end

  local function getCommonXrandrResList()
    local h = xrandr()
    if not h then return end
    local d = assert_read(h)
    h:close()
    local clist = {}
    for res in d:gmatch("(%d+x%d+)") do
      table.insert(clist, res)
    end
    table.sort(clist, function (a, b)
      local x  = a:match("^(%d+)x")
      local y  = b:match("^(%d+)x")
      return tonumber(x) > tonumber(y)
    end)
    return unique(clist)
  end

  local function extractChoices(tail)
    local sub = tail:match("Choices: ([^()]+)")
    local clist = {}
    for c in sub:gmatch("%S+") do
      table.insert(clist, c)
    end
    return clist
  end

  local function extractDefault(tail)
    return tail:match("default: ([^)]+)")
  end

  local function extractRange(tail)
    local a, b = tail:match("%(([%d.-]+) to ([%d.-]+)%)")
    if a and b then
      return tostring(a), tostring(b)
    else
      return nil
    end
  end

  local function wantsFile(tail)
    local m = tail:match("%[file%]")
    return m and true or false
  end

  local function hasNoCfg(tail)
    local m = tail:match("%[nocfg%]") -- or tail:match("%[global%]") -- Fuck.
    return m and true or false
  end

  local videoFormats = getRawVideoMpFormats()
  local x11ResList = getCommonXrandrResList()

  local function parseOpt(o, tail)
    local ot = tail:match("(%S+)")
    local clist = nil

    if oneOf(ot, "Integer", "Double", "Float", "Integer64")
                              then clist = { extractDefault(tail), extractRange(tail) }
                                   ot = "Numeric"
    elseif ot == "Flag"       then if hasNoCfg(tail) or o:match("^no%-") then ot = "Single"
                                   else clist = { "yes", "no", extractDefault(tail) } end
    elseif ot == "Audio"      then clist = { extractDefault(tail), extractRange(tail) }
    elseif ot == "Choices:"   then clist = { extractRange(tail), extractDefault(tail), table.unpack(extractChoices(tail)) }
                                   ot = "Choice"
    elseif ot == "Color"      then clist = { "#ffffff", "1.0/1.0/1.0/1.0" }
    elseif ot == "FourCC"     then clist = { "YV12", "UYVY", "YUY2", "I420", "other" }
    elseif ot == "Image"      then clist = videoFormats
    elseif ot == "Int[-Int]"  then clist = { "j-k" }
                                   ot = "Numeric"
    elseif ot == "Key/value"  then ot = "String"
    elseif ot == "Object"     then clist = expandObject(o)
    elseif ot == "Output"     then clist = { "all=no", "all=fatal", "all=error", "all=warn", "all=info", "all=status", "all=v", "all=debug", "all=trace" }
                                   ot = "String"
    elseif ot == "Relative"   then clist = { "-60", "60", "50%" }
                                   ot = "Position"
    elseif ot == "String"     then if wantsFile(tail) then ot = "File" else clist = extractDefault(tail) end
    elseif ot == "Time"       then clist = { "00:00:00" }
    elseif ot == "Window"     then clist = x11ResList
                                   ot = "Dimen"
    else
      ot = "Single"
    end

    t[ot] = t[ot] or {}
    local oo = Option(clist)
    t[ot][o] = oo
    log("option: %s :: %s -> [%d]", o, ot, oo.clist and #oo.clist or 0)
  end

  for s in h:lines() do
    local o, s= s:match("^ %-%-(%S+)%s+(%S.*)")
    if o then parseOpt(o, s) end
  end

  h:close()

  -- --af*/--vf* list aliases
  local no = {}
  for o,p in pairs(t.Object) do
    if o:sub(-1) == "*" then
      local stem = o:sub(1, -2)
      local alter = t.Object[stem.."-defaults"]
      for _,variant in pairs(p.clist) do
        log(" alias: %s -> %s", variant, stem)
        no[variant] = alter
      end
      no[stem] = alter
    else
      no[o] = p
    end
  end
  t.Object = no

  return t
end

local function createScript(olist)
  local lines = {[[#!/bin/bash
# mpv(1) Bash completion
# Generated for mpv ]]..MPV_VERSION,
[[if (( $BASH_VERSINFO < 4 )); then
  echo "$0: this completion function does only work with Bash >= 4. You are using Bash 3."
  exit 1
fi]],
[[_mpv(){
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  COMP_WORDBREAKS=${COMP_WORDBREAKS/=/}
  compopt +o default +o filenames]]}

  local function ofType(...)
    local t = {}
    for _,k in ipairs{...} do
      for u,v in pairs(olist[k]) do
        t[u] = v
      end
    end
    return pairs(t)
  end

  local function keys(t)
    local u = {}
    for k,_ in pairs(t) do
      table.insert(u, k)
    end
    return u
  end

  local function i(...)
    for _,e in ipairs{...} do
      table.insert(lines, e)
    end
  end

  local all = {}

  i("if [[ -n $cur ]]; then case \"$cur\" in")
  for o,p in ofType("Choice", "Flag") do
    i(string.format("--%s=*) COMPREPLY=($(compgen -W \"%s\" -- \"$cur\")); return;;",
        o, mapcats(p.clist, function (e) return string.format("--%s=%s", o, e) end)))
    table.insert(all, string.format("--%s=", o))
  end
  i("esac; fi")

  i("if [[ -n $prev ]]; then case \"$prev\" in")
  i(string.format("%s) _filedir; return;;",
    mapcator(keys(olist.File), function (e)
      local o = string.format("--%s", e)
      table.insert(all, o)
      return o
    end)))
  for o, p in ofType("Object", "Numeric", "Audio", "Color", "FourCC", "Image",
    "String", "Position", "Time", "Dimen") do
    if p.clist then table.sort(p.clist) end
    i(string.format("--%s) COMPREPLY=($(compgen -W \"%s\" -- \"$cur\")); return;;",
      o, p.clist and table.concat(p.clist, " ") or ""))
    table.insert(all, string.format("--%s", o))
  end
  i("esac; fi")

  i("if [[ $cur =~ ^- ]]; then")
  for o,_ in ofType("Single") do
    table.insert(all, string.format("--%s", o))
  end
  i(string.format("COMPREPLY=($(compgen -W \"%s\" -- \"$cur\")); return;",
    table.concat(all, " ")))
  i("fi")

  i("compopt -o filenames -o default; _filedir")

  i("}", "complete -o nospace -F _mpv "..basename(MPV_CMD))
  return table.concat(lines, "\n")
end

local function main()
  MPV_VERSION = MPV_VERSION or getMpvVersion()
  local l = optionList()
  debug_categories(l)
  print(createScript(l))
  return 0
end

os.exit(main())