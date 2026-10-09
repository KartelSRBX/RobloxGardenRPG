--!strict
-- Вращение орбит у эксклюзивных деревьев. Сервер ставит детали один раз,
-- клиент плавно крутит их вокруг центра кроны (локально, без нагрузки на сеть).
local RunService = game:GetService("RunService")

local OrbitFx = {}

type Orbit = {
	model: Model,
	center: Vector3,
	speed: number,
	parts: { { part: BasePart, offset: CFrame } },
}

local orbits: { [Model]: Orbit } = {}

local function track(m: Instance)
	if not m:IsA("Model") or m.Name ~= "Orbit" or orbits[m] then
		return
	end
	local center = m:GetAttribute("Center") :: Vector3?
	if not center then
		return
	end
	local list = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(list, { part = p, offset = CFrame.new(center):ToObjectSpace(p.CFrame) })
		end
	end
	local entry = {
		model = m,
		center = center,
		speed = (m:GetAttribute("Speed") or 1) :: number,
		parts = list,
	}
	orbits[m] = entry
	m.ChildAdded:Connect(function(p)
		if p:IsA("BasePart") then
			table.insert(
				entry.parts,
				{ part = p, offset = CFrame.new(center):ToObjectSpace(p.CFrame) }
			)
		end
	end)
	m.Destroying:Connect(function()
		orbits[m] = nil
	end)
end

function OrbitFx.start()
	local function watch(folder: Instance)
		for _, d in folder:GetDescendants() do
			track(d)
		end
		folder.DescendantAdded:Connect(function(d)
			-- детали орбиты приходят следом за моделью
			task.defer(track, d)
		end)
	end
	task.spawn(function()
		watch(workspace:WaitForChild("Islands"))
	end)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for m, o in orbits do
			if not m.Parent then
				orbits[m] = nil
				continue
			end
			local spin = CFrame.new(o.center) * CFrame.Angles(0, t * o.speed, 0)
			for i, item in o.parts do
				item.part.CFrame = spin
					* item.offset
					* CFrame.new(0, math.sin(t * 2 + i) * 0.25, 0)
					* CFrame.Angles(0, t * 1.5, 0)
			end
		end
	end)
end

return OrbitFx
