--!strict
-- Имена удалённых вызовов. Сервер создаёт их, клиент ждёт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER = "Remotes"

local Remotes = {
	-- RemoteFunction: клиент просит, сервер отвечает { ok, error?, ... }
	functions = {
		"GetState",
		"Roll",
		"SetAutoRoll",
		"BuyLuck",
		"BuySpeed",
		"Plant",
		"Harvest",
		"Upgrade",
		"Remove",
		"Fertilize",
		"Expand",
		"GoHome",
		"GoHub",
		"DungeonEnter",
		"DungeonAttack",
		"DungeonRevive",
		"DungeonLeave",
		"SellItem",
		"SellSeed",
		"EquipAura",
	},
	-- RemoteEvent: State — снимок профиля, Dungeon — состояние забега,
	-- Fx — эффекты (монеты над грядкой, удары), Rolled — результат авто-крутки
	events = { "State", "Dungeon", "Fx", "Rolled", "Announce" },
}

local function folder(): Folder
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild(FOLDER)
		if not f then
			local created = Instance.new("Folder")
			created.Name = FOLDER
			for _, name in Remotes.functions do
				Instance.new("RemoteFunction", created).Name = name
			end
			for _, name in Remotes.events do
				Instance.new("RemoteEvent", created).Name = name
			end
			created.Parent = ReplicatedStorage
			f = created
		end
		return f :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER) :: Folder
end

function Remotes.fn(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

function Remotes.event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
