--!strict
-- Воксельное оружие в руках: Tool с невидимым Handle, модель из вокселей приварена к нему.
-- Клинок направлен по -Z рукоятки (вперёд при стандартной позе удержания инструмента).
-- У оружия с anim = true: неоновая кромка, свет, частицы стиля оружия, след за клинком (Trail,
-- включается клиентом на время удара) и вращающаяся орбита мелких элементов (OrbitWeld).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponsConfig = require(ReplicatedStorage.Shared.Config.Weapons)
local Voxel = require(script.Parent.Voxel)

type Weapon = WeaponsConfig.Weapon

local WeaponBuilder = {}

local V = 0.3

local function weaponById(id: string): Weapon?
	for _, w in Config.Weapons do
		if w.id == id then
			return w
		end
	end
	return nil
end

WeaponBuilder.byId = weaponById

type Brush = (
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	c: Color3,
	neon: boolean?
) -> ()

-- Кисть: заливает параллелепипед вокселей.
local function brush(g: Voxel.Grid, glow: boolean): Brush
	return function(x0, y0, z0, x1, y1, z1, c, neon)
		local material = if neon and glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for x = math.min(x0, x1), math.max(x0, x1) do
			for y = math.min(y0, y1), math.max(y0, y1) do
				for z = math.min(z0, z1), math.max(z0, z1) do
					Voxel.set(g, x, y, z, c, material)
				end
			end
		end
	end
end

local function shade(c: Color3, k: number): Color3
	return if k >= 0 then c:Lerp(Color3.new(1, 1, 1), k) else c:Lerp(Color3.new(0, 0, 0), -k)
end

