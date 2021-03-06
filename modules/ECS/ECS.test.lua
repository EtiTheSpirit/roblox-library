local T = {}

local function pass(t, name, func)
	local ok, err = pcall(func)
	if not ok then
		t:Errorf("%s: unexpected error: %s", name, tostring(err))
	end
end

local function fail(t, name, func)
	if pcall(func) then
		t:Errorf("%s: expected error", name)
	end
end

local function empty()end

function T.TestWorld_DefineSystem(t, require)
	local world = require().NewWorld()
	fail(t, "missing name",           function() world:DefineSystem() end)
	fail(t, "name not a string",      function() world:DefineSystem(42) end)
	fail(t, "empty name",             function() world:DefineSystem("") end)
	fail(t, "name not ident",         function() world:DefineSystem("foo bar") end)
	fail(t, "missing components",     function() world:DefineSystem("System") end)
	fail(t, "components not a table", function() world:DefineSystem("System", 42) end)
	fail(t, "missing update",         function() world:DefineSystem("System", {}) end)
	fail(t, "update not a function",  function() world:DefineSystem("System", {}, 42) end)
	pass(t, "minimal definition",     function() world:DefineSystem("System", {}, empty) end)
	fail(t, "already defined",        function() world:DefineSystem("System", {}, empty) end)
	fail(t, "component not ident",    function() world:DefineSystem("SystemA", {"foo bar"}, empty) end)
	pass(t, "undefined component",    function() world:DefineSystem("SystemA", {"Component"}, empty) end)
	world:DefineComponent("Component", true) -- Allow Init to succeed.
	world:Init()
	fail(t, "define after init",      function() world:DefineSystem("SystemB", {}, empty) end)
end

function T.TestWorld_DefineComponent(t, require)
	local world = require().NewWorld()
	fail(t, "missing name",       function() world:DefineComponent() end)
	fail(t, "name not a string",  function() world:DefineComponent(42) end)
	fail(t, "empty name",         function() world:DefineComponent("") end)
	fail(t, "name not ident",     function() world:DefineComponent("foo bar") end)
	fail(t, "missing definition", function() world:DefineComponent("Component") end)
	fail(t, "definition is nil",  function() world:DefineComponent("Component", nil) end)
	pass(t, "minimal definition", function() world:DefineComponent("Component", 42) end)
	fail(t, "already defined",    function() world:DefineComponent("Component", 42) end)
	world:Init()
	fail(t, "define after init",  function() world:DefineComponent("ComponentA", 42) end)
end

function T.TestWorld_DefineEntity(t, require)
	local world = require().NewWorld()
	fail(t, "missing name",             function() world:DefineEntity() end)
	fail(t, "name not a string",        function() world:DefineEntity(42) end)
	fail(t, "empty name",               function() world:DefineEntity("") end)
	fail(t, "name not ident",           function() world:DefineEntity("foo bar") end)
	fail(t, "missing definition",       function() world:DefineEntity("Entity") end)
	fail(t, "definition is number",     function() world:DefineEntity("Entity", 42) end)
	fail(t, "invalid definition table", function() world:DefineEntity("Entity", {42}) end)
	fail(t, "invalid returned type",    function() world:DefineEntity("Entity", empty) end)
	fail(t, "invalid returned table",   function() world:DefineEntity("Entity", function() return {42} end) end)
	pass(t, "definition is table",      function() world:DefineEntity("Entity", {}) end)
	fail(t, "already defined",          function() world:DefineEntity("Entity", {}) end)
	pass(t, "definition is function",   function() world:DefineEntity("EntityA", function() return {} end) end)
	pass(t, "undefined component",      function() world:DefineEntity("EntityB", {Component=true}) end)
	world:DefineComponent("Component", true) -- Allow Init to succeed.
	world:Init()
	fail(t, "define after init",        function() world:DefineEntity("EntityC", {}) end)
end

