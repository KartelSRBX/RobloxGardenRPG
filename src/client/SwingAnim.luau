--!strict
-- Боевые анимации ударов: замах, удар, проводка, возврат. Рисуются прямо на суставах R15
-- (плечо, локоть, кисть, поясница), поверх стандартной анимации. Своё на каждый тип оружия,
-- у мечей, катан, топоров и кинжалов две анимации, они чередуются (комбо).
-- Углы в градусах. Ключ: t (0..1 по времени удара), ease к этому ключу, затем
-- плечо rx/ry/rz, локоть rx, кисть rx/ry, поясница ry (поворот) и rx (наклон, минус = вперёд).
-- Для плеча: rx 90 = рука вперёд, 180 = вверх; rz > 0 уводит руку вправо.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SwingAnim = {}

export type Key = { t: number, ease: string, p: { number } }
export type Arc = { tilt: number, from: number, to: number, line: boolean? }
export type Variant = { keys: { Key }, arc: Arc, durMul: number }

local function key(
	t: number,
	ease: string,
	shx: number,
	shy: number,
	shz: number,
	elx: number,
	wrx: number,
	wry: number,
	wsy: number,
	wsx: number
): Key
	return { t = t, ease = ease, p = { shx, shy, shz, elx, wrx, wry, wsy, wsx } }
end

