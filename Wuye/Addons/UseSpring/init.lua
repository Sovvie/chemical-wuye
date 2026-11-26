local RootFolder = script.Parent.Parent
local Core = RootFolder.Core

local JECS = require(Core.JECS)
local Wuye = require(RootFolder)
local Spr = require(script.Spr2)

type State<T> = {
	entity: JECS.Entity<T>,
	get: (self: State<T>) -> T,
}

type Scopable<S> = S & { entity: JECS.Entity<nil> }

type UseSpring<C> = C & {
	Spr: <T>(scope: Scopable<C>, target: State<T>, freq: number, damp: number) -> (
		{ entity: JECS.Entity<T>, get: () -> T, stop: () -> (), completed: (callback: () -> ()) -> () }
	)
}

local function main(library: Wuye.Wuye & UseSpring<Wuye.Wuye>): UseSpring<Wuye.Wuye>
	local newSpr = function<T>(
		scope: Wuye.Scopable<Wuye.Wuye>,
		target: Wuye.State<T>,
		freq: number,
		damp: number
	): { entity: JECS.Entity<T>, get: () -> T, stop: () -> (), completed: (callback: () -> ()) -> () }
		local initial = target:get()

		local springValue = scope:State(initial)

		local spring = Spr.value(initial, function(newValue)
			library.set(springValue, newValue)
		end)

		scope:Watch(target, function(new)
			spring:target(damp, freq, new)
		end)

		springValue.completed = function(callback: () -> ())
			spring:completed(callback)
		end

		springValue.stop = function()
			spring:stop()
		end

		return springValue
	end

	library.Spr = newSpr

	return library
end

return main