function T.TestWorld_Init(t, require)
	local world = require().NewWorld()
	world:DefineComponent("ComponentA", true)
	world:DefineSystem("SystemA", {"ComponentB"}, empty)
	world:DefineEntity("EntityA", {ComponentC = true})
	fail(t, "undefined system component", function() world:Init() end)
	world:DefineComponent("ComponentB", true)
	fail(t, "undefined entity component", function() world:Init() end)
	world:DefineComponent("ComponentC", true)
	pass(t, "initialize", function() world:Init() end)
end

function T.TestWorld_CreateEntity(t, require)
	local world = require().NewWorld()
	fail(t, "create before init", function() world:CreateEntity("Entity", {}) end)
	world:Init()
	fail(t, "no definition", function() world:CreateEntity("Entity", {}) end)

	local world = require().NewWorld()
	world:DefineEntity("Entity", {})
	world:Init()
	pass(t, "create entity", function() world:CreateEntity("Entity", {}) end)
end

function T.TestWorld_Update(t, require)
	local world = require().NewWorld()
	fail(t, "update before init", function() world:Update("System") end)
	world:Init()
	fail(t, "no definition", function() world:Update("System") end)

	local world = require().NewWorld()
	local set = false
	world:DefineSystem("System", {}, function(...) set = ... end)
	world:Init()
	pass(t, "update", function() world:Update("System", true) end)
	if not set then
		t.Errorf("update function not called")
	end
end

function T.TestWorld_DestroyEntity(t, require)
	local world = require().NewWorld()
	world:DefineEntity("Entity", {})
	fail(t, "destroy before init", function() world:DestroyEntity(0) end)
	world:Init()
	fail(t, "unexpected type", function() world:DestroyEntity({}) end)
	fail(t, "unknown entity", function() world:DestroyEntity(0) end)
	local entity = world:CreateEntity("Entity")
	pass(t, "mark entity", function() world:DestroyEntity(entity) end)
	pass(t, "remark entity", function() world:DestroyEntity(entity) end)
end

function T.TestWorld_Upkeep(t, require)
	local world = require().NewWorld()
	world:DefineEntity("Entity", {})
	fail(t, "upkeep before init", function() world:Upkeep() end)
	world:Init()
	pass(t, "empty", function() world:Upkeep() end)
	local entity = world:CreateEntity("Entity")
	world:DestroyEntity(entity)
	pass(t, "destroy", function() world:Upkeep() end)
	fail(t, "unknown entity", function() world:DestroyEntity(entity) end)
	pass(t, "empty again", function() world:Upkeep() end)
end

local hts = {nil, false, 1, {}, "Component", "Undefined"}

local function runHandleTests(v, f, ...)
	assert(v == f(...))
	for i = 1, 6 do
		assert(v == f(hts[i], ...))
		for j = 1, 6 do
			assert(v == f(hts[i], hts[j], ...))
		end
	end
end

function T.TestWorld_Has(t, require)
	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	local function has(...) return world:Has(...) end

	runHandleTests(false, has)
	world:Init()
	runHandleTests(false, has)
	local entity = world:CreateEntity("Entity")
	runHandleTests(false, has)
	assert(false == world:Has(hts[1], entity))
	assert(false == world:Has(hts[2], entity))
	assert(false == world:Has(hts[3], entity))
	assert(false == world:Has(hts[4], entity))
	assert(false == world:Has(hts[5], entity))
	assert(false == world:Has(hts[6], entity))
	assert(true  == world:Has(entity))
	assert(true  == world:Has(entity, hts[1]))
	assert(false == world:Has(entity, hts[2]))
	assert(false == world:Has(entity, hts[3]))
	assert(false == world:Has(entity, hts[4]))
	assert(true  == world:Has(entity, hts[5]))
	assert(false == world:Has(entity, hts[6]))
	assert(false == world:Has(entity, entity))
	world:DestroyEntity(entity)
	world:Upkeep()
	runHandleTests(false, has)
	assert(false == world:Has(hts[1], entity))
	assert(false == world:Has(hts[2], entity))
	assert(false == world:Has(hts[3], entity))
	assert(false == world:Has(hts[4], entity))
	assert(false == world:Has(hts[5], entity))
	assert(false == world:Has(hts[6], entity))
	assert(false == world:Has(entity))
	assert(false == world:Has(entity, hts[1]))
	assert(false == world:Has(entity, hts[2]))
	assert(false == world:Has(entity, hts[3]))
	assert(false == world:Has(entity, hts[4]))
	assert(false == world:Has(entity, hts[5]))
	assert(false == world:Has(entity, hts[6]))
	assert(false == world:Has(entity, entity))
