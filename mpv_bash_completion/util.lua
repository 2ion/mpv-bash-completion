local MPV_CMD = os.getenv("MPV_BASHCOMPGEN_MPV_CMD") or "mpv"
local VERBOSE = not not os.getenv("MPV_BASHCOMPGEN_VERBOSE") or false

local function log(s, ...)
  if VERBOSE then
    io.stderr:write(string.format(s.."\n", ...))
  end
end

local function basename(s)
  return s:match("^.-([^/]+)$")
end

local function run(cmd, ...)
  local argv = table.concat({...}, " ")
  log("%s %s", cmd, argv)
  return assert(io.popen(string.format("%s " .. argv, cmd), "r"))
end

local function mpv(...)
  return run(MPV_CMD, "--no-config", ...)
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

return {
  MPV_CMD     = MPV_CMD,
  MPV_VERSION = getMpvVersion(),
  assert_read = assert_read,
  basename    = basename,
  mpv         = mpv,
  run         = run,
}
