--!strict
-- Ограничение частоты запросов: одно действие игрока не чаще интервала из Config.
local Players = game:GetService("Players")

local RateLimit = {}

local last: { [Player]: { [string]: number } } = {}

function RateLimit.allow(player: Player, action: string, interval: number): boolean
	local now = os.clock()
	local byAction = last[player]
	if not byAction then
		byAction = {}
		last[player] = byAction
	end
	local prev = byAction[action]
	if prev and now - prev < interval then
		return false
	end
	byAction[action] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)

return RateLimit
