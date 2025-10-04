local JECS = require(script.Parent.Parent.Core.JECS)

local Tags = {
	Scope = JECS.tag(),
	Mapper = JECS.tag(),
	Consumer = JECS.tag(),
	Producer = JECS.tag(),
	Handshake = JECS.tag(),
	
	Effect = JECS.tag(),
	Memoized = JECS.tag(),
	Observer = JECS.tag(),
	
	
	Render = JECS.tag(),
	Update = JECS.tag(),
	React = JECS.tag(),

	--Relationships
	RuntimeOf = JECS.tag(),
	ChildOf = JECS.ChildOf,
	InScopeOf = JECS.tag(),
	ConsumerOf = JECS.tag(),
	DeleteBefore = JECS.tag(),
	Previous = JECS.tag(),
	Next = JECS.tag(),
	Cleanable = JECS.tag(),

	--Hooks
	OnChange = JECS.tag(),
	OnUpdate = JECS.tag(),

	--Actions
	Cascade = JECS.tag(),
	FireImmediately = JECS.tag(),
	
	--Statuses
	Dirty = JECS.tag(),
	Cleaning = JECS.tag(),
	HasConsumers = JECS.tag(),
}

return Tags