end

function T.TestWorld_Get(t, require)
	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	local function get(...) return world:Get(...) end

	runHandleTests(nil, get)
	world:Init()
	runHandleTests(nil, get)
	local entity = world:CreateEntity("Entity")
	runHandleTests(nil, get)
	assert(nil == world:Get(hts[1], entity))
	assert(nil == world:Get(hts[2], entity))
	assert(nil == world:Get(hts[3], entity))
	assert(nil == world:Get(hts[4], entity))
	assert(nil == world:Get(hts[5], entity))
	assert(nil == world:Get(hts[6], entity))
	assert(nil == world:Get(entity))
	assert(nil == world:Get(entity, hts[1]))
	assert(nil == world:Get(entity, hts[2]))
	assert(nil == world:Get(entity, hts[3]))
	assert(nil == world:Get(entity, hts[4]))
	assert(42  == world:Get(entity, hts[5]))
	assert(nil == world:Get(entity, hts[6]))
	assert(nil == world:Get(entity, entity))
	world:DestroyEntity(entity)
	world:Upkeep()
	runHandleTests(nil, get)
	assert(nil == world:Get(hts[1], entity))
	assert(nil == world:Get(hts[2], entity))
	assert(nil == world:Get(hts[3], entity))
	assert(nil == world:Get(hts[4], entity))
	assert(nil == world:Get(hts[5], entity))
	assert(nil == world:Get(hts[6], entity))
	assert(nil == world:Get(entity))
	assert(nil == world:Get(entity, hts[1]))
	assert(nil == world:Get(entity, hts[2]))
	assert(nil == world:Get(entity, hts[3]))
	assert(nil == world:Get(entity, hts[4]))
	assert(nil == world:Get(entity, hts[5]))
	assert(nil == world:Get(entity, hts[6]))
	assert(nil == world:Get(entity, entity))
end

