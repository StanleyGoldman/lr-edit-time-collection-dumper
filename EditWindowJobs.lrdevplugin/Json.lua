-- The JSON subset the plugin stores: objects, arrays, strings, numbers and
-- booleans (no null). Decoding parses the text, so saved data never runs as code.

local Json = {}

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encodeString(text)
	return '"'
		.. string.gsub(text, '[%c"\\]', function(char)
			return ESCAPES[char] or string.format("\\u%04x", string.byte(char))
		end)
		.. '"'
end

local function arrayLength(value)
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	for index = 1, count do
		if value[index] == nil then
			return nil
		end
	end
	return count
end

local function encodeValue(value, parts)
	local kind = type(value)
	if kind == "string" then
		parts[#parts + 1] = encodeString(value)
	elseif kind == "number" then
		if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
			parts[#parts + 1] = string.format("%d", value)
		else
			parts[#parts + 1] = string.format("%.17g", value)
		end
	elseif kind == "boolean" then
		parts[#parts + 1] = tostring(value)
	elseif kind == "table" then
		local length = arrayLength(value)
		if length then
			parts[#parts + 1] = "["
			for index = 1, length do
				if index > 1 then
					parts[#parts + 1] = ","
				end
				encodeValue(value[index], parts)
			end
			parts[#parts + 1] = "]"
		else
			local keys = {}
			for key in pairs(value) do
				if type(key) ~= "string" then
					error("cannot encode a table mixing array items and keys", 0)
				end
				keys[#keys + 1] = key
			end
			table.sort(keys)
			parts[#parts + 1] = "{"
			for index, key in ipairs(keys) do
				if index > 1 then
					parts[#parts + 1] = ","
				end
				parts[#parts + 1] = encodeString(key) .. ":"
				encodeValue(value[key], parts)
			end
			parts[#parts + 1] = "}"
		end
	else
		error("cannot encode a " .. kind, 0)
	end
end

function Json.encode(value)
	local parts = {}
	encodeValue(value, parts)
	return table.concat(parts)
end

local function utf8Char(code)
	if code < 0x80 then
		return string.char(code)
	elseif code < 0x800 then
		return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
	end
	return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local UNESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

-- Each reader takes the text and a position and returns the value and the
-- position after it, or raises a message caught by Json.decode.
local readValue

local function skipSpace(text, position)
	return string.find(text, "%S", position) or #text + 1
end

local function fail(position, expected)
	error({ message = string.format("expected %s at character %d", expected, position) })
end

local function readString(text, position)
	local parts = {}
	position = position + 1
	while true do
		local char = string.sub(text, position, position)
		if char == "" then
			fail(position, "a closing quote")
		elseif char == '"' then
			return table.concat(parts), position + 1
		elseif char == "\\" then
			local escape = string.sub(text, position + 1, position + 1)
			if escape == "u" then
				local hex = string.match(text, "^%x%x%x%x", position + 2)
				if not hex then
					fail(position, "four hex digits")
				end
				parts[#parts + 1] = utf8Char(tonumber(hex, 16))
				position = position + 6
			elseif UNESCAPES[escape] then
				parts[#parts + 1] = UNESCAPES[escape]
				position = position + 2
			else
				fail(position, "a valid escape")
			end
		else
			parts[#parts + 1] = char
			position = position + 1
		end
	end
end

local function readSequence(text, position, closer, readItem)
	position = skipSpace(text, position + 1)
	if string.sub(text, position, position) == closer then
		return position + 1
	end
	while true do
		position = skipSpace(text, readItem(position))
		local char = string.sub(text, position, position)
		if char == closer then
			return position + 1
		elseif char ~= "," then
			fail(position, "',' or '" .. closer .. "'")
		end
		position = skipSpace(text, position + 1)
	end
end

function readValue(text, position)
	position = skipSpace(text, position)
	local char = string.sub(text, position, position)
	if char == "{" then
		local object = {}
		local after = readSequence(text, position, "}", function(itemPosition)
			if string.sub(text, itemPosition, itemPosition) ~= '"' then
				fail(itemPosition, "a quoted key")
			end
			local key, afterKey = readString(text, itemPosition)
			afterKey = skipSpace(text, afterKey)
			if string.sub(text, afterKey, afterKey) ~= ":" then
				fail(afterKey, "':'")
			end
			local value, afterValue = readValue(text, afterKey + 1)
			object[key] = value
			return afterValue
		end)
		return object, after
	elseif char == "[" then
		local array = {}
		local after = readSequence(text, position, "]", function(itemPosition)
			local value, afterValue = readValue(text, itemPosition)
			array[#array + 1] = value
			return afterValue
		end)
		return array, after
	elseif char == '"' then
		return readString(text, position)
	elseif string.sub(text, position, position + 3) == "true" then
		return true, position + 4
	elseif string.sub(text, position, position + 4) == "false" then
		return false, position + 5
	end
	local number = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", position)
	if number and tonumber(number) then
		return tonumber(number), position + #number
	end
	fail(position, "a value")
end

-- Returns the decoded value, or nil and a message.
function Json.decode(text)
	local ok, value, position = pcall(readValue, text, 1)
	if not ok then
		if type(value) == "table" then
			return nil, value.message
		end
		error(value, 0)
	end
	position = skipSpace(text, position)
	if position <= #text then
		return nil, string.format("unexpected text at character %d", position)
	end
	return value
end

return Json
