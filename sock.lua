--[[
sock.lua: A WebSocket library for LÖVE

Copyright (c) 2020 Björn Ritzl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local sock = {
	_VERSION = "1.0.0",
	_URL = "https://github.com/britzl/sock.lua",
	_DESCRIPTION = "A WebSocket library for LÖVE"
}

local socket = require "socket"
local http = require "socket.http"
local url = require "socket.url"
local ltn12 = require "ltn12"

local TYPE_CONTINUE = 0x0
local TYPE_TEXT = 0x1
local TYPE_BINARY = 0x2
local TYPE_CLOSE = 0x8
local TYPE_PING = 0x9
local TYPE_PONG = 0xA

local CLOSE_NORMAL = 1000
local CLOSE_GOING_AWAY = 1001
local CLOSE_PROTOCOL_ERROR = 1002
local CLOSE_UNSUPPORTED_DATA = 1003
local CLOSE_INVALID_PAYLOAD = 1007
local CLOSE_POLICY_VIOLATION = 1008
local CLOSE_MESSAGE_TOO_BIG = 1009
local CLOSE_INTERNAL_ERROR = 1011

local function generate_key()
	local key = ""
	for i=1,16 do
		key = key .. string.char(math.random(0, 255))
	end
	return socket.skip(2, socket.base64.encode(key))
end

local function send_handshake_request(self)
	local key = generate_key()
	local handshake = {
		"GET " .. (self.path or "/") .. " HTTP/1.1",
		"Host: " .. self.host .. (self.port and (":" .. self.port) or ""),
		"Upgrade: websocket",
		"Connection: Upgrade",
		"Sec-WebSocket-Key: " .. key,
		"Sec-WebSocket-Version: 13",
		"\r\n"
	}
	local handshake_str = table.concat(handshake, "\r\n")
	self.socket:send(handshake_str)
	return key
end

local function receive_handshake_response(self, key)
	local expected_accept = socket.skip(2, socket.base64.encode(socket.md5.digest(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")))
	local response = {}
	local line, err = self.socket:receive("*l")
	while line and line ~= "" do
		table.insert(response, line)
		line, err = self.socket:receive("*l")
	end
	if err then
		return false, "Error receiving handshake response: " .. err
	end
	
	local status_line = table.remove(response, 1)
	local protocol, status_code = string.match(status_line, "HTTP/1.1 (%d+)")
	if status_code ~= "101" then
		return false, "WebSocket upgrade failed: " .. status_code .. " " .. table.concat(response, " ")
	end
	
	local headers = {}
	for i,h in ipairs(response) do
		local name, value = string.match(h, "([^:]+):%s*(.+)")
		if name and value then
			headers[name:lower()] = value
		end
	end
	
	if headers["upgrade"]:lower() ~= "websocket" then
		return false, "Invalid 'upgrade' header: " .. headers["upgrade"]
	end
	if headers["connection"]:lower() ~= "upgrade" then
		return false, "Invalid 'connection' header: " .. headers["connection"]
	end
	if headers["sec-websocket-accept"] ~= expected_accept then
		return false, "Invalid 'sec-websocket-accept' header"
	end
	
	return true
end

local function create_frame(self, data, opcode)
	opcode = opcode or TYPE_TEXT
	
	local header = {}
	local payload_len = #data
	
	-- First byte: FIN + opcode
	header[1] = 0x80 + opcode
	
	-- Second byte: MASK + payload length
	if payload_len <= 125 then
		header[2] = payload_len
	elseif payload_len <= 65535 then
		header[2] = 126
		header[3] = math.floor(payload_len / 256)
		header[4] = payload_len % 256
	else
		header[2] = 127
		local len = payload_len
		for i=9,2,-1 do
			header[i] = len % 256
			len = math.floor(len / 256)
		end
	end
	
	local frame = {}
	for i,b in ipairs(header) do
		frame[i] = string.char(b)
	end
	for i=1,#data do
		frame[#header + i] = data:sub(i,i)
	end
	
	return table.concat(frame)
end

local function parse_frame(self)
	local frame, err = self.socket:receive(2)
	if not frame then
		return nil, err
	end
	
	-- Parse first byte
	local byte1 = string.byte(frame:sub(1,1))
	local fin = bit.band(byte1, 0x80) == 0x80
	local opcode = bit.band(byte1, 0x0F)
	
	-- Parse second byte
	local byte2 = string.byte(frame:sub(2,2))
	local mask = bit.band(byte2, 0x80) == 0x80
	local payload_len = bit.band(byte2, 0x7F)
	
	-- Extended payload length
	if payload_len == 126 then
		local bytes, err = self.socket:receive(2)
		if not bytes then return nil, err end
		payload_len = bit.lshift(string.byte(bytes, 1), 8) + string.byte(bytes, 2)
	elseif payload_len == 127 then
		local bytes, err = self.socket:receive(8)
		if not bytes then return nil, err end
		payload_len = 0
		for i=1,8 do
			payload_len = bit.lshift(payload_len, 8) + string.byte(bytes, i)
		end
	end
	
	-- Read mask
	local masking_key = ""
	if mask then
		masking_key, err = self.socket:receive(4)
		if not masking_key then return nil, err end
	end
	
	-- Read payload
	local payload = ""
	if payload_len > 0 then
		payload, err = self.socket:receive(payload_len)
		if not payload then return nil, err end
		
		-- Unmask data if needed
		if mask then
			local unmasked = {}
			for i=1,payload_len do
				local j = (i-1) % 4 + 1
				unmasked[i] = string.char(bit.bxor(string.byte(payload, i), string.byte(masking_key, j)))
			end
			payload = table.concat(unmasked)
		end
	end
	
	return {
		fin = fin,
		opcode = opcode,
		mask = mask,
		payload_len = payload_len,
		payload = payload
	}
end

local function handle_control_frame(self, frame)
	if frame.opcode == TYPE_PING then
		self:send_frame(frame.payload, TYPE_PONG)
		return true
	elseif frame.opcode == TYPE_CLOSE then
		local code, reason
		if #frame.payload >= 2 then
			code = bit.lshift(string.byte(frame.payload, 1), 8) + string.byte(frame.payload, 2)
			reason = frame.payload:sub(3)
		end
		self:close(code, reason)
		return true
	end
	return false
end

function sock.connect(host, port, path, timeout)
	local self = {
		host = host,
		port = port,
		path = path or "/",
		connected = false,
		socket = socket.tcp(),
		timeout = timeout or 5,
		buffer = ""
	}
	
	function self:send(data)
		if not self.connected then return false, "Not connected" end
		return self:send_frame(data, TYPE_TEXT)
	end
	
	function self:send_frame(data, opcode)
		if not self.connected then return false, "Not connected" end
		local frame = create_frame(self, data, opcode)
		return self.socket:send(frame)
	end
	
	function self:receive()
		if not self.connected then return false, "Not connected" end
		
		local frames = {}
		while true do
			local frame, err = parse_frame(self)
			if not frame then
				return nil, err
			end
			
			-- Handle control frames
			if handle_control_frame(self, frame) then
				if #frames == 0 then
					-- No data frames received yet, continue receiving
					goto continue
				else
					-- Return any data frames we've received so far
					break
				end
			end
			
			-- Data frames
			if frame.opcode == TYPE_TEXT or frame.opcode == TYPE_BINARY or frame.opcode == TYPE_CONTINUE then
				table.insert(frames, frame)
				
				-- If this is the final frame or we have some complete text, we're done
				if frame.fin or frame.opcode == TYPE_TEXT or frame.opcode == TYPE_BINARY then
					break
				end
			end
			
			::continue::
		end
		
		-- Combine frames into a single payload
		local payload = ""
		for _,frame in ipairs(frames) do
			payload = payload .. frame.payload
		end
		
		return payload
	end
	
	function self:close(code, reason)
		if not self.connected then return false, "Not connected" end
		
		code = code or CLOSE_NORMAL
		reason = reason or ""
		
		local payload = string.char(bit.rshift(code, 8), bit.band(code, 0xFF)) .. reason
		self:send_frame(payload, TYPE_CLOSE)
		
		self.connected = false
		self.socket:close()
		return true
	end
	
	-- Connect and perform handshake
	self.socket:settimeout(self.timeout)
	local success, err = self.socket:connect(host, port)
	if not success then
		return nil, "Failed to connect: " .. tostring(err)
	end
	
	local key = send_handshake_request(self)
	local handshake_success, handshake_err = receive_handshake_response(self, key)
	if not handshake_success then
		self.socket:close()
		return nil, handshake_err
	end
	
	self.connected = true
	return self
end

return sock