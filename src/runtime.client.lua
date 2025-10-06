local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chemical = require(ReplicatedStorage.Packages.Chemical)




local source = Chemical:Scoped()

local state = source:State(1)

local changed = source.changed(state, function(new, old)
    print(new, old)
end)

source:Effect(function(use)
    return use(state)
end)

source:Cleanup()

source.Cleanup(changed)

