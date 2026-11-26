--!optimize 2

local Benchmark = {}

local function safeRate(iterations: number, seconds: number): number
	if seconds <= 0 then
		return 0
	end
	return iterations / seconds
end

function Benchmark.StateSet(library, scope, iterations: number?)
	local count = iterations or 100000
	local state = scope:State(0)

	local start = os.clock()
	for i = 1, count do
		library.set(state, i)
	end
	local elapsed = os.clock() - start

	state:destroy()

	return {
		name = "StateSet",
		iterations = count,
		seconds = elapsed,
		opsPerSecond = safeRate(count, elapsed),
	}
end

function Benchmark.WatchFanout(library, scope, producerCount: number?, iterations: number?)
	local producersN = producerCount or 64
	local loops = iterations or 5000

	local producers = table.create(producersN)
	local watchers = table.create(producersN)
	local observedChanges = 0

	for i = 1, producersN do
		producers[i] = scope:State(i)
	end

	for i = 1, producersN do
		watchers[i] = scope:Watch(producers[i], function()
			observedChanges += 1
		end)
	end

	local writes = producersN * loops
	local start = os.clock()
	for step = 1, loops do
		for i = 1, producersN do
			library.set(producers[i], step + i)
		end
	end
	local elapsed = os.clock() - start

	for i = 1, producersN do
		watchers[i]:destroy()
		producers[i]:destroy()
	end

	return {
		name = "WatchFanout",
		producers = producersN,
		iterations = loops,
		totalWrites = writes,
		seconds = elapsed,
		writesPerSecond = safeRate(writes, elapsed),
		observedChanges = observedChanges,
	}
end

function Benchmark.MapTable(library, scope, keyCount: number?, iterations: number?)
	local keys = keyCount or 64
	local loops = iterations or 1000

	local source = scope:State({})
	local mapped = scope:Map(source, function(_key, value)
		return value * 2
	end)

	local writes = 0
	local start = os.clock()
	for step = 1, loops do
		local payload = table.create(keys)
		for key = 1, keys do
			payload[key] = step + key
		end
		library.set(source, payload)
		writes += 1
	end
	local elapsed = os.clock() - start

	mapped:destroy()
	source:destroy()

	return {
		name = "MapTable",
		keys = keys,
		iterations = loops,
		seconds = elapsed,
		writesPerSecond = safeRate(writes, elapsed),
	}
end

function Benchmark.RunAll(library, scope, config)
	config = config or {}

	return {
		stateSet = Benchmark.StateSet(library, scope, config.stateSetIterations),
		watchFanout = Benchmark.WatchFanout(library, scope, config.watchProducers, config.watchIterations),
		mapTable = Benchmark.MapTable(library, scope, config.mapKeys, config.mapIterations),
	}
end

return Benchmark
