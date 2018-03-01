#!/usr/bin/env lua

-- Bash completion generator for the mpv media player
-- Compatible with Lua 5.{1,2,3} and LuaJIT

-- Set the following environment variables to pass parameters. Other
-- ways of interfacing are not supported:
--
--    MPV_BASHCOMPGEN_VERBOSE     Enable debug output on stderr
--    MPV_BASHCOMPGEN_MPV_CMD     mpv binary to use. Defaults to 'mpv',
--                                using the shell's $PATH.



local Option_Transformations = require 'mpv_bash_completion.option_transformations'
local Util = require 'mpv_bash_completion.util'
-----------------------------------------------------------------------
-- Shell and stdio ops
-----------------------------------------------------------------------

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
    table.insert(lines, string.format(" %s: %d", cat, count(t)))
    sum = sum + c
  end
  table.sort(lines)
  table.insert(lines, 1, string.format("Found %d options:", sum))
  Util.log(table.concat(lines, "\n"))
end

-----------------------------------------------------------------------
-- Table ops
-----------------------------------------------------------------------

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

local function mapcat   (t, f, c) return table.concat(map(t, f), c) end
local function mapcats  (t, f)    return mapcat(t, f, " ") end
local function mapcator (t, f)    return mapcat(t, f, "|") end

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

-- pairs() replacement with iterating using sorted keys
local function spairs(t)
  assert(t)

  local keys = {}
  for kk,_ in pairs(t) do
    table.insert(keys, kk)
  end

  local len = #keys
  local xi = 1

  local function snext(t, index)
    if not t
      or (index and index == len)
      or len == 0 then
      return nil
    elseif index == nil then
      local k = keys[xi]
      return k, t[k]
    else
      xi = xi + 1
      local k = keys[xi]
      return k, t[k]
    end
  end

  table.sort(keys)
  return snext, t, nil
end

local function keys(t)
  local u = {}
  if t then
    for k,_ in spairs(t) do
      table.insert(u, k)
    end
  end
  return u
end

-----------------------------------------------------------------------
-- Option processing
-----------------------------------------------------------------------

local function normalize_nums(xs)
  local xs = xs
  for i=#xs,1,-1 do
    local e = xs[i]
    local n = tonumber(e)
    if n then
      -- [ 1.0 1 -1.0 -1 ] -> [ 1.0 -1.0 ]
      if e:match("%.0") then
        for j=#xs,1,-1 do
          if i ~= j then
            local k = tonumber(xs[j])
            if k and k == n then table.remove(xs, j) end
          end
        end
      end
      -- [ 1.000000 ] -> [ 1.0 ]
      xs[i] = tostring(n)
    end
  end
  return xs
end

local Option = setmetatable({}, {
  __call = function (t, clist)
    local o = {}
    if type(clist)=="table" and #clist > 0 then
      o.clist = unique(clist)
      o.clist = normalize_nums(o.clist)
    end
    return setmetatable(o, { __index = t })
  end
})

local function parseOpt(t, group, o, tail)
  local ot = tail:match("(%S+)")
  local clist = nil

  ot, clist = Option_Transformations.transform(o, ot, tail)

  local oo = Option(clist)
  log(" + %s :: %s -> [%s]", o, ot, oo.clist and table.concat(oo.clist, " ") or "")

  if group then
    t[ot] = t[ot] or {}
    t[ot][o] = oo
  else
    t[o] = oo
  end
end


local function optionList()
  local t = {}
  local prev_s = nil
  local h = mpv("--list-options")

  local function getAVFilterArgs2(o, f)
    local h = Util.mpv(string.format("--%s %s=help", o, f))
    local t = {}
    for l in h:lines() do
      local o, tail = l:match("^%s([%w%-]+)%s+(%S.*)")
      if o then parseOpt(t, false, o, tail) end
    end
    h:close()
    return t
  end

  for s in h:lines() do
    -- Regular, top-level options
    local o, ss = s:match("^%s+%-%-(%S+)%s+(%S.*)")
    if o then
      prev_s = ss
      parseOpt(t, true, o, ss)
    else
      -- Second-level options (--vf-add, --vf-del etc)
      local o = s:match("^%s+%-%-(%S+)")
      if o then
        parseOpt(t, true, o, prev_s)
      end
    end
  end

  h:close()

  -- Expand filter arguments

  local function stem(name)
    local bound = name:find("-", 1, true)
    if bound then
      return name:sub(1, bound-1)
    end
    return name
  end

  local fargs = {}
  if t.Object then
    for name, value in pairs(t.Object) do
      if name:match("^vf") or name:match("^af") then
        local stem = stem(name)
        for _, filter in ipairs(value.clist or {}) do
          fargs[stem]         = fargs[stem] or {}
          fargs[stem][filter] = fargs[stem][filter] or getAVFilterArgs2(stem, filter)
          fargs[name]         = fargs[stem]
        end -- for
      end -- if
    end -- for
  end -- if
  setmetatable(t, { fargs = fargs })

  -- Resolve new-style aliases

  local function find_option(name)
    for group, members in pairs(t) do
      for o, oo in pairs(members) do
        if o == name then
          return group, oo
        end
      end
    end
    return nil
  end

  if t.Alias then
    for name, val in pairs(t.Alias) do
      local alias = table.remove(val.clist)
      local group, oo = find_option(alias)
      if group then
        log(" * %s is an alias of %s[%s]", name, group, alias)
        t[group][name] = oo
      end
    end
    t.Alias = nil
  end

  return t