function T.TestWorld_Set(t, require)
	local world = require().NewWorld()

	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	local function set(...) return world:Set(...) end

	runHandleTests(false, set)
	runHandleTests(false, set, 84)
	world:Init()
	runHandleTests(false, set)
	runHandleTests(false, set, 84)
	local entity = world:CreateEntity("Entity")
	runHandleTests(false, set)
	assert(false == world:Set(hts[1], entity))
	assert(false == world:Set(hts[2], entity))
	assert(false == world:Set(hts[3], entity))
	assert(false == world:Set(hts[4], entity))
	assert(false == world:Set(hts[5], entity))
	assert(false == world:Set(hts[6], entity))
	assert(false == world:Set(entity))
	assert(false == world:Set(entity, hts[1]))
	assert(false == world:Set(entity, hts[2]))
	assert(false == world:Set(entity, hts[3]))
	assert(false == world:Set(entity, hts[4]))
	assert(42    == world:Get(entity, hts[5]))
	assert(true  == world:Set(entity, hts[5])) -- Maybe should be false.
	assert(nil   == world:Get(entity, hts[5]))
	assert(false == world:Set(entity, hts[6]))
	assert(false == world:Set(entity, entity))
	runHandleTests(false, set, 84)
	assert(false == world:Set(hts[1], entity, 84))
	assert(false == world:Set(hts[2], entity, 84))
	assert(false == world:Set(hts[3], entity, 84))
	assert(false == world:Set(hts[4], entity, 84))
	assert(false == world:Set(hts[5], entity, 84))
	assert(false == world:Set(hts[6], entity, 84))
	assert(false == world:Set(entity, 84))
	assert(false == world:Set(entity, hts[1], 84))
	assert(false == world:Set(entity, hts[2], 84))
	assert(false == world:Set(entity, hts[3], 84))
	assert(false == world:Set(entity, hts[4], 84))
	assert(nil   == world:Get(entity, hts[5]))
	assert(true  == world:Set(entity, hts[5], 84))
	assert(84    == world:Get(entity, hts[5]))
	assert(false == world:Set(entity, hts[6], 84))
	assert(false == world:Set(entity, entity, 84))
	world:DestroyEntity(entity)
	world:Upkeep()
	runHandleTests(hts[2], set)
	assert(false == world:Set(hts[1], entity))
	assert(false == world:Set(hts[2], entity))
	assert(false == world:Set(hts[3], entity))
	assert(false == world:Set(hts[4], entity))
	assert(false == world:Set(hts[5], entity))
	assert(false == world:Set(hts[6], entity))
	assert(false == world:Set(entity))
	assert(false == world:Set(entity, hts[1]))
	assert(false == world:Set(entity, hts[2]))
	assert(false == world:Set(entity, hts[3]))
	assert(false == world:Set(entity, hts[4]))
	assert(false == world:Set(entity, hts[5]))
	assert(false == world:Set(entity, hts[6]))
	assert(false == world:Set(entity, entity))
	runHandleTests(hts[2], set, 84)
	assert(false == world:Set(hts[1], entity, 84))
	assert(false == world:Set(hts[2], entity, 84))
	assert(false == world:Set(hts[3], entity, 84))
	assert(false == world:Set(hts[4], entity, 84))
	assert(false == world:Set(hts[5], entity, 84))
	assert(false == world:Set(hts[6], entity, 84))
	assert(false == world:Set(entity, 84))
	assert(false == world:Set(entity, hts[1], 84))
	assert(false == world:Set(entity, hts[2], 84))
	assert(false == world:Set(entity, hts[3], 84))
	assert(false == world:Set(entity, hts[4], 84))
	assert(false == world:Set(entity, hts[5], 84))
	assert(false == world:Set(entity, hts[6], 84))
	assert(false == world:Set(entity, entity, 84))
end

function T.TestWorld_Handle(t, require)
	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	assert(world:Handle())
	assert(world:Handle(hts[1]))
	assert(world:Handle(hts[2]))
	assert(world:Handle(hts[3]))
	assert(world:Handle(hts[4]))
	assert(world:Handle(hts[5]))
	assert(world:Handle(hts[6]))
	world:Init()
	assert(world:Handle())
	assert(world:Handle(hts[1]))
	assert(world:Handle(hts[2]))
	assert(world:Handle(hts[3]))
	assert(world:Handle(hts[4]))
	assert(world:Handle(hts[5]))
	assert(world:Handle(hts[6]))
	local entity = world:CreateEntity("Entity")
	assert(world:Handle(entity))
	world:DestroyEntity(entity)
	world:Upkeep()
	assert(world:Handle(entity))
end

function T.TestHandle_call(t, require)
	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	local handle = world:Handle()
	assert(false == handle())
	assert(false == handle(hts[1]))
	assert(false == handle(hts[2]))
	assert(false == handle(hts[3]))
	assert(false == handle(hts[4]))
	assert(false == handle(hts[5]))
	assert(false == handle(hts[6]))
	world:Init()
	assert(false == handle())
	assert(false == handle(hts[1]))
	assert(false == handle(hts[2]))
	assert(false == handle(hts[3]))
	assert(false == handle(hts[4]))
	assert(false == handle(hts[5]))
	assert(false == handle(hts[6]))
	local entity = world:CreateEntity("Entity")
	local handle = world:Handle(entity)
	assert(true  == handle())
	assert(true  == handle(hts[1])) -- Maybe should be false.
	assert(false == handle(hts[2]))
	assert(false == handle(hts[3]))
	assert(false == handle(hts[4]))
	assert(true  == handle(hts[5]))
	assert(false == handle(hts[6]))
	world:DestroyEntity(entity)
	world:Upkeep()
	assert(false == handle())
	assert(false == handle(hts[1]))
	assert(false == handle(hts[2]))
	assert(false == handle(hts[3]))
	assert(false == handle(hts[4]))
	assert(false == handle(hts[5]))
	assert(false == handle(hts[6]))
end

