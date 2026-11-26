# Wuye

Lightweight reactive state programming on top of `JECS` ECS.

This version focuses on:

- plain-table handles (no metatable-based wrapper objects)
- deterministic system execution order
- lower allocation pressure in hot paths
- an easier API for game-side reactive workflows

## Quick start

```lua
local Wuye = require(path.To.Wuye)

local app = Wuye.Scope({
	name = "AppScope",
})

local health = app:State(100)
local armor = app:State(50)

local total = app:Computed(function(use)
	return use(health) + use(armor)
end)

app:Watch(total, function(newTotal, oldTotal)
	print("Total changed:", oldTotal, "->", newTotal)
end)

Wuye.set(health, 90)
```

## API

### Core

- `Wuye.Scope(sourceTable?, cheap?) -> scope`
- `scope:State(initial) -> state`
- `scope:Computed(function(use) ... end) -> computedState`
- `scope:Watch(state, function(new, old) end) -> watchHandle`
- `scope:Effect(function(use) ... end) -> effectHandle`
- `scope:Render(function(use) ... end) -> effectHandle`
- `scope:Map(tableState, transform, cleanupFn?) -> mappedState`
- `scope:Select(state, key) -> computedState`

### Utility

- `Wuye.set(state, value)`
- `Wuye.add(scope, ...subjects)`
- `Wuye.remove(scope, ...subjects)`
- `Wuye.clean(scope)`
- `Wuye.delete(handle)`
- `Wuye.Cleanup(subject)`
- `Wuye.Throttle.new(seconds)`
- `Wuye.Debounce.new()`

### Benchmark

- `Wuye.Benchmark.StateSet(Wuye, scope, iterations?)`
- `Wuye.Benchmark.WatchFanout(Wuye, scope, producerCount?, iterations?)`
- `Wuye.Benchmark.MapTable(Wuye, scope, keyCount?, iterations?)`
- `Wuye.Benchmark.RunAll(Wuye, scope, config?)`

## Migration map

- `scoped` -> `Scope`
- `Changed` -> `Watch`
- `Mapped` -> `Map`
- `Destroy` -> `Cleanup`

Legacy aliases are still exposed for easier migration.

## Performance notes

- Keep long-lived systems/effects in a stable scope; avoid rebuilding scopes every frame.
- Prefer `scope:Watch`/`scope:Computed` over ad-hoc polling loops.
- Use `scope:Map` for keyed table transforms when you want incremental reuse.
- Use `Wuye.Benchmark` in Studio to compare local changes before shipping.