-- Общий вид: замах (плавно) -> удар (резко, ease "in") -> проводка (гаснет) -> возврат
local styles: { [string]: { Variant } } = {
	sword = {
		{ -- рубящий сверху справа налево вниз
			durMul = 1,
			arc = { tilt = 40, from = 80, to = -80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.30, "smooth", 160, 0, 14, 45, 0, 0, -24, 8),
				key(0.50, "in", 62, 0, -4, 6, 12, 0, 26, -10),
				key(0.74, "out", 46, 0, -12, 14, 10, 0, 32, -12),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
		{ -- обратный: слева направо, наискосок
			durMul = 1,
			arc = { tilt = -40, from = -80, to = 80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.30, "smooth", 120, 0, -52, 32, 0, 0, 28, 4),
				key(0.50, "in", 78, 0, 58, 4, 0, 0, -32, -6),
				key(0.74, "out", 70, 0, 72, 10, 0, 0, -38, -6),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	axe = {
		{ -- тяжёлый рубящий сверху вниз
			durMul = 1.05,
			arc = { tilt = -90, from = -80, to = 80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.36, "smooth", 172, 0, 8, 50, 0, 0, -18, 12),
				key(0.54, "in", 52, 0, 0, 0, 14, 0, 18, -16),
				key(0.78, "out", 40, 0, 0, 8, 12, 0, 22, -18),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
		{ -- размашистый боковой справа налево
			durMul = 1.05,
			arc = { tilt = 0, from = 80, to = -80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.36, "smooth", 96, 0, 78, 20, 0, 0, -40, -4),
				key(0.54, "in", 88, 0, -48, 0, 0, 0, 44, -8),
				key(0.78, "out", 84, 0, -60, 6, 0, 0, 52, -8),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	dagger = {
		{ -- быстрый полоснуть
			durMul = 0.9,
			arc = { tilt = 18, from = 70, to = -70 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.28, "smooth", 82, 0, 46, 44, 0, 0, -16, 0),
				key(0.50, "in", 92, 0, -22, 8, 0, 0, 20, -6),
				key(0.72, "out", 92, 0, -30, 12, 0, 0, 24, -6),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
		{ -- быстрый укол
			durMul = 0.9,
			arc = { tilt = 0, from = 0, to = 0, line = true },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.26, "smooth", 18, 0, 6, 84, 0, 0, -14, 0),
				key(0.48, "in", 94, 0, 0, 0, 0, 0, 16, -8),
				key(0.70, "out", 94, 0, 0, 2, 0, 0, 20, -10),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	spear = {
		{ -- выпад с замахом назад
			durMul = 1,
			arc = { tilt = 0, from = 0, to = 0, line = true },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.34, "smooth", 10, 0, 8, 82, 0, 0, -28, 4),
				key(0.52, "in", 96, 0, 0, 0, 0, 0, 24, -14),
				key(0.76, "out", 96, 0, 0, 2, 0, 0, 28, -16),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	hammer = {
		{ -- замах над головой и удар в землю
			durMul = 1.15,
			arc = { tilt = -90, from = -80, to = 80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.42, "smooth", 178, 0, 6, 30, 0, 0, -12, 14),
				key(0.58, "in", 60, 0, 0, 0, 22, 0, 14, -24),
				key(0.76, "smooth", 58, 0, 0, 0, 22, 0, 14, -26),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	katana = {
		{ -- быстрый косой сверху
			durMul = 0.85,
			arc = { tilt = 36, from = 80, to = -80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.26, "smooth", 150, 0, 38, 36, 0, 0, -28, 6),
				key(0.46, "in", 54, 0, -28, 0, 8, 0, 32, -12),
				key(0.70, "out", 40, 0, -36, 8, 6, 0, 38, -14),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
		{ -- горизонтальный размах
			durMul = 0.85,
			arc = { tilt = 0, from = 80, to = -80 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.26, "smooth", 96, 0, 76, 26, 0, 0, -38, 0),
				key(0.46, "in", 90, 0, -52, 0, 0, 0, 40, -4),
				key(0.70, "out", 88, 0, -64, 6, 0, 0, 46, -4),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	scythe = {
		{ -- широкий низкий взмах справа налево
			durMul = 1.1,
			arc = { tilt = -14, from = 85, to = -85 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.38, "smooth", 70, 0, 88, 22, 0, 0, -44, -6),
				key(0.58, "in", 76, 0, -56, 0, 0, 0, 46, -10),
				key(0.80, "out", 74, 0, -70, 6, 0, 0, 54, -10),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
	staff = {
		{ -- посох поднимается и опускается вперёд, как при заклинании
			durMul = 1.1,
			arc = { tilt = -90, from = -60, to = 60 },
			keys = {
				key(0.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
				key(0.38, "smooth", 152, 0, 6, 28, 0, 0, -10, 8),
				key(0.58, "in", 84, 0, 0, 4, 10, 0, 14, -14),
				key(0.78, "out", 80, 0, 0, 4, 10, 0, 16, -16),
				key(1.00, "smooth", 90, 0, 0, 0, 0, 0, 0, 0),
			},
		},
	},
}

local function ease(kind: string, u: number): number
	if kind == "in" then
		return u * u * u
	elseif kind == "out" then
		return 1 - (1 - u) ^ 2
	end
	return u * u * (3 - 2 * u)
end

-- Поза (8 чисел) в момент alpha 0..1 одной анимации
local function sample(variant: Variant, alpha: number): { number }
	local keys = variant.keys
	local a = math.clamp(alpha, 0, 1)
	for i = 2, #keys do
		local k1 = keys[i]
		if a <= k1.t then
			local k0 = keys[i - 1]
			local span = k1.t - k0.t
			local u = if span > 0 then (a - k0.t) / span else 1
			local e = ease(k1.ease, u)
			local out = table.create(8, 0)
			for j = 1, 8 do
				out[j] = k0.p[j] + (k1.p[j] - k0.p[j]) * e
			end
			return out
		end
	end
	return keys[#keys].p
end

local function toCFrames(p: { number }): (CFrame, CFrame, CFrame, CFrame)
	local r = math.rad
	return CFrame.Angles(r(p[1]), r(p[2]), r(p[3])),
		CFrame.Angles(r(p[4]), 0, 0),
		CFrame.Angles(r(p[5]), r(p[6]), 0),
		CFrame.Angles(r(p[8]), r(p[7]), 0)
end

-- Для предпросмотра и тестов: суставы в позе kind/variant в момент alpha.
function SwingAnim.sample(
	kind: string,
	variantIndex: number,
	alpha: number
): (CFrame, CFrame, CFrame, CFrame)
	local list = styles[kind] or styles.sword
	return toCFrames(sample(list[variantIndex] or list[1], alpha))
end

function SwingAnim.variantCount(kind: string): number
	local list = styles[kind] or styles.sword
	return #list
end

-- Суставы R15 правой руки и корпуса (nil у R6, там анимация остаётся стандартной).
-- В новых персонажах это AnimationConstraint, в старых Motor6D; у обоих есть Transform.
type Joint = Motor6D | AnimationConstraint
type Rig = { shoulder: Joint, elbow: Joint, wrist: Joint, waist: Joint }

local rigs: { [Model]: Rig? } = setmetatable({}, { __mode = "k" }) :: any

local function findRig(character: Model): Rig?
	local cached = rigs[character]
	if cached and cached.shoulder.Parent then
		return cached
	end
	local function motor(partName: string, name: string): Joint?
		local part = character:FindFirstChild(partName)
		local m = part and part:FindFirstChild(name)
		return if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then m else nil
	end
	local shoulder = motor("RightUpperArm", "RightShoulder")
	local elbow = motor("RightLowerArm", "RightElbow")
	local wrist = motor("RightHand", "RightWrist")
	local waist = motor("UpperTorso", "Waist")
	if not (shoulder and elbow and wrist and waist) then
		return nil
	end
	local rig: Rig = { shoulder = shoulder, elbow = elbow, wrist = wrist, waist = waist }
	rigs[character] = rig
	return rig
end

type Active = { variant: Variant, rig: Rig, t0: number, dur: number }
local active: Active? = nil
local combo: { [string]: number } = {}

-- Запускает удар оружием weapon (поля kind и cooldown), возвращает данные дуги для эффектов.
function SwingAnim.play(weapon: { kind: string, cooldown: number }): Arc?
	local list = styles[weapon.kind] or styles.sword
	local n = (combo[weapon.kind] or 0) % #list + 1
	combo[weapon.kind] = n
	local variant = list[n]
	local character = Players.LocalPlayer.Character
	local rig = character and findRig(character)
	if rig then
		active = {
			variant = variant,
			rig = rig,
			t0 = os.clock(),
			dur = math.clamp(weapon.cooldown * variant.durMul, 0.28, 0.9),
		}
	end
	return variant.arc
end

function SwingAnim.start()
	RunService.PreSimulation:Connect(function()
		local a = active
		if not a then
			return
		end
		local character = Players.LocalPlayer.Character
		local alpha = (os.clock() - a.t0) / a.dur
		if alpha >= 1 or not character or not a.rig.shoulder:IsDescendantOf(character) then
			active = nil
			return
		end
		if not character:FindFirstChildOfClass("Tool") then
			active = nil
			return
		end
		-- PreSimulation идёт после обновления анимаций персонажа, поэтому читаем готовую позу и
		-- плавно входим в нашу анимацию и выходим из неё
		local fadeIn = math.clamp(alpha / 0.18, 0, 1)
		local fadeOut = math.clamp((1 - alpha) / 0.16, 0, 1)
		local w = ease("smooth", math.min(fadeIn, fadeOut))
		local shoulder, elbow, wrist, waist = toCFrames(sample(a.variant, alpha))
		local rig = a.rig
		rig.shoulder.Transform = rig.shoulder.Transform:Lerp(shoulder, w)
		rig.elbow.Transform = rig.elbow.Transform:Lerp(elbow, w)
		rig.wrist.Transform = rig.wrist.Transform:Lerp(wrist, w)
		rig.waist.Transform = rig.waist.Transform:Lerp(waist, w)
	end)
end

return SwingAnim
