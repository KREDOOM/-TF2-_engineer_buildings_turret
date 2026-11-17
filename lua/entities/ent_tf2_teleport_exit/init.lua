AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/buildables/teleporter.mdl")
	self:SetupSharedPhysics()

	self.Level = 1
	self.UpgradeMetal = 0
	self.IsTF2Building = true
	self:SetRenderMode(RENDERMODE_NORMAL)
	self:SetColor(Color(255, 255, 255, 255))
	self:SetNWInt("TF2_Level", 1)
	self:SetNWInt("TF2_UpgradeMetal", 0)

	self:SetMaxHealth(150)
	self:SetHealth(150)

	self.BuildingTeam = self.BuildingTeam or (TF2_ENG and TF2_ENG.TEAM_RED or 0)
	self:SetSkin(self.BuildingTeam)

	timer.Simple(0, function()
		if IsValid(self) then
			local owner = self:GetBuildingOwner()
			if IsValid(owner) then
				self:SetNWEntity("BuildingOwner", owner)
			end
		end
	end)

	self:EmitSound("weapons/sentry_finish.wav", 75, 100)
end

function ENT:GetBuildingOwner()
	return self.BuildingOwner or self:GetCreator() or self:GetNWEntity("BuildingOwner")
end

function ENT:SetBuildingSkin(skinId)
	self.BuildingTeam = skinId
	self:SetSkin(skinId)
end

function ENT:FindEnterTeleport()
	local owner = self:GetBuildingOwner()
	if IsValid(owner) and owner.TF2_GetBuilding and TF2_ENG then
		local bEnt = owner:TF2_GetBuilding(TF2_ENG.BUILDING_TELE_ENTER)
		if IsValid(bEnt) then return bEnt end
	end

	for _, ent in ipairs(ents.FindByClass("ent_tf2_teleport_enter")) do
		if IsValid(ent) and (ent:GetBuildingOwner() == owner or ent.BuildingOwner == owner) then
			return ent
		end
	end

	return nil
end

function ENT:ResetBuildingLevel()
	self.Level = 1
	self.UpgradeMetal = 0
	self:SetNWInt("TF2_Level", 1)
	self:SetNWInt("TF2_UpgradeMetal", 0)
	
	self:SetMaxHealth(150)
	self:SetHealth(math.min(self:Health(), 150))
end

function ENT:AddUpgradeProgress(amount, ply)
	if not IsValid(self:FindEnterTeleport()) then 
		if IsValid(ply) then ply:ChatPrint("[TF2 Teleporter] Нельзя улучшить выход без установленного входа!") end
		return 
	end

	if self.Level >= 3 then return end

	self.UpgradeMetal = (self.UpgradeMetal or 0) + amount
	self:SetNWInt("TF2_UpgradeMetal", self.UpgradeMetal)

	self:EmitSound("weapons/sentry_upgrading" .. math.random(1, 8) .. ".wav", 75, 100)

	local ef = EffectData()
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 15))
	util.Effect("Sparks", ef)

	if self.UpgradeMetal >= 200 then
		self:UpgradeBuilding(ply)
	end
end

function ENT:UpgradeBuilding(ply)
	if self.Level >= 3 then return end

	local enterEnt = self:FindEnterTeleport()
	if not IsValid(enterEnt) then return end

	local targetLevel = math.min(self.Level + 1, 3)

	self.Level = targetLevel
	self.UpgradeMetal = 0
	self:SetNWInt("TF2_Level", targetLevel)
	self:SetNWInt("TF2_UpgradeMetal", 0)

	local maxHp = targetLevel == 2 and 180 or 216
	self:SetMaxHealth(maxHp)
	self:SetHealth(maxHp)

	self:EmitSound("weapons/sentry_finish.wav", 85, 100)

	local ef = EffectData()
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 15))
	ef:SetScale(2)
	util.Effect("cball_explode", ef)

	if IsValid(enterEnt) and enterEnt.Level ~= targetLevel then
		enterEnt.Level = targetLevel
		enterEnt.UpgradeMetal = 0
		enterEnt:SetNWInt("TF2_Level", targetLevel)
		enterEnt:SetNWInt("TF2_UpgradeMetal", 0)
		enterEnt:SetMaxHealth(maxHp)
		enterEnt:SetHealth(maxHp)
		
		local efEnter = EffectData()
		efEnter:SetOrigin(enterEnt:GetPos() + Vector(0, 0, 15))
		efEnter:SetScale(2)
		util.Effect("cball_explode", efEnter)
	end

	if IsValid(ply) then
		ply:ChatPrint("[TF2 Teleporter] Телепорты улучшены до УРОВНЯ " .. targetLevel .. "!")
	end
end

function ENT:Think()
	if not self:IsValid() then return end

	if self:GetColor().a < 255 then
		self:SetColor(Color(255, 255, 255, 255))
		self:SetRenderMode(RENDERMODE_NORMAL)
	end

	local enterEnt = self:FindEnterTeleport()
	if not IsValid(enterEnt) then
		if self.Level ~= 1 then
			self:ResetBuildingLevel()
		end
		self:SetBodygroup(1, 0)
	else
		self:SetBodygroup(1, 1)
	end

	self:NextThink(CurTime() + 0.2)
	return true
end

function ENT:OnTakeDamage(dmg)
	local hp = self:Health() - dmg:GetDamage()
	self:SetHealth(hp)

	if hp <= 0 then
		self:Explode()
	end
end

function ENT:Explode()
	local enterEnt = self:FindEnterTeleport()
	if IsValid(enterEnt) then
		enterEnt:ResetBuildingLevel()
		local owner = enterEnt:GetBuildingOwner()
		if IsValid(owner) then
			owner:ChatPrint("[TF2 Teleporter] Связь разорвана! Входной телепорт сброшен до 1 уровня.")
		end
	end

	local pos = self:GetPos()
	local ef = EffectData()
	ef:SetOrigin(pos)
	util.Effect("Explosion", ef)

	self:EmitSound("weapons/teleporter_explode.wav", 85, 100)

	local owner = self:GetBuildingOwner()
	if IsValid(owner) and TF2_ENG then
		owner:SetNWEntity("TF2_Building_" .. TF2_ENG.BUILDING_TELE_EXIT, NULL)
		owner:ChatPrint("[TF2 Teleporter] Выходной телепорт был уничтожен!")
	end

	SafeRemoveEntity(self)
end
