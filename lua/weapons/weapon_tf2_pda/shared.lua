SWEP.PrintName = "КПК Инженера (Build PDA)"
SWEP.Author = "TF2 Engineer"
SWEP.Instructions = "ЛКМ: Меню строительства | ПКМ: Меню сноса | R: Смена команды (RED / BLU)"
SWEP.Category = "Team Fortress 2"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

-- Оригинальные модели КПК Инженера TF2
SWEP.ViewModel = "models/weapons/v_models/v_pda_engineer.mdl"
SWEP.WorldModel = "models/weapons/w_models/w_pda_engineer.mdl"
SWEP.UseHands = false

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/entities/weapon_tf2_pda")
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
	local PDA_WORLD_MODEL = "models/weapons/w_models/w_pda_engineer.mdl"
	local PDA_BONES = {
		"right hand", -- кость, заданная для модели персонажа
		"ValveBiped.Bip01_R_Hand", -- запасной вариант для стандартных playermodel'ов GMod
		"bip_hand_R",
		"Bip01_R_Hand",
	}
	local PDA_OFFSET = Vector(4, 4.5, 0)
	local PDA_ANGLE = Angle(0, 180, 180)
	local PDA_SCALE = 0.75

	function SWEP:GetTF2WrenchWorldModel()
		if IsValid(self.TF2WrenchWorldModel) then
			return self.TF2WrenchWorldModel
		end

		local mdl = ClientsideModel(PDA_WORLD_MODEL, RENDERGROUP_OPAQUE)
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
		for _, boneName in ipairs(PDA_BONES) do
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
			+ drawAng:Forward() * PDA_OFFSET.x
			+ drawAng:Right() * PDA_OFFSET.y
			+ drawAng:Up() * PDA_OFFSET.z

		-- Поворот: -12, 0, 180 относительно осей кости.
		drawAng:RotateAroundAxis(drawAng:Up(), PDA_ANGLE.y)
		drawAng:RotateAroundAxis(drawAng:Right(), PDA_ANGLE.p)
		drawAng:RotateAroundAxis(drawAng:Forward(), PDA_ANGLE.r)

		mdl:SetPos(drawPos)
		mdl:SetAngles(drawAng)

		local matrix = Matrix()
		matrix:Scale(Vector(PDA_SCALE, PDA_SCALE, PDA_SCALE))
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
	self:SetHoldType("slam")
end

function SWEP:Deploy()
	self:EmitSound("weapons/draw_pda_engineer.wav", 65, 100)
	self:SendWeaponAnim(ACT_VM_DRAW)
	if CLIENT and IsFirstTimePredicted() then
		TF2_ENG.OpenPDAMenu(false)
	end
	return true
end

function SWEP:PrimaryAttack()
	if CLIENT and IsFirstTimePredicted() then
		TF2_ENG.OpenPDAMenu(false)
	end
	self:SetNextPrimaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
	if CLIENT and IsFirstTimePredicted() then
		TF2_ENG.OpenPDAMenu(true)
	end
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
	if CLIENT and IsFirstTimePredicted() then
		local lp = LocalPlayer()
		local mySkin = lp:TF2_GetTeamSkin()
		local nextSkin = mySkin == TF2_ENG.TEAM_RED and TF2_ENG.TEAM_BLU or TF2_ENG.TEAM_RED
		net.Start("TF2_SwitchTeamSkin")
		net.WriteUInt(nextSkin, 2)
		net.SendToServer()
	end
end
