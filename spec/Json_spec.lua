local Json = require "Json"

describe("Json.encode", function()
	it("writes objects with sorted keys and arrays in order", function()
		assert.are.equal(
			'{"a":[1,2.5,"x"],"b":true,"c":false}',
			Json.encode({ c = false, a = { 1, 2.5, "x" }, b = true })
		)
	end)

	it("writes an empty table as an empty array", function()
		assert.are.equal("[]", Json.encode({}))
	end)

	it("escapes quotes, backslashes and control characters", function()
		assert.are.equal([["a\"b\\c\nd\u0001"]], Json.encode 'a"b\\c\nd\1')
	end)

	it("refuses values JSON cannot hold", function()
		assert.has_error(function()
			Json.encode({ f = function() end })
		end)
		assert.has_error(function()
			Json.encode({ [1] = "a", x = "b" })
		end)
	end)
end)

describe("Json.decode", function()
	it("reads what encode writes", function()
		local value = { list = { 1, -2, 3.25e2 }, name = "Family › 2026", flag = true, nested = { deep = { "x" } } }
		assert.are.same(value, Json.decode(Json.encode(value)))
	end)

	it("reads whitespace and \\u escapes", function()
		assert.are.same({ a = "é\t" }, Json.decode ' { "a" : "\\u00e9\\t" } ')
	end)

	for _, text in ipairs({ "", "{", '{"a":}', "[1,]", '"open', "nul", "{} {}", "{'a':1}" }) do
		it("rejects " .. string.format("%q", text), function()
			local value, message = Json.decode(text)
			assert.is_nil(value)
			assert.is_string(message)
		end)
	end
end)
