local JECS = require(script.Parent.Parent.Core.JECS)

local Components = {
	Producers = JECS.component(),
	Consumers = JECS.component(),
	
	Name = JECS.Name,
	Count = JECS.component(),
	State = JECS.component(),
	Cache = JECS.component(),
	Callback = JECS.component() :: JECS.Entity<(...any) -> ()>,
	Cleanup = JECS.component() :: JECS.Entity<() -> ()>,
}


return Components
