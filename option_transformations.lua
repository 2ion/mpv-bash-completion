if _VERSION == "Lua 5.1" then table.unpack = unpack end

-----------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-----------------------------------------------------------------------

local function hasNoCfg(tail)
  local m = tail:match("%[nocfg%]") -- or tail:match("%[global%]") -- Fuck.
  return m and true or false
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

local function wantsFile(op, tail)
  local m = tail:match("%[file%]")
  if m then return true end
  for _,re in ipairs{ "%-file[s]?%-", "^script[s]?", "^scripts%-.*" } do
    if op:match(re) then return true end
  end
  return false
end

local function ot_numeric(o, ot, tail, lookup_table)
  return "Numeric", { extractDefault(tail), extractRange(tail) }
end

local function ot_flag(o, ot, tail, lookup_table)
  if  hasNoCfg(tail)
        or o:match("^no%-")
        or o:match("^[{}]$")
  then
    return "Single", nil
  else
    return ot, { "yes", "no", extractDefault(tail) }
end

local function ot_audio(o, ot, tail, lookup_table)
  return ot, { extractDefault(tail), extractRange(tail) }
end

local function ot_choice(o, ot, tail, lookup_table)
  return "Choice", { extractRange(tail), extractDefault(tail), table.unpack(extractChoices(tail)) }
end

local function ot_expandable_choice(o, ot, tail, lookup_table)
  return "Choice", expandChoice(o)
end

local function ot_color(o, ot, tail, lookup_table)
  return ot, { "#ffffff", "1.0/1.0/1.0/1.0" }
end
local function ot_fourcc(o, ot, tail)
  return ot, { "YV12", "UYVY", "YUY2", "I420", "other" }
end

local function ot_image(o, ot, tail, lookup_table)
  return ot, lookup_table.videoFormats
end

local function ot_range(o, ot, tail, lookup_table)
  return "Numeric", { "j-k" }
end

local function ot_key_value(o, ot, tail, lookup_table)
  return "String", nil
end

local function ot_object(o, ot, tail, lookup_table)
  return ot, expandObject(o)
end

local function ot_output(o, ot, tail, lookup_table)
  return "String", { "all=no", "all=fatal", "all=error", "all=warn", "all=info", "all=status", "all=v", "all=debug", "all=trace" }
end

local function ot_relative(o, ot, tail, lookup_table)
  return "Position", { "-60", "60", "50%" }
end

local function ot_string(o, ot, tail, lookup_table)
  local ot = ot
  local clist = nil
  if wantsFile(o, tail) then
    ot = "File"
    if o:match("directory") or o:match("dir") then
      ot = "Directory"
    end
  else
    clist = { extractDefault(tail) }
  end
  return ot, clist
end

local function ot_time(o, ot, tail, lookup_table)
  return ot, { "00:00:00" }
end

local function ot_window(o, ot, tail, lookup_table)
  return "Dimen", nil
end

local function ot_profile(o, ot, tail, lookup_table)
  return ot, {}
end

local function ot_drm_connector(o, ot, tail, lookup_table)
  return ot, {}
end

local function ot_alias(o, ot, tail, lookup_table)
  return "Alias", { tail:match("^alias for (%S+)") or "" }
end

-----------------------------------------------------------------------
-- PRIVATE VARIABLES
-----------------------------------------------------------------------

local OT_HOOKS = {
  Audio            = ot_audio,
  Color            = ot_color,
  DRMConnector     = ot_drm_connector,
  Double           = ot_numeric,
  ExpandableChoice = ot_expandable_choice,
  Flag             = ot_flag,
  Float            = ot_numeric,
  FourCC           = ot_fourcc,
  Image            = ot_image,
  Integer          = ot_numeric,
  Integer64        = ot_numeric,
  Object           = ot_object,
  Output           = ot_output,
  Profile          = ot_profile,
  Relative         = ot_relative,
  String           = ot_string,
  Time             = ot_time,
  Window           = ot_window,
  ["Choices:"]     = ot_choice,
  ["Int[-Int]"]    = ot_range,
  ["Key/value"]    = ot_key_value,
  alias            = ot_alias,
}

local O_OT_OVERRIDES = {
   ["audio-demuxer"]        = "Object",
   ["cscale-window"]        = "Object",
   ["demuxer"]              = "Object",
   ["dscale"]               = "Object",
   ["dscale-window"]        = "Object",
   ["opengl-backend"]       = "Object",
   ["opengl-hwdec-interop"] = "Object",
   ["scale-window"]         = "Object",
   ["sub-demuxer"]          = "Object",
   ["ad"]                   = "Object",
   ["vd"]                   = "Object",
   ["oac"]                  = "Object",
   ["ovc"]                  = "Object",
   ["audio-spdif"]          = "ExpandableChoice",
   ["drm-connector"]        = "DRMConnector",
   ["show-profile"]         = "Profile",
}

local O_OT_MATCHES = {
   ["^profile"] = "Profile",
}

-----------------------------------------------------------------------
-- PUBLIC API
-----------------------------------------------------------------------

return {
  transform = function (o, ot, tail, lookup_table)
    local o = o
    local ot = ot
    local clist = nil

    if O_OT_OVERRIDES[o] then
      ot = O_OT_OVERRIDES[o]
    else
      for regex, _ot in pairs(O_OT_MATCHES) do
        if o:match(regex) then
          ot = _ot
        end
      end
    end

    if OT_HOOKS[ot] then
      ot, clist = OT_HOOKS[ot](o, ot, tail, lookup_table)
    else
      ot = "Single"
    end

    return ot, clist
  end,
}
