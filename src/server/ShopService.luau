--!strict
-- Геймпассы: только предсказуемые покупки (см. Config.GamePasses).
-- Покупку показывает клиент, сервер лишь проверяет владение.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ShopService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local changed = Instance.new("BindableEvent")
ShopService.changed = changed.Event

local function passById(id: number)
	for _, pass in Config.GamePasses do
		if pass.id == id and id ~= 0 then
			return pass
		end
	end
	return nil
end

local function load(player: Player)
	local set: { [string]: boolean } = {}
	for _, pass in Config.GamePasses do
		if pass.id ~= 0 then
			local ok, has = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				pass.id
			)
			if ok and has then
				set[pass.key] = true
			end
		end
	end
	owned[player] = set
	changed:Fire(player)
end

function ShopService.owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

function ShopService.ownedList(player: Player): { [string]: boolean }
	return owned[player] or {}
end

-- Купленные эксклюзивные деревья: { [treeId] = true }.
function ShopService.ownedTrees(player: Player): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, pass in Config.GamePasses do
		local treeId = (pass :: any).treeId
		if treeId and ShopService.owns(player, pass.key) then
			out[treeId] = true
		end
	end
	return out
end

function ShopService.bonusPlots(player: Player): number
	return if ShopService.owns(player, "plots2") then Config.BonusPlots else 0
end

-- Только в Studio: выдать себе пропуск без покупки, чтобы проверить его в игре.
-- В живой игре не работает (RunService:IsStudio() = false).
function ShopService.testGrant(player: Player, key: any): string?
	if not RunService:IsStudio() then
		return "studio_only"
	end
	local found = false
	for _, pass in Config.GamePasses do
		if pass.key == key then
			found = true
		end
	end
	if not found or not owned[player] then
		return "bad_args"
	end
	owned[player][key] = true
	changed:Fire(player)
	return nil
end

function ShopService.coinMult(player: Player): number
	return if ShopService.owns(player, "coins2x") then 2 else 1
end

function ShopService.start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
		local pass = passById(id)
		if purchased and pass and owned[player] then
			owned[player][pass.key] = true
			changed:Fire(player)
		end
	end)
end

return ShopService
