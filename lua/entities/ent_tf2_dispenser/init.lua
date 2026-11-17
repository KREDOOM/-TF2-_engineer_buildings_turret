AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:SetupDispenserPhysics()
	-- Создаём твёрдую физическую коробку по реальным габаритам раздатчика
	self:PhysicsInitBox(Vector(-20, -20, 0), Vector(20, 20, 62))
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:EnableCustomCollisions(true)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(300)
		phys:Wake()
		phys:EnableMotion(false)
	end
end

function ENT:Initialize()
	self:SetModel("models/buildables/dispenser.mdl")
	self:SetupDispenserPhysics()

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

	self.NextHealTick = 0

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

function ENT:AddUpgradeProgress(amount, ply)
	if self.Level >= 3 then return end

	self.UpgradeMetal = (self.UpgradeMetal or 0) + amount
	self:SetNWInt("TF2_UpgradeMetal", self.UpgradeMetal)

	self:EmitSound("weapons/sentry_upgrading" .. math.random(1, 8) .. ".wav", 75, 100)

	local ef = EffectData()
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 25))
	util.Effect("Sparks", ef)

	if self.UpgradeMetal >= 200 then
		self:UpgradeBuilding(ply)
	end
end

function ENT:UpgradeBuilding(ply)
	if self.Level >= 3 then return end

	self.Level = self.Level + 1
	self.UpgradeMetal = 0
	self:SetNWInt("TF2_Level", self.Level)
	self:SetNWInt("TF2_UpgradeMetal", 0)

	local newModel = (self.Level == 2) and "models/buildables/dispenser_lvl2.mdl" or "models/buildables/dispenser_lvl3.mdl"
	self:SetModel(newModel)
	self:SetSkin(self.BuildingTeam)

	local maxHp = (self.Level == 2) and 180 or 216
	self:SetMaxHealth(maxHp)
	self:SetHealth(maxHp)

	self:EmitSound("weapons/sentry_finish.wav", 85, 100)

	local ef = EffectData()
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 25))
	ef:SetScale(2)
	util.Effect("cball_explode", ef)

	if IsValid(ply) then
		ply:ChatPrint("[TF2 Dispenser] Раздатчик улучшен до УРОВНЯ " .. self.Level .. "!")
	end
end

function ENT:HasLineOfSight(ply)
	if not IsValid(ply) then return false end
	local myPos = self:GetPos() + Vector(0, 0, 36)
	local tr = util.TraceLine({
		start = myPos,
		endpos = ply:WorldSpaceCenter(),
		filter = { self, ply },
		mask = MASK_SOLID
	})
	return not tr.Hit
end

function ENT:Think()
	if not self:IsValid() then return end

	if self:GetColor().a < 255 then
		self:SetColor(Color(255, 255, 255, 255))
		self:SetRenderMode(RENDERMODE_NORMAL)
	end

	local curTime = CurTime()
	local myPos = self:GetPos() + Vector(0, 0, 32)

	-- Скорость восстановления в зависимости от уровня (1 / 2 / 3)
	local hpRate = (self.Level == 1 and 10) or (self.Level == 2 and 15) or 20
	local armRate = (self.Level == 1 and 5) or (self.Level == 2 and 10) or 15
	local metalRate = (self.Level == 1 and 40) or (self.Level == 2 and 50) or 60

	if curTime >= self.NextHealTick then
		local players = ents.FindInSphere(myPos, 260)

		for _, ply in ipairs(players) do
			if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
				if not self:HasLineOfSight(ply) then continue end

				local curHp = ply:Health()
				local maxHp = ply:GetMaxHealth()
				if curHp < maxHp then
					ply:SetHealth(math.min(maxHp, curHp + hpRate))
				end

				local curArmor = ply:Armor()
				if curArmor < 100 then
					ply:SetArmor(math.min(100, curArmor + armRate))
				end

				if ply.TF2_GetMetal and ply:TF2_GetMetal() < 200 then
					ply:TF2_AddMetal(metalRate)
				end
			end
		end

		self.NextHealTick = curTime + 1.0
	end

	self:NextThink(curTime + 0.1)
	return true
end

function ENT:OnTakeDamage(dmg)
	local hp = self:Health() - dmg:GetDamage()
	self:SetHealth(hp)
	self:EmitSound("weapons/sentry_damage" .. math.random(1, 4) .. ".wav", 75, 100)

	if hp <= 0 then
		self:Explode()
	end
end

function ENT:Explode()
	local pos = self:GetPos()
	local ef = EffectData()
	ef:SetOrigin(pos)
	util.Effect("Explosion", ef)

	self:EmitSound("weapons/dispenser_explode.wav", 85, 100)

	local owner = self:GetBuildingOwner()
	if IsValid(owner) and TF2_ENG then
		owner:SetNWEntity("TF2_Building_" .. TF2_ENG.BUILDING_DISPENSER, NULL)
		owner:ChatPrint("[TF2 Dispenser] Ваш раздатчик был уничтожен!")
	end

	SafeRemoveEntity(self)
end
