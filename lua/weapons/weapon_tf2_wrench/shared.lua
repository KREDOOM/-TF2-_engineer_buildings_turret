SWEP.PrintName = "Гаечный ключ (Wrench)"
SWEP.Author = "TF2 Engineer"
SWEP.Instructions = "ЛКМ: Удар / Починка и Прокачка построек | ПКМ: Меню КПК"
SWEP.Category = "Team Fortress 2"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
--SWEP.AutoSwitchTo = false
--SWEP.AutoSwitchFrom = false

SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

-- Оригинальные модели Гаечного ключа Инженера TF2
SWEP.ViewModel = "models/weapons/v_models/v_wrench_engineer.mdl" 
SWEP.WorldModel = "models/weapons/w_models/w_wrench.mdl"
SWEP.UseHands = false

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/weapon_tf2_wrench")
	SWEP.DrawWeaponInfoBox = true
	SWEP.BounceWeaponIcon = false

	-- Ручная отрисовка квадратной иконки 512x512 без сплющивания
	function SWEP:DrawWeaponSelection(x, y, wide, tall, alpha)
		surface.SetDrawColor(255, 255, 255, alpha)
		surface.SetTexture(self.WepSelectIcon)

		-- Вычисляем квадратный размер по высоте слота, чтобы сохранить пропорции 1:1
		local iconSize = tall * 0.9
		local iconX = x + (wide - iconSize) * 0.5
		local iconY = y + (tall - iconSize) * 0.5

		surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)

		-- Отрисовка стандартного окна с подсказкой SWEP.Instructions при выборе оружия
		self:PrintWeaponInfo(x + wide + 20, y + tall * 0.95, alpha)
	end

	surface.CreateFont("MedigunHUDSmall", {
		font = "Trebuchet MS",
		size = 16,
		weight = 500,
		antialias = true
	})

	surface.CreateFont("MedigunHUDMedium", {
		font = "Trebuchet MS",
		size = 20,
		weight = 600,
		antialias = true
	})

	surface.CreateFont("MedigunHUDLarge", {
		font = "Trebuchet MS",
		size = 24,
		weight = 800,
		antialias = true
	})
end

if CLIENT then
	local WRENCH_WORLD_MODEL = "models/weapons/w_models/w_wrench.mdl"
	local WRENCH_BONES = {
		"right hand", -- кость, заданная для модели персонажа
		"ValveBiped.Bip01_R_Hand", -- запасной вариант для стандартных playermodel'ов GMod
		"bip_hand_R",
		"Bip01_R_Hand",
	}
	local WRENCH_OFFSET = Vector(3, 2.5, 0.8)
	local WRENCH_ANGLE = Angle(12, 0, 180)
	local WRENCH_SCALE = 0.75

	function SWEP:GetTF2WrenchWorldModel()
		if IsValid(self.TF2WrenchWorldModel) then
			return self.TF2WrenchWorldModel
		end

		local mdl = ClientsideModel(WRENCH_WORLD_MODEL, RENDERGROUP_OPAQUE)
		if not IsValid(mdl) then return nil end

		mdl:SetNoDraw(true)
		self.TF2WrenchWorldModel = mdl
		return mdl
	end

	function SWEP:DrawWorldModel()
		local owner = self:GetOwner()

		-- Не рисуем отдельную world-модель у локального игрока в первом лице.
		if owner == LocalPlayer() and not owner:ShouldDrawLocalPlayer() then return end

		-- Если ключ лежит на карте, используем обычную отрисовку оружия.
		if not IsValid(owner) or not owner:IsPlayer() then
			self:DrawModel()
			return
		end

		local bone
		for _, boneName in ipairs(WRENCH_BONES) do
			bone = owner:LookupBone(boneName)
			if bone then break end
		end

		if not bone then
			self:DrawModel()
			return
		end

		local bonePos, boneAng = owner:GetBonePosition(bone)
		if not bonePos or not boneAng then
			self:DrawModel()
			return
		end

		local mdl = self:GetTF2WrenchWorldModel()
		if not IsValid(mdl) then return end

		-- Позиция: 3, -2.5, 0.8 относительно right hand.
		local drawPos = bonePos
		local drawAng = Angle(boneAng.p, boneAng.y, boneAng.r)
		drawPos = drawPos
			+ drawAng:Forward() * WRENCH_OFFSET.x
			+ drawAng:Right() * WRENCH_OFFSET.y
			+ drawAng:Up() * WRENCH_OFFSET.z

		-- Поворот: -12, 0, 180 относительно осей кости.
		drawAng:RotateAroundAxis(drawAng:Up(), WRENCH_ANGLE.y)
		drawAng:RotateAroundAxis(drawAng:Right(), WRENCH_ANGLE.p)
		drawAng:RotateAroundAxis(drawAng:Forward(), WRENCH_ANGLE.r)

		mdl:SetPos(drawPos)
		mdl:SetAngles(drawAng)

		local matrix = Matrix()
		matrix:Scale(Vector(WRENCH_SCALE, WRENCH_SCALE, WRENCH_SCALE))
		mdl:EnableMatrix("RenderMultiply", matrix)
		mdl:SetupBones()
		mdl:DrawModel()
	end

	function SWEP:OnRemove()
		if IsValid(self.TF2WrenchWorldModel) then
			self.TF2WrenchWorldModel:Remove()
		end
	end
