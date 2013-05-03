-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local taptcp = Listener.new(nil, "tcp")
local tcppackets = 0
local collectedMessages = {}
local dbgServerPort
local dbgClientPort
local ports = {}

local log = debug
debug = require('debug') -- restore proper 'debug' table

local OUT = os.getenv("OUT") or "out.json"
local PORT = os.getenv("PORT");

json = require('json')

-- called at the end of the capture to print the summary
function taptcp.draw()
  log("Remote Debugging Protocol packets: " .. tcppackets)
  log("dbgServerPort: " .. (dbgServerPort or "Unknown"))

  local data = {}
  data["dbgServerPort"] = dbgServerPort
  data["dbgClientPort"] = dbgClientPort
  data["collectedMessages"] = collectedMessages
  data["ports"] = {
    collectedMessages[1]["src_port"],
    collectedMessages[1]["dst_port"]
  }

  log(json.encode(data))

  local file = io.open(OUT, "w")
  file:write(json.encode(data))
  file:close()
end

data = Field.new("data.data")

-- called once each time the filter of the tap matches
function taptcp.packet(pinfo,tvb)
  if tonumber(PORT) and
     not tonumber(PORT) == pinfo.src_port and
     not tonumber(PORT) == pinfo.dst_port then
     return
  end

  tcppackets = tcppackets + 1
  local d = data()
  if d then
    local cs = tostring(d):split(':')
    local text = ""
    for i,v in ipairs(cs) do
      text = text .. string.char(tonumber(v,16))
    end
    local msgs = getRemoteDebuggerMessages(text)

    if type(msgs) == "nil" or #msgs == 0 then
      return
    end

    local jd = {}
    jd["src_port"] = pinfo.src_port
    jd["dst_port"] = pinfo.dst_port
    jd["messages"] = msgs

    for i,v in ipairs(msgs) do
      if v["applicationType"] == "browser" then
        dbgServerPort = pinfo.src_port
        dbgClientPort = pinfo.dst_port
      end
      if (not dbgServerPort) and (v["to"]) then
        dbgServerPort = pinfo.dst_port
        dbgClientPort = pinfo.src_port
      end
      if (not dbgServerPort) and (v["from"]) then
        dbgServerPort = pinfo.src_port
        dbgClientPort = pinfo.dst_port
      end
    end

    collectedMessages[#collectedMessages+1] = jd
  end
end

local bufferedContent = ""
local bufferedSepPos = -1
local bufferedLength = -1
function getRemoteDebuggerMessages(text)
  local packets = {}
  local sepPos
  local numChars

  if bufferedLength == -1 then
    sepPos = text:find(':')

    if type(sepPos) == "nil" then
      return patckets;
    end

    numChars = tonumber(string.sub(text,0,sepPos-1),10)

    if type(numChars) == "nil" then
      log("UNKNOWN LENGTH", text:len())
      -- log(text)
      return packets
    end
  else
    text = bufferedContent .. text
    sepPos = bufferedSepPos
    numChars = bufferedLength
    bufferedLength = -1
    bufferedSepPos = -1
    bufferedContent = ""
  end

  if text:len() - (sepPos) < numChars then
    log("NOT ENOUGH DATA", text:len(), sepPos, numChars)
    -- log(text)
    bufferedLength = numChars
    bufferedSepPos = sepPos
    bufferedContent = bufferedContent .. text
    return packets
  end

  local pkt = string.sub(text,sepPos+1,sepPos+1+numChars)

  packets[1] = json.decode(pkt)

  local rest = string.sub(text,sepPos+numChars+1,-1)

  if type(rest) == "string" and rest:len() > 0 then
    packets = concat(packets, getRemoteDebuggerMessages(rest))
  end

  return packets
end

function concat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end
