AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:SetupSentryPhysics()
	self:PhysicsInitBox(Vector(-20, -20, 0), Vector(20, 20, 58))
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:EnableCustomCollisions(true)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(350)
		phys:Wake()
		phys:EnableMotion(false)
	end
end

function ENT:Initialize()
	self:SetModel("models/buildables/sentry1.mdl")
	self:SetupSentryPhysics()

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

	self.CurHeadYaw = self:GetAngles().y
	self.CurHeadPitch = 0
	self.BaseYaw = self:GetAngles().y
	self.ScanDir = 1
	self.ScanOffset = 0

	self.NextFireTime = 0
	self.NextRocketTime = 0
	self.UseRightBarrel = false

	self.Controller = nil
	self.Target = nil
	self.TargetSpottedTime = nil

	self:SetUseType(SIMPLE_USE)

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
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 35))
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

	local newModel = (self.Level == 2) and "models/buildables/sentry2.mdl" or "models/buildables/sentry3.mdl"
	self:SetModel(newModel)
	self:SetSkin(self.BuildingTeam)
	self:SetupSentryPhysics()

	local maxHp = (self.Level == 2) and 180 or 216
	self:SetMaxHealth(maxHp)
	self:SetHealth(maxHp)

	self:EmitSound("weapons/sentry_finish.wav", 85, 100)

	local ef = EffectData()
	ef:SetOrigin(self:GetPos() + Vector(0, 0, 35))
	ef:SetScale(2)
	util.Effect("cball_explode", ef)

	if IsValid(ply) then
		ply:ChatPrint("[TF2 Sentry] Турель улучшена до УРОВНЯ " .. self.Level .. "!")
		if self.Level == 3 then
			ply:ChatPrint("[TF2 Sentry] На 3 уровне доступно ручное управление! Нажмите [E] для входа.")
		end
	end
end

function ENT:Use(activator, caller)
	if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end

	if self.Level < 3 then
		activator:ChatPrint("[TF2 Sentry] Ручное управление доступно только на 3-м уровне.")
		return
	end

	if self.Controller == activator then
		self:ExitControl(activator)
	else
		if IsValid(activator:GetNWEntity("TF2_ControlledSentry")) then
			activator:ChatPrint("[TF2 Sentry] Вы уже управляете другой турелью!")
			return
		end
		self:EnterControl(activator)
	end
end

function ENT:EnterControl(ply)
	self.Controller = ply
	self:SetNWEntity("TF2_Controller", ply)
	ply:SetNWEntity("TF2_ControlledSentry", self)

	ply:DrawViewModel(false)
	ply:DrawWorldModel(false)

	ply:ChatPrint("[TF2 Sentry] РЕЖИМ УПРАВЛЕНИЯ: [ЛКМ] - Пулеметы | [ПКМ] - Залп ракет | [E] - Выход")
end

function ENT:ExitControl(ply)
	if IsValid(ply) then
		ply:SetNWEntity("TF2_ControlledSentry", NULL)
		ply:DrawViewModel(true)
		ply:DrawWorldModel(true)
		ply:ChatPrint("[TF2 Sentry] Вы вышли из управления турелью.")
	end

	if IsValid(self.Controller) and self.Controller ~= ply then
		self.Controller:SetNWEntity("TF2_ControlledSentry", NULL)
		self.Controller:DrawViewModel(true)
		self.Controller:DrawWorldModel(true)
	end

	self.Controller = nil
	self:SetNWEntity("TF2_Controller", NULL)
end

