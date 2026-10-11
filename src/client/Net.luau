--!strict
-- Запросы к серверу и понятные тексты ошибок.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

local ERRORS: { [string]: string } = {
	not_enough_coins = "Not enough coins",
	not_loaded = "Loading...",
	too_fast = "Slow down!",
	not_ready = "Not ready yet",
	max_level = "Max level!",
	no_seed = "No seed",
	occupied = "Plot is busy",
	no_fertilizer = "No fertilizer. Find it in the Dungeon",
	already_ready = "Already ripe!",
	max_plots = "All plots bought!",
	in_run = "Finish your dungeon run first",
	dungeon_full = "Dungeon is busy, try again soon",
	in_fight = "Defeat this wave first!",
	no_character = "Wait for your character",
	cooldown = "Rolling...",
	auto_locked = "Auto roll unlocks after 250 rolls",
	need_time = "Play a bit longer to expand",
	need_seeds = "Need more sprouts to expand",
	max_island = "Island is at max size",
	not_owned = "You don't own this yet",
	already_planted = "This tree is already on your island",
	studio_only = "Purchases open when the game is published",
}

function Net.request(name: string, ...: any): { [string]: any }
	local remote = Remotes.fn(name)
	local ok, res = pcall(remote.InvokeServer, remote, ...)
	if ok and type(res) == "table" then
		return res
	end
	return { ok = false, error = "Connection problem" }
end

function Net.errorText(code: string?): string
	if not code then
		return "Something went wrong"
	end
	return ERRORS[code] or code
end

return Net
