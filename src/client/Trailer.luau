--!strict
-- Режим трейлера: только в Studio, клавиша F8. Камера сама проходит по планам
-- (хаб, витрина, свой остров, крутка с анимацией выпадения, кольцо островов, титр),
-- а ты записываешь экран (Win+Alt+R). В живой игре модуль не включается.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Trailer = {}

type Shot = { from: CFrame, to: CFrame, time: number, hud: boolean?, onStart: (() -> ())? }

local running = false

local function look(from: Vector3, at: Vector3): CFrame
	return CFrame.lookAt(from, at)
end

local function myIslandCenter(): Vector3?
	local islands = workspace:FindFirstChild("Islands")
	if not islands then
		return nil
	end
	for _, m in islands:GetChildren() do
		if m:GetAttribute("Owner") == player.UserId and m:IsA("Model") then
			local root = m:FindFirstChild("Root") :: BasePart?
			return root and root.Position
		end
	end
	return nil
end

function Trailer.bind(gui: ScreenGui, showReveal: (any) -> ())
	if not RunService:IsStudio() then
		return
	end
	-- затемнение между планами и финальный титр
	local fade = UI.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 200,
	})
	local title = UI.label(fade, "SPROUT RNG", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0.8, 0, 0, 90),
		TextTransparency = 1,
		ZIndex = 201,
	})
	local limit = title:FindFirstChildOfClass("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = 96
	end
	UI.paletteGradient(title, { Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 176, 60) }, 90)
	local subtitle = UI.label(fade, "ROLL FOR FREE  ·  35 MAGICAL TREES  ·  GROW YOUR ISLAND", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.new(0.8, 0, 0, 28),
		Font = UI.fontRegular,
		TextTransparency = 1,
		ZIndex = 201,
	})

	local function blink()
		TweenService:Create(fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
		task.wait(0.25)
		TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end

	local function run()
		if running then
			return
		end
		running = true
		local cam = workspace.CurrentCamera
		local oldType = cam.CameraType
		local worldHud = gui:FindFirstChild("WorldHud") :: GuiObject?
		cam.CameraType = Enum.CameraType.Scriptable
		local hub = Vector3.new(0, 40, 0)
		local island = myIslandCenter() or Vector3.new(190, 40, 0)
		local root = player.Character
			and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local me = if root then root.Position else island
		local shots: { Shot } = {
			{
				from = look(hub + Vector3.new(120, 60, 120), hub),
				to = look(hub + Vector3.new(-40, 45, 140), hub),
				time = 5,
			},
			{
				from = look(hub + Vector3.new(30, 8, 40), hub + Vector3.new(-24, 10, 24)),
				to = look(hub + Vector3.new(40, 10, -10), hub + Vector3.new(24, 10, -24)),
				time = 5,
			},
			{
				from = look(island + Vector3.new(0, 10, 60), island + Vector3.new(0, 6, 0)),
				to = look(island + Vector3.new(30, 45, 40), island),
				time = 5,
			},
			{
				-- крутка: камера за спиной игрока, интерфейс включён, редкое выпадение
				from = look(me + Vector3.new(0, 6, 14), me + Vector3.new(0, 3, 0)),
				to = look(me + Vector3.new(4, 5, 11), me + Vector3.new(0, 3, 0)),
				time = 6,
				hud = true,
				onStart = function()
					task.delay(0.6, showReveal, { treeId = "phoenix", isNew = true, lucky = true })
				end,
			},
			{
				from = look(hub + Vector3.new(0, 30, 0), hub + Vector3.new(190, 30, 0)),
				to = look(hub + Vector3.new(0, 160, 10), hub),
				time = 5,
			},
		}
		for _, shot in shots do
			if worldHud then
				worldHud.Visible = shot.hud == true
			end
			cam.CFrame = shot.from
			if shot.onStart then
				shot.onStart()
			end
			TweenService
				:Create(cam, TweenInfo.new(shot.time, Enum.EasingStyle.Sine), { CFrame = shot.to })
				:Play()
			task.wait(shot.time - 0.25)
			blink()
		end
		-- финальный титр
		TweenService:Create(fade, TweenInfo.new(0.6), { BackgroundTransparency = 0.25 }):Play()
		TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
		task.wait(3.5)
		TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		cam.CameraType = oldType
		if worldHud then
			worldHud.Visible = true
		end
		running = false
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F8 then
			task.spawn(run)
		end
	end)
end

return Trailer