local function IsProtectedFromSentry(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return false end
	if ply:HasGodMode() or ply.bGodMode or ply.GodMode or ply:GetNWBool("GodMode", false) then return true end
	if ply.BuildMode == true or ply.bBuildMode or ply:GetNWBool("BuildMode", false) then return true end
	return false
end

function ENT:FindTarget()
	local myPos = self:GetPos() + Vector(0, 0, 42)
	local myOwner = self:GetBuildingOwner()
	local scanRadius = 1200

	local entsFound = ents.FindInSphere(myPos, scanRadius)
	local bestTarget = nil
	local bestDist = scanRadius * scanRadius + 1

	for _, ent in ipairs(entsFound) do
		if not IsValid(ent) or ent == self or ent == myOwner then continue end

		local isEnemy = false

		if ent:IsPlayer() and ent:Alive() then
			if not IsProtectedFromSentry(ent) then
				if IsValid(myOwner) then
					if ent ~= myOwner then
						local sameSkin = ent.TF2_GetTeamSkin and (ent:TF2_GetTeamSkin() == self.BuildingTeam)
						if ent:Team() ~= myOwner:Team() or not sameSkin or myOwner:Team() == 0 then
							isEnemy = true
						end
					end
				else
					isEnemy = true
				end
			end
		end

		if ent:IsNPC() or ent:IsNextBot() then
			if ent:Health() > 0 then isEnemy = true end
		end

		if isEnemy then
			local tPos = ent.WorldSpaceCenter and ent:WorldSpaceCenter() or (ent:GetPos() + Vector(0, 0, 38))
			local tr = util.TraceLine({
				start = myPos,
				endpos = tPos,
				filter = { self, myOwner },
				mask = MASK_SHOT
			})

			if tr.Entity == ent or tr.Fraction >= 0.85 then
				local d = myPos:DistToSqr(tPos)
				if d < bestDist then
					bestDist = d
					bestTarget = ent
				end
			end
		end
	end

	return bestTarget
end

function ENT:Think()
	if not self:IsValid() then return end

	if self:GetColor().a < 255 then
		self:SetColor(Color(255, 255, 255, 255))
		self:SetRenderMode(RENDERMODE_NORMAL)
	end

	local curTime = CurTime()
	local myPos = self:GetPos() + Vector(0, 0, 42)
	local curBaseYaw = self:GetAngles().y

	-- 1. РЕЖИМ РУЧНОГО УПРАВЛЕНИЯ (Поводырь / Wrangler)
	if IsValid(self.Controller) then
		local ply = self.Controller
		if not ply:Alive() or ply:GetPos():DistToSqr(self:GetPos()) > (250 * 250) then
			self:ExitControl(ply)
		else
			self:SetNWBool("TF2_HasTarget", true)

			local eyeAng = ply:EyeAngles()
			self.CurHeadYaw = math.ApproachAngle(self.CurHeadYaw or curBaseYaw, eyeAng.y, 25)
			self.CurHeadPitch = math.ApproachAngle(self.CurHeadPitch or 0, eyeAng.p, 18)

			local tr = ply:GetEyeTrace()
			local targetPos = tr.HitPos

			if ply:KeyDown(IN_ATTACK) then
				local fireDelay = (self.Level == 1) and 0.135 or 0.09
				if curTime >= self.NextFireTime then
					self:FireBulletAtTarget(targetPos)
					self.NextFireTime = curTime + fireDelay
				end
			end

			if ply:KeyDown(IN_ATTACK2) and self.Level >= 3 then
				if curTime >= self.NextRocketTime then
					self:FireRocketSalvo(targetPos)
					self.NextRocketTime = curTime + 2.25
				end
			end
		end
	-- 2. АВТОМАТИЧЕСКИЙ РЕЖИМ
	else
		if IsValid(self.Target) then
			local tPos = self.Target.WorldSpaceCenter and self.Target:WorldSpaceCenter() or (self.Target:GetPos() + Vector(0, 0, 38))
			local distSqr = myPos:DistToSqr(tPos)

			if distSqr > (1250 * 1250) or (self.Target.Health and self.Target:Health() <= 0) or IsProtectedFromSentry(self.Target) then
				self.Target = nil
				self.TargetSpottedTime = nil
			else
				local tr = util.TraceLine({
					start = myPos,
					endpos = tPos,
					filter = { self, self:GetBuildingOwner() },
					mask = MASK_SHOT
				})
				if tr.Entity ~= self.Target and tr.Fraction < 0.85 then 
					self.Target = nil 
					self.TargetSpottedTime = nil
				end
			end
		end

		if not IsValid(self.Target) then 
			local previousTarget = self.Target
			self.Target = self:FindTarget() 
			
			if IsValid(self.Target) and not IsValid(previousTarget) then
				self.TargetSpottedTime = curTime
				self:EmitSound("weapons/sentry_spot.wav", 80, 100)
				
				local owner = self:GetBuildingOwner()
				if IsValid(owner) and owner:IsPlayer() then
					owner:SendLua([[surface.PlaySound("weapons/sentry_spot_client.wav")]])
				end
			end
		end

		if IsValid(self.Target) then
			self:SetNWBool("TF2_HasTarget", true)
			local targetPos = self.Target.WorldSpaceCenter and self.Target:WorldSpaceCenter() or (self.Target:GetPos() + Vector(0, 0, 38))
			local aimDir = (targetPos - myPos):Angle()

			self.CurHeadYaw = math.ApproachAngle(self.CurHeadYaw or curBaseYaw, aimDir.y, 22)
			self.CurHeadPitch = math.ApproachAngle(self.CurHeadPitch or 0, aimDir.p, 16)

			-- Задержка перед открытием огня после обнаружения
			if self.TargetSpottedTime and (curTime - self.TargetSpottedTime) >= 0.25 then
				local fireDelay = (self.Level == 1) and 0.225 or 0.135
				if curTime >= self.NextFireTime then
					self:FireBulletAtTarget(targetPos)
					self.NextFireTime = curTime + fireDelay
				end

				if self.Level >= 3 and curTime >= self.NextRocketTime then
					self:FireRocketSalvo(targetPos)
					self.NextRocketTime = curTime + 3.05
				end
			end
		else
			self:SetNWBool("TF2_HasTarget", false)
			self.BaseYaw = curBaseYaw

			self.ScanOffset = (self.ScanOffset or 0) + ((self.ScanDir or 1) * 1.6)
			
			if math.abs(self.ScanOffset) > 45 then 
				self.ScanDir = -self.ScanDir 
				local lvlSuffix = (self.Level == 1) and "" or tostring(self.Level)
				self:EmitSound("weapons/sentry_scan" .. lvlSuffix .. ".wav", 70, 100)
			end

			self.CurHeadYaw = math.NormalizeAngle(curBaseYaw + self.ScanOffset)
			self.CurHeadPitch = math.ApproachAngle(self.CurHeadPitch or 0, 0, 4)
		end
	end

	self.CurHeadYaw = self.CurHeadYaw or curBaseYaw
	self.CurHeadPitch = self.CurHeadPitch or 0

	self:SetNWFloat("TF2_HeadYaw", self.CurHeadYaw)
	self:SetNWFloat("TF2_HeadPitch", self.CurHeadPitch)

	local relYaw = math.NormalizeAngle(self.CurHeadYaw - curBaseYaw)
	local clPitch = math.Clamp(self.CurHeadPitch, -55, 55)

	local yawBone = self:LookupBone("upper_telescope_01")
	if yawBone and yawBone >= 0 then self:ManipulateBoneAngles(yawBone, Angle(relYaw, 0, 0)) end

	local pitchAng = Angle(0, 0, clPitch)
	local pitchBones = {
		"turret_back", "fork_base", "S2turret_back",
		"S2midHousingL", "S2midHousingR", "S2lFork_bolt", "S2rFork_bolt"
	}
	for _, bName in ipairs(pitchBones) do
		local bId = self:LookupBone(bName)
		if bId and bId >= 0 and bId ~= yawBone then self:ManipulateBoneAngles(bId, pitchAng) end
	end

	self:NextThink(curTime + 0.03)
	return true
end

function ENT:GetBarrelMuzzle(isRightBarrel)
	local headAngle = Angle(self.CurHeadPitch or 0, self.CurHeadYaw or self:GetAngles().y, 0)
	local height = (self.Level == 1) and 36 or 47
	local fwdDist = (self.Level == 1) and 24 or 32

	local sideOffset = 0
	if self.Level >= 2 then
		sideOffset = isRightBarrel and 16 or -16
	end

	local pos = self:GetPos() + Vector(0, 0, height) + headAngle:Forward() * fwdDist + headAngle:Right() * sideOffset
	return pos, headAngle
end

function ENT:FireBulletAtTarget(targetPos)
	local owner = self:GetBuildingOwner()
	local isDual = (self.Level >= 2)

	local function BulletCallback(att, tr, dmg)
		if IsValid(tr.Entity) and not tr.Entity:IsPlayer() and not tr.Entity:IsNPC() and not tr.Entity.TF2_Building and not tr.Entity.IsTF2Building and not tr.Entity.BuildingType then
			constraint.RemoveConstraints(tr.Entity, "Weld")
			local p = tr.Entity:GetPhysicsObject()
			if IsValid(p) then p:EnableMotion(true) p:Wake() end
		end
	end

	if isDual then
		self.UseRightBarrel = not self.UseRightBarrel
	else
		self.UseRightBarrel = false
	end

	local barrelPos, headAngle = self:GetBarrelMuzzle(self.UseRightBarrel)
	local aimDir = (targetPos - barrelPos):GetNormalized()

	self:FireBullets({
		Num = 1,
		Src = barrelPos,
		Dir = aimDir,
		Spread = isDual and Vector(0.02, 0.02, 0) or Vector(0.015, 0.015, 0),
		Tracer = 1,
		TracerName = "Tracer",
		Force = 3,
		Damage = 16,
		Attacker = IsValid(owner) and owner or self,
		Inflictor = self,
		IgnoreEntity = self,
		Callback = BulletCallback
	})

	local ef = EffectData()
	ef:SetOrigin(barrelPos)
	ef:SetAngles(headAngle)
	ef:SetScale(isDual and 1.0 or 0.9)
	util.Effect("MuzzleEffect", ef)

	local shootSound = "weapons/sentry_shoot.wav"
	if self.Level == 2 then
		shootSound = "weapons/sentry_shoot2.wav"
	elseif self.Level >= 3 then
		shootSound = "weapons/sentry_shoot3.wav"
	end

	self:EmitSound(shootSound, 80, 100, 1, CHAN_WEAPON)
end

function ENT:FireRocketSalvo(targetPos)
	local owner = self:GetBuildingOwner()
	self:EmitSound("weapons/sentry_rocket.wav", 88, 100)

	local podOffsets = {
		Vector(0, -3.35, 2.35),
		Vector(0, 3.35, 2.35),
		Vector(0, -3.35, -2.35),
		Vector(0, 3.35, -2.35)
	}

	for i = 1, 4 do
		timer.Simple((i - 1) * 0.08, function()
			if not IsValid(self) then return end

			local curAng = Angle(self.CurHeadPitch or 0, self.CurHeadYaw or self:GetAngles().y, 0)
			local baseRocketPos = self:GetPos() + Vector(0, 0, 64)

			local boneId = self:LookupBone("rocket")
			if boneId and boneId >= 0 then
				local bPos = self:GetBonePosition(boneId)
				if bPos and bPos ~= self:GetPos() then
					baseRocketPos = bPos
				end
			else
				local attId = self:LookupAttachment("rocket")
				if attId and attId > 0 then
					local att = self:GetAttachment(attId)
					if att and att.Pos then
						baseRocketPos = att.Pos
					end
				end
			end

			-- Вычисляем единое направление от центра ракетницы к цели, чтобы ракеты летели параллельно
			local sharedAimDir = (targetPos - baseRocketPos):GetNormalized()
			local sharedAng = sharedAimDir:Angle()

			local off = podOffsets[i]
			-- Выносим старт чуть вперёд (на 12 юнитов) по линии ствола, чтобы при стрельбе вниз ракета не задевала корпус турели
			local rPos = baseRocketPos + sharedAng:Forward() * 12 + sharedAng:Right() * off.y + sharedAng:Up() * off.z

			local rocket = ents.Create("ent_tf2_sentry_rocket")
			if IsValid(rocket) then
				rocket:SetPos(rPos)
				rocket:SetAngles(sharedAng)
				rocket.Sentry = self
				rocket.BuildingOwner = owner
				rocket:Spawn()
				rocket:Activate()
				rocket:SetVelocity(sharedAimDir * 1600)
			end
		end)
	end
end

function ENT:OnTakeDamage(dmg)
	local hp = self:Health() - dmg:GetDamage()
	self:SetHealth(hp)
	self:EmitSound("weapons/sentry_damage" .. math.random(1, 4) .. ".wav", 75, 100)
	if hp <= 0 then self:Explode() end
end

function ENT:Explode()
	local pos = self:GetPos()
	local ef = EffectData()
	ef:SetOrigin(pos)
	util.Effect("Explosion", ef)
	self:EmitSound("weapons/sentry_explode.wav", 85, 100)

	if IsValid(self.Controller) then self:ExitControl(self.Controller) end

	local owner = self:GetBuildingOwner()
	if IsValid(owner) and TF2_ENG then
		owner:SetNWEntity("TF2_Building_" .. TF2_ENG.BUILDING_SENTRY, NULL)
		owner:ChatPrint("[TF2 Sentry] Ваша турель была уничтожена!")
	end
	SafeRemoveEntity(self)
end

function ENT:OnRemove()
	if IsValid(self.Controller) then self:ExitControl(self.Controller) end
end

hook.Add("PlayerBindPress", "TF2_Sentry_Control_Block", function(ply, bind, pressed)
	if IsValid(ply:GetNWEntity("TF2_ControlledSentry")) then
		if string.find(bind, "+attack") or string.find(bind, "+attack2") then
			return true
		end
	end
end)

hook.Add("PlayerDeath", "TF2_Sentry_Killicon_LevelFix", function(victim, inflictor, attacker)
	if IsValid(inflictor) and inflictor:GetClass() == "ent_tf2_sentry" then
		local lvl = inflictor.Level or 1
		local virtualClass = "ent_tf2_sentry_lvl" .. lvl
		
		inflictor.GetClassOld = inflictor.GetClass
		inflictor.GetClass = function(self) return virtualClass end
		
		timer.Simple(0, function()
			if IsValid(inflictor) and inflictor.GetClassOld then
				inflictor.GetClass = inflictor.GetClassOld
				inflictor.GetClassOld = nil
			end
		end)
	end
end)