end

local function createScript(olist)
  local lines = {}

  local function ofType(...)
    local t = {}
    for _,k in ipairs{...} do
      if olist[k] then
        for u,v in spairs(olist[k]) do
          t[u] = v
        end
      end
    end
    return spairs(t)
  end

  local function emit(...)
    for _,e in ipairs{...} do
      table.insert(lines, e)
    end
  end

  emit([[#!/bin/bash
# mpv ]] .. Util.MPV_VERSION)

  emit([[### LOOKUP TABLES AND CACHES ###
declare _mpv_xrandr_cache
declare -A _mpv_fargs
declare -A _mpv_pargs]])
  local fargs = getmetatable(olist).fargs
  for o,fv in spairs(fargs) do
    for f,pv in spairs(fv) do
      local plist = table.concat(keys(pv), "= ")
      if #plist > 0 then
        plist = plist.."="
        emit(string.format([[_mpv_fargs[%s@%s]="%s"]], o, f, plist))
      end
      for p,pa in spairs(pv) do
        plist = pa.clist and table.concat(pa.clist, " ") or ""
        if #plist > 0 then
          emit(string.format([[_mpv_pargs[%s@%s@%s]="%s"]], o, f, p, plist ))
        end
      end
    end
  end

  emit([=[### HELPER FUNCTIONS ###
_mpv_uniq(){
  local -A w
  local o=""
  for ww in "$@"; do
    if [[ -z "${w[$ww]}" ]]; then
      o="${o}${ww} "
      w[$ww]=x
    fi
  done
  printf "${o% }"
}
_mpv_profiles(){
  type mpv &>/dev/null || return 0;
  mpv --profile help  \
  | awk '{if(NR>2 && $1 != ""){ print $1; }}'
}
_mpv_drm_connectors(){
  type mpv &>/dev/null || return 0;
  mpv --no-config --drm-connector help \
  | awk '/\<connected\>/{ print $1 ; }'
}
_mpv_xrandr(){
  if [[ -z "$_mpv_xrandr_cache" && -n "$DISPLAY" ]] && type xrandr &>/dev/null; then
    _mpv_xrandr_cache=$(xrandr|while read l; do
      [[ $l =~ ([0-9]+x[0-9]+) ]] && echo "${BASH_REMATCH[1]}"
    done)
    _mpv_xrandr_cache=$(_mpv_uniq $_mpv_xrandr_cache)
  fi
  printf "$_mpv_xrandr_cache"
}
_mpv_s(){
  local cmp=$1
  local cur=$2
  COMPREPLY=($(compgen -W "$cmp" -- "$cur"))
}
_mpv_objarg(){
  local prev=${1#--} p=$2 r s t k f
  shift 2
  # Parameter arguments I:
  # All available parameters
  if [[ $p =~ : && $p =~ =$ ]]; then
    # current filter
    s=${p##*,}
    s=${s%%:*}
    # current parameter
    t=${p%=}
    t=${t##*:}
    # index key
    k="$prev@$s@$t"
    if [[ ${_mpv_pargs[$k]+x} ]]; then
      for q in ${_mpv_pargs[$k]}; do
        r="${r}${p}${q} "
      done
    fi

  # Parameter arguments II:
  # Fragment completion
  elif [[ ${p##*,} =~ : && ${p##*:} =~ = ]]; then
    # current filter
    s=${p##*,}
    s=${s%%:*}
    # current parameter
    t=${p%=}
    t=${t##*:}
    t=${t%%=*}
    # index key
    k="$prev@$s@$t"
    # fragment
    f=${p##*=}
    if [[ ${_mpv_pargs[$k]+x} ]]; then
      for q in ${_mpv_pargs[$k]}; do
        if [[ $q =~ ^${f} ]]; then
          r="${r}${p%=*}=${q} "
        fi
      done
    fi

  # Filter parameters I:
  # Suggest all available parameters
  elif [[ $p =~ :$ ]]; then
    # current filter
    s=${p##*,}
    s=${s%%:*}
    # index key
    k="$prev@$s"
    for q in ${_mpv_fargs[$k]}; do
      r="${r}${p}${q} "
    done

  # Filter parameters II:
  # Complete fragment
  elif [[ ${p##*,} =~ : ]]; then
    s=${p##*,}
    s=${s%%:*}
    # current argument
    t=${p##*:}
    # index key
    k="$prev@$s"
    for q in ${_mpv_fargs[$k]}; do
      if [[ $q =~ ^${t} ]]; then
        r="${r}${p%:*}:${q} "
      fi
    done

  # Filter list I:
  # All available filters
  elif [[ $p =~ ,$ ]]; then
    for q in "$@"; do
      r="${r}${p}${q} "
    done

  # Filter list II:
  # Complete fragment
  else
    s=${p##*,}
    for q in "$@"; do
      if [[ $q =~ ^${s} ]]; then
        r="${r}${p%,*},${q} "
      fi
    done
  fi
  printf "${r% }"
}]=])

  emit([=[### COMPLETION ###
_mpv(){
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  # handle --option=a|b|c and --option a=b=c
  COMP_WORDBREAKS=${COMP_WORDBREAKS/=/}
  # handle --af filter=arg,filter2=arg
  COMP_WORDBREAKS=${COMP_WORDBREAKS/:/}
  COMP_WORDBREAKS=${COMP_WORDBREAKS/,/}]=])

  local all = setmetatable({}, {
    __call = function (t, o)
      table.insert(t, string.format("--%s", o))
    end
  })

  emit([=[if [[ -n $cur ]]; then case "$cur" in]=])
  for o,p in ofType("Choice", "Flag") do
    emit(string.format([[--%s=*)_mpv_s '%s' "$cur"; return;;]],
        o, mapcats(p.clist, function (e) return string.format("--%s=%s", o, e) end)))
    table.insert(all, string.format("--%s=", o))
  end
  emit("esac; fi")

  emit([=[if [[ -n $prev && ( $cur =~ , || $cur =~ : ) ]]; then case "$prev" in]=])
  for o,p in ofType("Object") do
    if o:match("^[av][fo]") then
      emit(string.format([[--%s)_mpv_s "$(_mpv_objarg "$prev" "$cur" %s)" "$cur";return;;]],
        o, p.clist and table.concat(p.clist, " ") or ""))
    end
  end
  emit("esac; fi")

  emit([=[if [[ -n $prev ]]; then case "$prev" in]=])
  if olist.File then
    emit(string.format("%s)_filedir;return;;",
      mapcator(keys(olist.File), function (e)
        local o = string.format("--%s", e)
        table.insert(all, o)
        return o
      end)))
  end
  if olist.Profile then
    emit(string.format([[%s)_mpv_s "$(_mpv_profiles)" "$cur";return;;]],
      mapcator(keys(olist.Profile), function (e)
        local o = string.format("--%s", e)
        table.insert(all, o)
        return o
      end)))
  end
  if olist.DRMConnector then
    emit(string.format([[%s)_mpv_s "$(_mpv_drm_connectors)" "$cur";return;;]],
      mapcator(keys(olist.DRMConnector), function (e)
            local o = string.format("--%s", e)
            table.insert(all, o)
            return o
    end)))
  end
  if olist.Directory then
    emit(string.format("%s)_filedir -d;return;;",
      mapcator(keys(olist.Directory), function (e)
        local o = string.format("--%s", e)
        table.insert(all, o)
        return o
      end)))
  end
  for o, p in ofType("Object", "Numeric", "Audio", "Color", "FourCC", "Image",
    "String", "Position", "Time") do
    if p.clist then table.sort(p.clist) end
    emit(string.format([[--%s)_mpv_s '%s' "$cur"; return;;]],
      o, p.clist and table.concat(p.clist, " ") or ""))
    all(o)
  end
  for o,p in ofType("Dimen") do
    emit(string.format([[--%s)_mpv_s "$(_mpv_xrandr)" "$cur";return;;]], o))
    all(o)
  end
  emit("esac; fi")

  emit("if [[ $cur =~ ^- ]]; then")
  for o,_ in ofType("Single") do all(o) end
  emit(string.format([[_mpv_s '%s' "$cur"; return;]],
    table.concat(all, " ")))
  emit("fi")

  emit("_filedir")

  emit("}", "complete -o nospace -F _mpv " .. Util.basename(Util.MPV_CMD))
  return table.concat(lines, "\n")
end

-----------------------------------------------------------------------
-- Entry point
-----------------------------------------------------------------------

local function main()

  local l = optionList()
  debug_categories(l)
  print(createScript(l))
  return 0
end

os.exit(main())
