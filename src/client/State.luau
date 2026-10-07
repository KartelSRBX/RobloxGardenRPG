--!strict
-- Последний снимок с сервера: профиль, геймпассы, забег. Экраны подписываются на changed.
local State = {
	profile = nil :: any,
	passes = {} :: { [string]: boolean },
	dungeon = nil :: any,
}

local changed = Instance.new("BindableEvent")
local dungeonChanged = Instance.new("BindableEvent")
State.changed = changed.Event
State.dungeonChanged = dungeonChanged.Event

function State.set(profile: any, meta: any?)
	State.profile = profile
	if type(meta) == "table" and type(meta.passes) == "table" then
		State.passes = meta.passes
	end
	changed:Fire()
end

function State.setDungeon(payload: any)
	State.dungeon = payload
	dungeonChanged:Fire(payload)
end

function State.inRun(): boolean
	return State.dungeon ~= nil and State.dungeon.active == true
end

return State
