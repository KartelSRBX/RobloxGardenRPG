--!strict
-- Визуальные эффекты: монеты над грядкой, цифры урона, вспышка при ударе по игроку,
-- облачко при победе над врагом, конфетти при выпадении семени.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local Effects = {}

local gui: ScreenGui? = nil
local flash: Frame? = nil

function Effects.init(screenGui: ScreenGui)
	gui = screenGui
	flash = UI.frame(screenGui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 40, 40),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Active = false,
	})
end

local function anchor(pos: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = pos
	p.Parent = workspace
	Debris:AddItem(p, life)
	return p
end

-- Всплывающий текст в мире.
function Effects.floatText(pos: Vector3, text: string, color: Color3, size: number?)
	local a = anchor(pos, 1.4)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, size or 50)
	bb.AlwaysOnTop = true
	bb.Adornee = a
	bb.Parent = a
	local l = UI.label(bb, text, { TextColor3 = color })
	UI.textStroke(l, 2.5)
	TweenService:Create(bb, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(l, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
end

function Effects.poof(pos: Vector3, color: Color3)
	local a = anchor(pos, 2)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(1.2, 0)
	pe.Speed = NumberRange.new(8, 14)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.4, 0.7)
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(24)
end

function Effects.hurt()
	local f = flash
	if not f then
		return
	end
	f.BackgroundTransparency = 0.6
	TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

function Effects.confetti(color: Color3)
	local g = gui
	if not g then
		return
	end
	local rng = Random.new()
	for _ = 1, 36 do
		local c = UI.frame(g, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.08, 0.08), 0.35),
			Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(8, 14)),
			BackgroundColor3 = if rng:NextNumber() < 0.5
				then color
				else Color3.fromHSV(rng:NextNumber(), 0.7, 1),
			Rotation = rng:NextNumber(0, 360),
			ZIndex = 60,
		})
		local target = UDim2.fromScale(0.5 + rng:NextNumber(-0.45, 0.45), 1.1)
		TweenService:Create(
			c,
			TweenInfo.new(rng:NextNumber(1.2, 2), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = target,
				Rotation = rng:NextNumber(-360, 360),
			}
		):Play()
		Debris:AddItem(c, 2.2)
	end
end

-- События с сервера.
function Effects.handle(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "coins" and payload.pos then
		Effects.floatText(payload.pos, `+{UI.formatNumber(payload.amount)}`, UI.colors.gold, 60)
		Effects.poof(payload.pos, UI.colors.gold)
	elseif payload.kind == "hit" and payload.pos then
		Effects.floatText(
			payload.pos + Vector3.new(0, 3, 0),
			`-{payload.amount}`,
			Color3.fromRGB(255, 240, 120)
		)
	elseif payload.kind == "kill" and payload.pos then
		Effects.poof(payload.pos, Color3.fromRGB(200, 255, 200))
	elseif payload.kind == "hurt" then
		Effects.hurt()
	end
end

return Effects