-- Параметры форм. Возвращает: длина клинка в вокселях, положение центра «головы» (для орбит, света).
local function build(g: Voxel.Grid, w: Weapon): (number, number)
	local b = brush(g, w.anim)
	local blade, edge, hilt, accent = w.blade, w.edge, w.hilt, w.accent
	local kind = w.kind

	-- общая рукоять и навершие
	local function grip(from: number, to: number)
		b(0, from, 0, 0, to, 0, hilt)
		b(-1, from, 0, -1, to, 0, shade(hilt, -0.2))
		b(0, from, -1, 0, to, -1, shade(hilt, -0.2))
		b(-1, from, -1, -1, to, -1, shade(hilt, -0.3))
	end

	if kind == "sword" then
		grip(-5, 0)
		b(-1, -6, -1, 0, -6, 0, accent) -- навершие
		b(-4, 1, -1, 3, 1, 0, accent) -- гарда
		b(-3, 2, -1, 2, 2, 0, shade(accent, -0.2))
		for y = 2, 18 do
			local taper = y > 15 and (y - 15) or 0
			b(-1 + taper, y, -1, 0 - taper, y, 0, blade)
			if taper < 2 then
				b(-2 + taper, y, -1, -2 + taper, y, 0, edge, true)
				b(1 - taper, y, -1, 1 - taper, y, 0, edge, true)
			end
		end
		b(-1, 19, -1, 0, 19, 0, edge, true)
		return 19, 11
	elseif kind == "katana" then
		grip(-6, 0)
		b(-1, -7, -1, 0, -7, 0, accent)
		b(-3, 1, -3, 2, 1, 2, accent) -- цуба
		b(-2, 2, -2, 1, 2, 1, shade(accent, -0.3))
		for y = 2, 22 do
			local curve = if y > 14 then (y - 14) // 4 else 0
			local taper = if y > 19 then y - 19 else 0
			b(-1 + curve, y, -1, 0 + curve - taper, y, 0, blade)
			b(1 + curve - taper, y, -1, 1 + curve - taper, y, 0, edge, true)
		end
		b(1 + 2, 23, -1, 2 + 2, 23, 0, edge, true)
		return 23, 13
	elseif kind == "dagger" then
		grip(-3, 0)
		b(-1, -4, -1, 0, -4, 0, accent)
		b(-3, 1, -1, 2, 1, 0, accent)
		for y = 2, 10 do
			local taper = if y > 7 then y - 7 else 0
			b(-1 + (taper > 1 and 1 or 0), y, -1, 0 - (taper > 1 and 1 or 0), y, 0, blade)
			if taper == 0 then
				b(-2, y, -1, -2, y, 0, edge, true)
				b(1, y, -1, 1, y, 0, edge, true)
			end
		end
		b(-1, 11, -1, 0, 11, 0, edge, true)
		return 11, 6
	elseif kind == "axe" then
		grip(-5, 12)
		b(-1, -6, -1, 0, -6, 0, accent)
		-- голова: клин вправо
		for y = 8, 15 do
			local reach = 6 - math.abs(y - 11.5) * 1.1
			for x = 1, math.floor(reach) do
				b(
					x,
					y,
					-1,
					x,
					y,
					0,
					if x >= math.floor(reach) then edge else blade,
					x >= math.floor(reach)
				)
			end
		end
		b(-3, 9, -1, -1, 14, 0, shade(blade, -0.1)) -- обух
		b(-3, 10, -1, -3, 13, 0, accent)
		return 15, 12
	elseif kind == "hammer" then
		grip(-5, 14)
		b(-1, -6, -1, 0, -6, 0, accent)
		b(-5, 15, -3, 4, 21, 2, blade) -- боёк
		b(-5, 15, -3, -5, 21, 2, shade(blade, -0.2))
		b(4, 15, -3, 4, 21, 2, edge, true)
		b(-5, 15, -3, 4, 15, 2, accent)
		b(-5, 21, -3, 4, 21, 2, accent)
		return 21, 18
	elseif kind == "spear" then
		grip(-5, 22)
		b(-1, -6, -1, 0, -6, 0, accent)
		b(-1, 18, -1, 0, 20, 0, accent) -- кисть
		for k = 0, 6 do
			local half = math.max(0, 2 - k // 2)
			b(-1 - half, 23 + k, -1, half, 23 + k, 0, if k > 3 then edge else blade, k > 3)
		end
		b(-1, 30, -1, 0, 30, 0, edge, true)
		return 30, 25
	elseif kind == "staff" then
		grip(-5, 18)
		b(-1, -6, -1, 0, -6, 0, accent)
		b(-1, 19, -1, 0, 19, 0, accent)
		-- голова: шар и «клешни» вокруг
		for x = -3, 2 do
			for y = 20, 25 do
				for z = -3, 2 do
					local d = (x + 0.5) ^ 2 + (y - 22.5) ^ 2 + (z + 0.5) ^ 2
					if d <= 7.5 then
						b(x, y, z, x, y, z, if d < 3 then edge else blade, d < 3)
					end
				end
			end
		end
		b(-3, 19, -1, -3, 24, 0, accent)
		b(2, 19, -1, 2, 24, 0, accent)
		return 25, 22
	else -- scythe
		grip(-5, 20)
		b(-1, -6, -1, 0, -6, 0, accent)
		b(-1, 21, -1, 0, 22, 0, accent)
		-- серп: дуга влево
		for x = -9, 1 do
			local y = 22 + math.floor((x + 9) ^ 2 / 14 * -1 + 4.5)
			b(x, y, -1, x, y + 1, 0, blade)
			b(x, y - 1, -1, x, y - 1, 0, edge, true)
		end
		b(-10, 21, -1, -9, 21, 0, edge, true)
		return 24, 22
	end
end

-- Частицы: разные стили.
local function particles(parent: Instance, w: Weapon)
	local style = w.particles
	if not style then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(w.edge, w.accent)
	pe.LightEmission = 1
	pe.Rate = 14
	pe.Lifetime = NumberRange.new(0.5, 1.1)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.28, 0)
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Shape = Enum.ParticleEmitterShape.Box
	if style == "embers" then
		pe.Acceleration = Vector3.new(0, 5, 0)
		pe.Rate = 22
	elseif style == "frost" then
		pe.Acceleration = Vector3.new(0, -2, 0)
		pe.Rotation = NumberRange.new(45, 45)
		pe.Size = NumberSequence.new(0.3, 0.05)
	elseif style == "sparks" then
		pe.Speed = NumberRange.new(2, 6)
		pe.Lifetime = NumberRange.new(0.15, 0.35)
		pe.Rate = 26
		pe.Size = NumberSequence.new(0.18, 0)
	elseif style == "void" then
		pe.LightEmission = 0
		pe.Color = ColorSequence.new(w.accent, Color3.fromRGB(20, 10, 40))
		pe.Size = NumberSequence.new(0.45, 0)
	elseif style == "sun" then
		pe.Rate = 30
		pe.Size = NumberSequence.new(0.4, 0)
		pe.Speed = NumberRange.new(1, 3)
	elseif style == "stars" then
		pe.Lifetime = NumberRange.new(0.8, 1.5)
		pe.Speed = NumberRange.new(0.2, 0.8)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0.34),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	pe.Parent = parent
