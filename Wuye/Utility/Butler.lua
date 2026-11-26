--!optimize 2

--Sovereignty

local Butler = {}

local taskCancel = task.cancel

local cleanSingle: (task: any) -> ()

local function isInstanceDestroyed(obj: Instance): boolean
	if obj.Parent == nil then
		local _, err = pcall(function()
			obj.Parent = UserSettings() :: any
		end)
		return err ~= "Not allowed to add that under settings"
	end
	return false
end

local typeHandlers = table.freeze({
	Instance = function(t: Instance)
		if not isInstanceDestroyed(t) then
			t:Destroy()
		end
	end,

	RBXScriptConnection = function(t: RBXScriptConnection)
		t:Disconnect()
	end,

	thread = function(t: thread)
		pcall(taskCancel, t)
	end,

	["function"] = function(t: (...any) -> ...any)
		t()
	end,

	table = function(t: { [any]: any })
		local method = t.disconnect or t.Disconnect
			or t.destroy or t.Destroy

		if method then
			method(t)
			return
		end

		if getmetatable(t :: any) then
			setmetatable(t, nil)
			table.clear(t :: any)
		else
			for _, v in t do
				cleanSingle(v)
			end
		end
	end,
})

function cleanSingle(t: any)
	local handler = (typeHandlers :: any)[typeof(t)]
	if handler then
		handler(t)
	end
end

local function add(self: any, addTask: any): any
	if addTask == nil then return nil end

	local data = self._
	if data.destroyed then
		warn("[Butler] Attempting to add to a destroyed Butler.")
		return nil
	end

	local n = data.n + 1
	data.n = n
	data[n] = addTask
	return addTask
end

local function fastClean(self: any)
	local data = self._

	for i = data.n, 1, -1 do
		local t = data[i]
		data[i] = nil
		cleanSingle(t)
	end

	data.n = 0
end

local function clean(self: any)
	local data = self._

	for i = 1, data.n do
		local t = data[i]
		data[i] = nil
		cleanSingle(t)
	end

	data.n = 0
end

local function destroy(self: any)
	local data = self._
	if data.destroyed then return end
	fastClean(self)
	data.destroyed = true
end

local function isDestroyed(self: any): boolean
	return self._.destroyed
end

export type Type = {
	Add: <T>(Type, task: T) -> T?,
	Clean: (Type) -> (),
	Destroy: (Type) -> (),
	IsDestroyed: (Type) -> boolean,
}

function Butler.new(size: number?): Type
	local data: any = if size then table.create(size) else {}
	data.n = 0
	data.destroyed = false

	return table.freeze({
		_ = data,
		Add = add,
		Clean = clean,
		FastClean = fastClean,
		Destroy = destroy,
		IsDestroyed = isDestroyed,
	}) :: any
end

return Butler