function T.TestHandle_index(t, require)
	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	local handle = world:Handle()
	for i = 1, 6 do assert(nil == handle[hts[i]]) end
	world:Init()
	for i = 1, 6 do assert(nil == handle[hts[i]]) end
	local entity = world:CreateEntity("Entity")
	local handle = world:Handle(entity)
	assert(nil == handle[hts[1]])
	assert(nil == handle[hts[2]])
	assert(nil == handle[hts[3]])
	assert(nil == handle[hts[4]])
	assert(42  == handle[hts[5]])
	assert(nil == handle[hts[6]])
	world:DestroyEntity(entity)
	world:Upkeep()
	for i = 1, 6 do assert(nil == handle[hts[i]]) end
end

function T.TestHandle_newindex(t, require)
	local world = require().NewWorld()
	world:DefineComponent(hts[5], 42)
	world:DefineEntity("Entity", {[hts[5]]=true})
	local handle = world:Handle()
	for i = 2, 6 do -- Nil not allowed as index.
		assert(nil == handle[hts[i]]); handle[hts[i]] = 84; assert(nil == handle[hts[i]])
	end
	world:Init()
	for i = 2, 6 do
		assert(nil == handle[hts[i]]); handle[hts[i]] = 84; assert(nil == handle[hts[i]])
	end
	local entity = world:CreateEntity("Entity")
	local handle = world:Handle(entity)
	assert(nil == handle[hts[2]]); handle[hts[2]] = 84; assert(nil == handle[hts[2]])
	assert(nil == handle[hts[3]]); handle[hts[3]] = 84; assert(nil == handle[hts[3]])
	assert(nil == handle[hts[4]]); handle[hts[4]] = 84; assert(nil == handle[hts[4]])
	assert(42  == handle[hts[5]]); handle[hts[5]] = 84; assert(84  == handle[hts[5]])
	assert(nil == handle[hts[6]]); handle[hts[6]] = 84; assert(nil == handle[hts[6]])
	world:DestroyEntity(entity)
	world:Upkeep()
	for i = 2, 6 do
		assert(nil == handle[hts[i]]); handle[hts[i]] = 84; assert(nil == handle[hts[i]])
	end
end

-- Simulation of two objects moving towards each other that stop when they're
-- close enough.
function T.TestSimulate(t, require)
	local world = require().NewWorld()

	world:DefineComponent("Speed", 1)
	world:DefineComponent("Position", function(x,y,z)
		return Vector3.new(x,y,z)
	end)
	world:DefineComponent("MoveTo", {
		Target = false,
		Position = Vector3.new(0,0,0),
	})

	world:DefineEntity("Buddy", function(x,y,z) return {
		Speed = true,
		Position = {x,y,z},
		MoveTo = true,
	} end)

	world:DefineSystem("MoveTo",
		{"Speed", "Position", "MoveTo"},
		function(world, entities, dt)
			for _, e in ipairs(entities) do
				local target = world:Entity(target)
				if target then
					local direction = (target.Position - e.Position)
					if direction.magnitude > 1 then
						e.MoveTo.Position = e.Position + direction.unit*(e.Speed*dt)
					end
				end
			end
		end
	)
	world:DefineSystem("SetPosition",
		{"Position", "MoveTo"},
		function(world, entities, dt)
			for _, e in ipairs(entities) do
				e.Position = e.MoveTo.Position
			end
		end
	)

	world:Init()

	local a = world:CreateEntity("Buddy",-10,0,0)
	local b = world:CreateEntity("Buddy",10,0,0)
	world:Get(a, "MoveTo").Target = b
	world:Get(b, "MoveTo").Target = a
	for i = 1, 20 do
		world:Update("MoveTo", 1)
		world:Update("SetPosition", 1)
		world:Upkeep()
	end

	t:Log("A", world:Get(a, "Position"))
	t:Log("B", world:Get(b, "Position"))
	assert(world:Get(a,"Position"):FuzzyEq(Vector3.new(0,0,0)))
	assert(world:Get(b,"Position"):FuzzyEq(Vector3.new(0,0,0)))
end

return T
