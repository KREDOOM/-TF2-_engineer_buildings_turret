AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

game.AddParticles("particles/building_teleporter.pcf")
for _, team in ipairs({"red", "blue"}) do
	PrecacheParticleSystem("teleported_" .. team)
	PrecacheParticleSystem("player_sparkles_" .. team)
	PrecacheParticleSystem("teleporter_arms_circle_" .. team .. "_blink")
end

function ENT:Initialize()
	self:SetModel("models/buildables/teleporter.mdl")
	self:SetupSharedPhysics()

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(250)
		phys:Wake()
		phys:EnableMotion(false)
	end

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

	self.NextTeleportTime = 0
	self.HadExitBefore = false

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
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 15))
	util.Effect("Sparks", ef)

	if self.UpgradeMetal >= 200 then
		self:UpgradeBuilding(ply)
	end
end

function ENT:ResetBuildingLevel()
	self.Level = 1
	self.UpgradeMetal = 0
	self:SetNWInt("TF2_Level", 1)
	self:SetNWInt("TF2_UpgradeMetal", 0)
	
	self:SetMaxHealth(150)
	self:SetHealth(math.min(self:Health(), 150))
end

function ENT:UpgradeBuilding(ply)
	if self.Level >= 3 then return end

	local exitEnt = self:FindExitTeleport()
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

	if IsValid(exitEnt) and exitEnt.Level ~= targetLevel then
		exitEnt.Level = targetLevel
		exitEnt.UpgradeMetal = 0
		exitEnt:SetNWInt("TF2_Level", targetLevel)
		exitEnt:SetNWInt("TF2_UpgradeMetal", 0)
		exitEnt:SetMaxHealth(maxHp)
		exitEnt:SetHealth(maxHp)
		
		local efExit = EffectData()
		efExit:SetOrigin(exitEnt:GetPos() + Vector(0, 0, 15))
		efExit:SetScale(2)
		util.Effect("cball_explode", efExit)
	end

	if IsValid(ply) then
		ply:ChatPrint("[TF2 Teleporter] Телепорты улучшены до УРОВНЯ " .. targetLevel .. "!")
	end
end

function ENT:FindExitTeleport()
	local owner = self:GetBuildingOwner()
	if IsValid(owner) and owner.TF2_GetBuilding and TF2_ENG then
		local bEnt = owner:TF2_GetBuilding(TF2_ENG.BUILDING_TELE_EXIT)
		if IsValid(bEnt) then return bEnt end
	end

	for _, ent in ipairs(ents.FindByClass("ent_tf2_teleport_exit")) do
		if IsValid(ent) and (ent:GetBuildingOwner() == owner or ent.BuildingOwner == owner) then
			return ent
		end
	end

	return nil
end

function ENT:Think()
	if not self:IsValid() then return end

	if self:GetColor().a < 255 then
		self:SetColor(Color(255, 255, 255, 255))
		self:SetRenderMode(RENDERMODE_NORMAL)
	end

	local curTime = CurTime()
	local myPos = self:GetPos()

	-- Официальное время перезарядки TF2: 10 сек (1 ур.), 5 сек (2 ур.), 3 сек (3 ур.)
	local rechargeTime = (self.Level == 1 and 10.0) or (self.Level == 2 and 5.0) or 3.0

	local exitEnt = self:FindExitTeleport()
	if IsValid(exitEnt) then
		-- Синхронизация уровней при наличии пары
		local maxLevel = math.max(self.Level, exitEnt.Level)
		if self.Level ~= maxLevel then
			self.Level = maxLevel
			self:SetNWInt("TF2_Level", maxLevel)
		elseif exitEnt.Level ~= maxLevel then
			exitEnt.Level = maxLevel
			exitEnt:SetNWInt("TF2_Level", maxLevel)
		end

		-- Начальный таймер зарядки при появлении выходного телепорта
		if not self.HadExitBefore then
			self.NextTeleportTime = curTime + rechargeTime
			self.HadExitBefore = true
		end
		self:SetBodygroup(1, 1)
	else
		self.HadExitBefore = false
		self:SetBodygroup(1, 0)
	end

	local isReady = (curTime >= self.NextTeleportTime)
	self:SetNWBool("TF2_TeleReady", isReady and IsValid(exitEnt))

	if isReady and IsValid(exitEnt) then
		local players = ents.FindInBox(myPos + Vector(-24, -24, 0), myPos + Vector(24, 24, 60))
		for _, ply in ipairs(players) do
			if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
				self:TeleportPlayer(ply, exitEnt)
				self.NextTeleportTime = curTime + rechargeTime
				self:SetNWBool("TF2_TeleReady", false)
				break
			end
		end
	end

	self:NextThink(curTime + 0.1)
	return true
end

function ENT:TeleportPlayer(ply, exitEnt)
	if not IsValid(ply) or not IsValid(exitEnt) then return end

	local isBlue = (self:GetSkin() == 1)
	local teleportEffect = isBlue and "teleported_blue" or "teleported_red"
	local flashEffect = isBlue and "teleporter_arms_circle_blue_blink" or "teleporter_arms_circle_red_blink"

	local startPos = self:GetPos() + Vector(0, 0, 5)
	local exitPos = exitEnt:GetPos() + Vector(0, 0, 13)

	ParticleEffect(teleportEffect, startPos, self:GetAngles(), self)
	ParticleEffect(flashEffect, startPos, self:GetAngles(), self)
	self:EmitSound("weapons/teleporter_send.wav", 80, 100)

	ply:SetPos(exitPos)
	ply:SetVelocity(Vector(0, 0, 0))
	ply:SetLocalVelocity(Vector(0, 0, 0))
	ply:DropToFloor()

	ParticleEffect(teleportEffect, exitEnt:GetPos() + Vector(0, 0, 5), exitEnt:GetAngles(), exitEnt)
	ParticleEffectAttach(isBlue and "player_sparkles_blue" or "player_sparkles_red", PATTACH_ABSORIGIN_FOLLOW, ply, 0)
	exitEnt:EmitSound("weapons/teleporter_receive.wav", 80, 100)

	ply:ScreenFade(SCREENFADE.IN, Color(245, 195, 65, 140), 0.2, 0.4)
end

function ENT:OnTakeDamage(dmg)
	local hp = self:Health() - dmg:GetDamage()
	self:SetHealth(hp)

	if hp <= 0 then
		self:Explode()
	end
end

function ENT:Explode()
	local exitEnt = self:FindExitTeleport()
	if IsValid(exitEnt) then
		exitEnt:ResetBuildingLevel()
		local owner = exitEnt:GetBuildingOwner()
		if IsValid(owner) then
			owner:ChatPrint("[TF2 Teleporter] Связь разорвана! Выходной телепорт сброшен до 1 уровня.")
		end
	end

	local pos = self:GetPos()
	local ef = EffectData()
	ef:SetOrigin(pos)
	util.Effect("Explosion", ef)

	self:EmitSound("weapons/teleporter_explode.wav", 85, 100)

	local owner = self:GetBuildingOwner()
	if IsValid(owner) and TF2_ENG then
		owner:SetNWEntity("TF2_Building_" .. TF2_ENG.BUILDING_TELE_ENTER, NULL)
		owner:ChatPrint("[TF2 Teleporter] Входной телепорт был уничтожен!")
	end

	SafeRemoveEntity(self)
end
