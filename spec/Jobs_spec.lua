local Jobs = require "Jobs"

local function job(overrides)
	local result = {
		id = "job-1",
		name = "This week",
		sources = { { id = 11, path = "Family › 2026 › October" }, { id = 12, path = "Archive" } },
		target = { id = 20, path = "Edited › This week" },
		window = { kind = "relative", amount = 7, unit = "days" },
	}
	for key, value in pairs(overrides or {}) do
		result[key] = value
	end
	return result
end

describe("Jobs.validate", function()
	it("accepts a complete Job", function()
		assert.is_true(Jobs.validate(job(), {}))
	end)

	local function rejects(description, candidate, others, expected)
		it("rejects " .. description, function()
			local ok, message = Jobs.validate(candidate, others or {})
			assert.is_nil(ok)
			assert.matches(expected, message, 1, true)
		end)
	end

	rejects("a blank name", job({ name = "  " }), nil, "needs a name")
	rejects("no Source Collections", job({ sources = {} }), nil, "at least one Source Collection")
	local noTarget = job()
	noTarget.target = nil
	rejects("no Target Collection", noTarget, nil, "needs a Target Collection")
	rejects(
		"a target that is also a source",
		job({ target = { id = 12, path = "Archive" } }),
		nil,
		'"Archive" cannot be both a Source and the Target'
	)
	rejects(
		"a target another Job already owns",
		job(),
		{ job({ id = "job-2", name = "Last month" }) },
		'"Edited › This week" is already the Target Collection of "Last month"'
	)
	rejects("a bad window", job({ window = { kind = "relative", amount = 0, unit = "days" } }), nil, "whole number")

	it("ignores the Job itself among the others when checking targets", function()
		assert.is_true(Jobs.validate(job(), { job() }))
	end)

	it("rejects a duplicate name", function()
		local ok, message = Jobs.validate(job(), { job({ id = "job-2", target = { id = 30, path = "Other" } }) })
		assert.is_nil(ok)
		assert.matches('A Job called "This week" already exists', message, 1, true)
	end)
end)

describe("Jobs.encode and Jobs.decode", function()
	it("round-trips a list of Jobs", function()
		local jobs = {
			job(),
			job({
				id = "job-2",
				name = 'Quotes "and" \\ backslashes\nand a newline',
				target = { id = 21, path = "Other" },
				window = { kind = "fixed", startDate = "2026-10-01", endDate = "2026-10-15" },
			}),
		}
		assert.are.same(jobs, assert(Jobs.decode(Jobs.encode(jobs))))
	end)

	it("encodes the same Jobs to the same text", function()
		assert.are.equal(Jobs.encode({ job() }), Jobs.encode({ job() }))
	end)

	it("writes JSON", function()
		assert.are.equal(
			'{"jobs":[{"id":"job-1","name":"A","sources":[{"id":11,"path":"S"}],"target":{"id":20,"path":"T"},'
				.. '"window":{"amount":7,"kind":"relative","unit":"days"}}],"version":1}',
			Jobs.encode({
				job({ name = "A", sources = { { id = 11, path = "S" } }, target = { id = 20, path = "T" } }),
			})
		)
	end)

	it("keeps non-ASCII text such as the path separator intact", function()
		local decoded = assert(Jobs.decode(Jobs.encode({ job() })))
		assert.are.equal("Family › 2026 › October", decoded[1].sources[1].path)
	end)

	it("decodes nothing stored yet as no Jobs", function()
		assert.are.same({}, Jobs.decode(nil))
	end)

	for description, text in pairs({
		["text that is not JSON"] = "return os.exit()",
		["a different version"] = '{"jobs":[],"version":99}',
		["truncated text"] = '{"jobs":[{"id":"job-1"',
		["trailing text"] = '{"jobs":[],"version":1} x',
	}) do
		it("rejects " .. description, function()
			local jobs, message = Jobs.decode(text)
			assert.is_nil(jobs)
			assert.matches("saved Jobs", message, 1, true)
		end)
	end
end)

describe("Jobs.newId", function()
	it("picks the next unused number", function()
		assert.are.equal("job-1", Jobs.newId({}))
		assert.are.equal("job-8", Jobs.newId({ job({ id = "job-7" }), job({ id = "job-2" }) }))
	end)
end)