end

function WeaponBuilder.build(weaponId: string): Tool?
	local w = weaponById(weaponId)
	if not w then
		return nil
	end
	local g = Voxel.new(V * w.scale)
	local length, headY = build(g, w)

	local tool = Instance.new("Tool")
	tool.Name = w.name
	tool.ToolTip = w.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true -- удар идёт через кнопку атаки, а не через клик по экрану
	tool:SetAttribute("WeaponId", w.id)
	tool:SetAttribute("Anim", w.anim)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = tool

	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = tool
	-- модель строится вдоль +Y, поворачиваем так, чтобы клинок смотрел по -Z
	Voxel.build(g, body, CFrame.Angles(-math.rad(90), 0, 0), { castShadow = false })
	for _, p in body:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end

	if w.anim then
		local s = V * w.scale
		-- точки на оси клинка (после поворота: высота y в вокселях → -Z)
		local function axis(yv: number): Vector3
			return Vector3.new(0, 0, -yv * s)
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailBase"
		a0.Position = axis(2)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailTip"
		a1.Position = axis(length)
		a1.Parent = handle
		local trail = Instance.new("Trail")
		trail.Name = "SwingTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(w.edge, w.accent)
		trail.LightEmission = 1
		trail.Lifetime = 0.28
		trail.MinLength = 0.05
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new(1, 0.4)
		trail.Enabled = false
		trail.Parent = handle

		local fx = Instance.new("Attachment")
		fx.Name = "Fx"
		fx.Position = axis(headY)
		fx.Parent = handle
		particles(fx, w)
		local light = Instance.new("PointLight")
		light.Color = w.edge
		light.Range = 7 + w.tier * 1.2
		light.Brightness = 0.8 + w.tier * 0.15
		light.Parent = fx

		-- орбита из мелких светящихся вокселей вокруг головы (крутит клиент)
		if w.kind == "staff" or w.kind == "scythe" or w.kind == "hammer" or w.tier >= 4 then
			local hub = Instance.new("Part")
			hub.Name = "OrbitHub"
			hub.Size = Vector3.new(0.2, 0.2, 0.2)
			hub.Transparency = 1
			hub.CanCollide = false
			hub.CanQuery = false
			hub.Massless = true
			hub.Parent = tool
			local orbitWeld = Instance.new("Weld")
			orbitWeld.Name = "OrbitWeld"
			orbitWeld.Part0 = handle
			orbitWeld.Part1 = hub
			orbitWeld.C0 = CFrame.new(axis(headY))
			orbitWeld.Parent = hub
			local count = 3 + (w.tier // 2)
			for i = 1, count do
				local a = i / count * math.pi * 2
				local bit = Instance.new("Part")
				bit.Name = "OrbitBit"
				bit.Size = Vector3.new(s * 1.3, s * 1.3, s * 1.3)
				bit.Color = if i % 2 == 0 then w.edge else w.accent
				bit.Material = Enum.Material.Neon
				bit.CanCollide = false
				bit.CanQuery = false
				bit.CastShadow = false
				bit.Massless = true
				bit.CFrame = hub.CFrame
					* CFrame.new(math.cos(a) * 1.5, math.sin(a) * 1.5, math.sin(a * 2) * 0.35)
				bit.Parent = tool
				local ow = Instance.new("WeldConstraint")
				ow.Part0 = hub
				ow.Part1 = bit
				ow.Parent = bit
			end
			tool:SetAttribute("Orbit", true)
		end
	end
	return tool
end

return WeaponBuilder