end

function SWEP:Initialize()
	self:SetHoldType("melee")
end

function SWEP:Deploy()
	self:EmitSound("weapons/draw_wrench_engineer.wav", 65, 100, 1, CHAN_WEAPON, 0, 0)
	self:SendWeaponAnim(ACT_VM_DRAW)
	
	-- Устанавливаем время, когда закончится анимация доставания и можно будет включить IDLE
	self:SetNextIdle(CurTime() + self:SequenceDuration())
	return true
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	self:SetNextPrimaryFire(CurTime() + 0.6)
	ply:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_HITCENTER)

	self:EmitSound("weapons/wrench_swing.wav", 65, 100)

	-- Задаем задержку перед возвратом в IDLE после удара
	self:SetNextIdle(CurTime() + self:SequenceDuration())

	local tr = util.TraceHull({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 115,
		filter = ply,
		mins = Vector(-12, -12, -12),
		maxs = Vector(12, 12, 12),
		mask = MASK_SHOT_HULL
	})

	if not tr.Hit then return end
	local target = tr.Entity

	if SERVER and IsValid(target) then
		if target.BuildingType or string.find(target:GetClass(), "ent_tf2_") then
			local curHp = target:Health()
			local maxHp = target:GetMaxHealth()
			local curMetal = ply:TF2_GetMetal()

			-- 1. Ремонт (если здоровье постройки ниже максимума)
			if curHp < maxHp then
				if curMetal >= 15 then
					ply:TF2_SetMetal(curMetal - 15)
					target:SetHealth(math.min(maxHp, curHp + 35))
					target:EmitSound("weapons/wrench_hit_build_success" .. math.random(1, 2) .. ".wav", 75, 100)

					local ef = EffectData()
					ef:SetOrigin(tr.HitPos)
					ef:SetNormal(tr.HitNormal)
					util.Effect("Sparks", ef)
					ply:ChatPrint("[TF2 Wrench] Постройка отремонтирована (+35 HP). Металл: " .. ply:TF2_GetMetal())
				else
					ply:ChatPrint("[TF2 Wrench] Недостаточно металла для ремонта!")
					target:EmitSound("weapons/wrench_hit_build_fail.wav", 75, 100)
				end
				return
			end

			-- 2. Прокачка (если уровень меньше 3 и здоровье полное)
			if target.Level and target.Level < 3 and target.AddUpgradeProgress then
				if curMetal >= 25 then
					ply:TF2_SetMetal(curMetal - 25)
					target:AddUpgradeProgress(25, ply)
					target:EmitSound("weapons/wrench_hit_build_success" .. math.random(1, 2) .. ".wav", 75, 100)
					ply:ChatPrint("[TF2 Wrench] Прокачка постройки: " .. (target.UpgradeMetal or 0) .. " / 200 металла. Ваш металл: " .. ply:TF2_GetMetal())
				else
					ply:ChatPrint("[TF2 Wrench] Недостаточно металла для прокачки (нужно 25)! Ваш металл: " .. curMetal)
					target:EmitSound("weapons/wrench_hit_build_fail.wav", 75, 100)
				end
				return
			end

			-- === ИСПРАВЛЕНО: Постройка полностью улучшена (3 ур.) и имеет 100% здоровья ===
			target:EmitSound("weapons/wrench_hit_build_fail.wav", 75, 100)
			ply:ChatPrint("[TF2 Wrench] Постройка полностью улучшена и не нуждается в ремонте!")
			return
		end

		if target:IsPlayer() or target:IsNPC() or string.find(target:GetClass(), "ragdoll") then
			local dmg = DamageInfo()
			dmg:SetDamage(65)
			dmg:SetAttacker(ply)
			dmg:SetInflictor(self)
			dmg:SetDamageType(DMG_CLUB)
			dmg:SetDamagePosition(tr.HitPos)
			target:TakeDamageInfo(dmg)

			target:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 6) .. ".wav", 75, 100)
			return
		end
	end

	if SERVER then
		self:EmitSound("weapons/wrench_hit_world.wav", 70, 100)
	end
end

function SWEP:SecondaryAttack()
	if CLIENT and IsFirstTimePredicted() then
		if TF2_ENG and TF2_ENG.OpenPDAMenu then
			TF2_ENG.OpenPDAMenu(false)
		end
	end
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

-- === НАЧАЛО ЛОГИКИ КОНТРОЛЯ И ЦИКЛА IDLE ===
function SWEP:SetNextIdle(nextIdleTime)
	self:SetNWFloat("NextIdleTime", nextIdleTime)
end

function SWEP:GetNextIdle()
	return self:GetNWFloat("NextIdleTime", 0)
end

function SWEP:Think()
	if self:GetNextIdle() ~= 0 and CurTime() >= self:GetNextIdle() then
		self:SendWeaponAnim(ACT_VM_IDLE)
		self:SetNextIdle(CurTime() + self:SequenceDuration())
	end
end
-- === КОНЕЦ ЛОГИКИ ЦИКЛА IDLE ===