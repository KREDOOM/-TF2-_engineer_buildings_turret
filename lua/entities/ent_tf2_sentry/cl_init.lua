include("shared.lua")

function ENT:Initialize()
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionBounds(Vector(-20, -20, 0), Vector(20, 20, 58))
	self:EnableCustomCollisions(true)

	self.SmoothRelYaw = 0
	self.SmoothRelPitch = 0
end

function ENT:Think()
	local targetWorldYaw = self:GetNWFloat("TF2_HeadYaw", self:GetAngles().y)
	local targetPitch = self:GetNWFloat("TF2_HeadPitch", 0)

	local targetRelYaw = math.NormalizeAngle(targetWorldYaw - self:GetAngles().y)
	local targetRelPitch = math.NormalizeAngle(targetPitch)

	local dt = FrameTime()
	if dt <= 0 then dt = 0.015 end

	self.SmoothRelYaw = math.ApproachAngle(self.SmoothRelYaw or targetRelYaw, targetRelYaw, dt * 280)
	self.SmoothRelPitch = math.ApproachAngle(self.SmoothRelPitch or targetRelPitch, targetRelPitch, dt * 220)

	self:UpdateHeadRotation(self.SmoothRelYaw, self.SmoothRelPitch)

	self:NextThink(CurTime())
	return true
end

function ENT:UpdateHeadRotation(relYaw, relPitch)
	local clPitch = math.Clamp(relPitch, -55, 55)

	local yawBone = self:LookupBone("upper_telescope_01")
	if yawBone and yawBone >= 0 then
		self:ManipulateBoneAngles(yawBone, Angle(relYaw, 0, 0))
	end

	local pitchAng = Angle(0, 0, clPitch)
	local pitchBones = {
		"turret_back", "fork_base", "S2turret_back",
		"S2midHousingL", "S2midHousingR", "S2lFork_bolt", "S2rFork_bolt"
	}

	for _, bName in ipairs(pitchBones) do
		local bId = self:LookupBone(bName)
		if bId and bId >= 0 and bId ~= yawBone then
			self:ManipulateBoneAngles(bId, pitchAng)
		end
	end
end

function ENT:Draw()
	self:DrawModel()
end

if CLIENT then
	local kfColor = Color(255, 255, 255, 255)

	-- Оригинальные TF2 killicon'ы, если отсутствуют — используем иконку энтити из спавнменю
	local function AddSentryKillicon(class, matPath)
		if not file.Exists("materials/" .. matPath .. ".vmt", "GAME") then
			matPath = "vgui/entities/ent_tf2_sentry"
		end
		killicon.Add(class, matPath, kfColor)
	end

	AddSentryKillicon("ent_tf2_sentry_lvl1", "hud/killicons/d_sentry1")
	AddSentryKillicon("ent_tf2_sentry_lvl2", "hud/killicons/d_sentry2")
	AddSentryKillicon("ent_tf2_sentry_lvl3", "hud/killicons/d_sentry3")
end
