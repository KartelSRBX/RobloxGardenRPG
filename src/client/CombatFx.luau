--!strict
-- Звук и эффекты боя в подземелье по событиям сервера (Fx):
-- wave (появление врагов), swing (взмах), hit (попадание), kill (смерть врага),
-- hurt (урон игроку), drop (добыча). Для оружия с anim: дуга удара в цвет оружия,
-- след за клинком, вращающаяся орбита мелких элементов.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local CombatFx = {}

local weaponById: { [string]: any } = {}
for _, w in Config.Weapons do
	weaponById[w.id] = w
end

local function character(): Model?
	return player.Character
end

local function equippedTool(): Tool?
	local c = character()
	return c and c:FindFirstChildOfClass("Tool")
end

-- Дуга удара: ряд светящихся кубиков перед игроком, разлетается и гаснет.
local function slashArc(w: any)
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local count = 9
	local radius = math.clamp(w.range * 0.28, 2.6, 5)
	local base = root.CFrame * CFrame.new(0, 0.4, 0)
	local tilt = if w.toolanim == "Lunge" then 0 else math.rad(20)
	for i = 1, count do
		local t = (i - 1) / (count - 1)
		local ang = math.rad(-80 + 160 * t)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = w.edge:Lerp(w.accent, t)
		local s = 0.35 + math.sin(t * math.pi) * 0.45
		part.Size = Vector3.new(s, s, s)
		-- дуга перед игроком; у копий (Lunge) — прямая вперёд
		local forward = if w.toolanim == "Lunge"
			then Vector3.new(0, 0, -(1.5 + t * radius * 1.6))
			else Vector3.new(math.sin(ang) * radius, 0, -math.cos(ang) * radius)
		part.CFrame = base * CFrame.Angles(0, 0, tilt) * CFrame.new(forward)
		part.Transparency = 0.05
		part.Parent = workspace
		TweenService:Create(part, TweenInfo.new(0.32, Enum.EasingStyle.Quad), {
			Transparency = 1,
			Size = Vector3.new(0.05, 0.05, 0.05),
			CFrame = part.CFrame * CFrame.new(0, 0.3, -1.2),
		}):Play()
		Debris:AddItem(part, 0.5)
	end
end

local function enableTrail(tool: Tool, seconds: number)
	local trail = tool:FindFirstChild("SwingTrail", true) :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(seconds, function()
			if trail.Parent then
				trail.Enabled = false
			end
		end)
	end
end

function CombatFx.handle(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "swing" then
		local w = weaponById[payload.weapon]
		if w then
			Sfx.swing(w.swing, nil)
			if w.anim then
				slashArc(w)
				local tool = equippedTool()
				if tool then
					enableTrail(tool, 0.4)
				end
			end
		end
	elseif kind == "hit" then
		local w = weaponById[payload.weapon]
		if w then
			Sfx.weaponHit(w.hit, payload.pos)
		end
		if payload.enemy then
			Sfx.enemy(payload.enemy, "hit", payload.pos)
		end
	elseif kind == "kill" then
		if payload.enemy then
			Sfx.enemy(payload.enemy, "die", payload.pos)
		end
	elseif kind == "hurt" then
		Sfx.playerHurt()
		if payload.enemy then
			Sfx.enemy(payload.enemy, "attack", nil)
		end
	elseif kind == "wave" then
		Sfx.enemy(payload.enemy, "spawn", nil)
	elseif kind == "drop" then
		Sfx.loot()
	elseif kind == "coins" then
		Sfx.coins()
	end
end

-- Вращение орбиты у оружия в руке (локально, без сети).
function CombatFx.start()
	-- встроенная панель инструментов Roblox не нужна: оружие и слоты рисует наш HUD
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local base: { [Weld]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local tool = equippedTool()
		if not tool or not tool:GetAttribute("Orbit") then
			return
		end
		local hub = tool:FindFirstChild("OrbitHub")
		local weld = hub and hub:FindFirstChild("OrbitWeld") :: Weld?
		if not weld then
			return
		end
		if not base[weld] then
			base[weld] = weld.C0
		end
		weld.C0 = base[weld]
			* CFrame.Angles(0, 0, t * 2.4)
			* CFrame.new(0, 0, math.sin(t * 3) * 0.12)
	end)
end

return CombatFx
