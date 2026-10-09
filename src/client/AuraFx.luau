--!strict
-- Косметическое сияние персонажей. Сервер ставит атрибут Aura на модель персонажа,
-- каждый клиент рисует сияние сам: частицы в гамме вида, свет, орбита воксельных
-- кубиков и лучи у редких видов. Анимация локальная, по сети ничего не гоняем.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garden = require(ReplicatedStorage.Shared.Garden)

local AuraFx = {}

type Active = {
	character: Model,
	root: BasePart,
	folder: Folder,
	ring: { BasePart },
	rays: { BasePart },
	palette: { Color3 },
}

local active: { [Model]: Active } = {}

local function sequence(palette: { Color3 }): ColorSequence
	local keys = {}
	for i, c in palette do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #palette - 1), c))
	end
	return ColorSequence.new(keys)
end

-- Настройка частиц под стиль.
local function emitter(style: string, palette: { Color3 }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Color = sequence(palette)
	pe.LightEmission = 0.6
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Rate = 8
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Speed = NumberRange.new(0.3, 1)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.22, 0)
	if style == "petals" then
		pe.Acceleration = Vector3.new(0, -1.2, 0)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Rotation = NumberRange.new(0, 360)
		pe.Size = NumberSequence.new(0.3, 0.15)
		pe.LightEmission = 0.2
	elseif style == "embers" then
		pe.Acceleration = Vector3.new(0, 3, 0)
		pe.LightEmission = 1
		pe.Rate = 14
		pe.Size = NumberSequence.new(0.18, 0)
	elseif style == "sparkle" then
		pe.LightEmission = 1
		pe.Rate = 10
		pe.Lifetime = NumberRange.new(0.4, 0.8)
		pe.Speed = NumberRange.new(0, 0.2)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
	elseif style == "frost" then
		pe.Acceleration = Vector3.new(0, -0.4, 0)
		pe.LightEmission = 0.8
		pe.Rotation = NumberRange.new(45, 45)
		pe.Size = NumberSequence.new(0.25, 0.05)
	elseif style == "void" then
		pe.LightEmission = 0
		pe.Rate = 16
		pe.Speed = NumberRange.new(1, 2)
		pe.Acceleration = Vector3.new(0, -0.5, 0)
		pe.Size = NumberSequence.new(0.5, 0)
		pe.Transparency = NumberSequence.new(0.2, 1)
	elseif style == "stars" then
		pe.LightEmission = 1
		pe.Rate = 12
		pe.Lifetime = NumberRange.new(1.5, 2.5)
		pe.Speed = NumberRange.new(0.1, 0.4)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	return pe
end

local function clear(character: Model)
	local a = active[character]
	if a then
		a.folder:Destroy()
		active[character] = nil
	end
end

local function build(character: Model)
	clear(character)
	local id = character:GetAttribute("Aura") :: string?
	local tree = Garden.tree(id)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tree or not root then
		return
	end
	local aura = Garden.aura(tree.id)
	local folder = Instance.new("Folder")
	folder.Name = "AuraFx"
	folder.Parent = workspace

	local holder = Instance.new("Part")
	holder.Name = "Emitter"
	holder.Anchored = false
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Massless = true
	holder.Transparency = 1
	holder.Size = Vector3.new(3, 5, 3)
	holder.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = holder
	weld.Parent = holder
	holder.Parent = folder
	emitter(aura.particles, aura.palette).Parent = holder
	if aura.light then
		local light = Instance.new("PointLight")
		light.Color = aura.palette[1]
		light.Range = 10
		light.Brightness = 0.8
		light.Parent = holder
	end

	local ring: { BasePart } = {}
	if aura.ring then
		for i = 1, 8 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = aura.palette[(i % #aura.palette) + 1]
			p.Size = Vector3.new(0.35, 0.35, 0.35)
			p.Parent = folder
			table.insert(ring, p)
		end
	end
	local rays: { BasePart } = {}
	if aura.rays then
		for i = 1, 4 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = aura.palette[(i % #aura.palette) + 1]
			p.Transparency = 0.75
			p.Size = Vector3.new(0.12, 5, 0.12)
			p.Parent = folder
			table.insert(rays, p)
		end
	end
	active[character] = {
		character = character,
		root = root,
		folder = folder,
		ring = ring,
		rays = rays,
		palette = aura.palette,
	}
end

local function watch(character: Model)
	task.spawn(function()
		character:WaitForChild("HumanoidRootPart", 10)
		build(character)
	end)
	character:GetAttributeChangedSignal("Aura"):Connect(function()
		build(character)
	end)
	character.Destroying:Connect(function()
		clear(character)
	end)
end

local function watchPlayer(p: Player)
	if p.Character then
		watch(p.Character)
	end
	p.CharacterAdded:Connect(watch)
	p.CharacterRemoving:Connect(clear)
end

function AuraFx.start()
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for character, a in active do
			if not a.root.Parent then
				clear(character)
				continue
			end
			local base = a.root.Position - Vector3.new(0, 1, 0)
			for i, p in a.ring do
				local ang = t * 1.6 + i / #a.ring * math.pi * 2
				local y = math.sin(t * 2 + i) * 0.6 + 0.5
				p.CFrame = CFrame.new(
					base + Vector3.new(math.cos(ang) * 2.4, y, math.sin(ang) * 2.4)
				) * CFrame.Angles(t * 2, t * 3, 0)
			end
			for i, p in a.rays do
				local ang = t * 0.5 + i / #a.rays * math.pi * 2
				p.CFrame = CFrame.new(a.root.Position - a.root.CFrame.LookVector * 0.8)
					* a.root.CFrame.Rotation
					* CFrame.Angles(0, 0, ang)
					* CFrame.new(0, 2.2, 0)
			end
		end
	end)
end

return AuraFx
