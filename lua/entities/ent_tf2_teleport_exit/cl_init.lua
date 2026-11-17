include("shared.lua")

game.AddParticles("particles/building_teleporter.pcf")
for _, team in ipairs({"red", "blue"}) do
	for lvl = 1, 3 do
		PrecacheParticleSystem("teleporter_" .. team .. "_exit_level" .. lvl)
		PrecacheParticleSystem("teleporter_" .. team .. "_charged_level" .. lvl)
	end
end

local spinSounds = {
	[1] = "weapons/teleporter_spin.wav",
	[2] = "weapons/teleporter_spin2.wav",
	[3] = "weapons/teleporter_spin3.wav"
}

function ENT:Initialize()
	self:SetupSharedPhysics()

	self.TargetRotation = 0
	self.CurrentSoundLevel = 0
	self.ActiveExitName = ""
	self.ActiveChargedName = ""
end

function ENT:FindEnterTeleport()
	local owner = self:GetNWEntity("BuildingOwner")
	if not IsValid(owner) then return nil end

	for _, ent in ipairs(ents.FindByClass("ent_tf2_teleport_enter")) do
		if IsValid(ent) then
			local entOwner = ent:GetNWEntity("BuildingOwner")
			if IsValid(entOwner) and entOwner == owner then
				return ent
			end
		end
	end

	return nil
end

function ENT:StopExitEffect()
	if self.ExitParticle and self.ExitParticle:IsValid() then
		self.ExitParticle:StopEmissionAndDestroyImmediately()
	end
	self.ExitParticle = nil
	self.ActiveExitName = ""
end

function ENT:StopChargedEffect()
	if self.ChargedParticle and self.ChargedParticle:IsValid() then
		self.ChargedParticle:StopEmissionAndDestroyImmediately()
	end
	self.ChargedParticle = nil
	self.ActiveChargedName = ""
end

function ENT:StopAllTeleporterEffects()
	self:StopExitEffect()
	self:StopChargedEffect()
end

function ENT:UpdateTeleporterEffects(level, hasEnter, isReady)
	if not hasEnter then
		self:StopAllTeleporterEffects()
		return
	end

	local teamStr = (self:GetSkin() == 1) and "blue" or "red"
	local clampedLvl = math.Clamp(level, 1, 3)

	-- 1. Базовый эффект выхода (Exit): работает всегда, пока установлен вход
	local targetExit = "teleporter_" .. teamStr .. "_exit_level" .. clampedLvl
	if self.ActiveExitName ~= targetExit or not self.ExitParticle or not self.ExitParticle:IsValid() then
		self:StopExitEffect()
		self.ExitParticle = CreateParticleSystem(self, targetExit, PATTACH_ABSORIGIN_FOLLOW, 0)
		self.ActiveExitName = targetExit
	end

	-- 2. Эффект готовности (Charged): накладывается поверх, когда входной телепорт заряжен
	if isReady then
		local targetCharged = "teleporter_" .. teamStr .. "_charged_level" .. clampedLvl
		if self.ActiveChargedName ~= targetCharged or not self.ChargedParticle or not self.ChargedParticle:IsValid() then
			self:StopChargedEffect()
			self.ChargedParticle = CreateParticleSystem(self, targetCharged, PATTACH_ABSORIGIN_FOLLOW, 0)
			self.ActiveChargedName = targetCharged
		end
	else
		self:StopChargedEffect()
	end
end

function ENT:UpdateSpinSound(level, hasEnter)
	local targetLevel = hasEnter and level or 0
	if self.CurrentSoundLevel == targetLevel then return end

	if self.SpinSoundObject then
		self.SpinSoundObject:Stop()
		self.SpinSoundObject = nil
	end

	if targetLevel > 0 then
		local soundPath = spinSounds[targetLevel]
		if soundPath then
			self.SpinSoundObject = CreateSound(self, soundPath)
			if self.SpinSoundObject then
				self.SpinSoundObject:Play()
				self.SpinSoundObject:ChangeVolume(0.7, 0) 
			end
		end
	end

	self.CurrentSoundLevel = targetLevel
end

function ENT:Think()
	local enterEnt = self:FindEnterTeleport()
	local hasEnter = IsValid(enterEnt)
	local currentLevel = self:GetNWInt("TF2_Level", 1)
	
	local isReady = hasEnter and enterEnt:GetNWBool("TF2_TeleReady", false)

	self:UpdateSpinSound(currentLevel, hasEnter)
	self:UpdateTeleporterEffects(currentLevel, hasEnter, isReady)

	if hasEnter then
		self:SetBodygroup(1, 1)
		local boneIndex = self:LookupBone("mid_section")
		if boneIndex then
			local ft = FrameTime()
			if ft > 0 then
				self.TargetRotation = (self.TargetRotation - ((800 * currentLevel) * ft)) % 360
				self:ManipulateBoneAngles(boneIndex, Angle(self.TargetRotation, 0, 0))
			end
		end
	else
		self:SetBodygroup(1, 0)
		local boneIndex = self:LookupBone("mid_section")
		if boneIndex then
			self:ManipulateBoneAngles(boneIndex, Angle(0, 0, 0))
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:OnRemove()
	if self.SpinSoundObject then
		self.SpinSoundObject:Stop()
	end
	self:StopAllTeleporterEffects()
end
