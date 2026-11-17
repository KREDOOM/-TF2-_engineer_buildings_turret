include("shared.lua")

-- =========================================================
-- НАСТРОЙКИ ЭКРАНА РАЗДАТЧИКА
-- =========================================================
local SCREEN_CONFIG = {
	Width = 650,          -- Ширина экрана
	Height = 350,         -- Высота экрана
	Scale = 0.030,        -- Общий масштаб отображения 3D2D
	ForwardOffset = 7.4,  -- Смещение экрана вперед/назад от центра корпуса
	HeightOffset = 42.6,  -- Высота экрана от основания постройки
}
-- =========================================================

game.AddParticles("particles/building_dispenser.pcf")
PrecacheParticleSystem("dispenser_heal_red")
PrecacheParticleSystem("dispenser_heal_blue")

surface.CreateFont("TF2_Dispenser_FullLarge", {
	font = "Arial Black",
	extended = true,
	size = 36,
	weight = 900,
})

surface.CreateFont("TF2_Dispenser_FullMedium", {
	font = "Arial Black",
	extended = true,
	size = 28,
	weight = 800,
})

surface.CreateFont("TF2_Dispenser_FullSmall", {
	font = "Arial Black",
	extended = true,
	size = 24,
	weight = 800,
})

function ENT:Initialize()
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionBounds(Vector(-20, -20, 0), Vector(20, 20, 58))
	
	self.IdleSoundObject = nil
	self.HealSoundObject = nil
	self.HealBeams = {}
end

function ENT:HasLineOfSightClient(ply)
	if not IsValid(ply) then return false end
	local myPos = self:GetPos() + Vector(0, 0, 36)
	local targetCenter = ply:WorldSpaceCenter()
	local trCenter = util.TraceLine({
		start = myPos,
		endpos = targetCenter,
		filter = { self, ply },
		mask = MASK_SOLID,
	})
	return not trCenter.Hit
end

function ENT:StopAllHealBeams()
	if not self.HealBeams then return end
	for ply, beam in pairs(self.HealBeams) do
		if beam and beam:IsValid() then
			beam:StopEmissionAndDestroyImmediately()
		end
	end
	self.HealBeams = {}
end

local function DrawFullTF2Screen(lvl, hp, maxHp, curTime)
	local hpPct = math.Clamp(hp / math.max(1, maxHp), 0, 1)

	local w, h = SCREEN_CONFIG.Width, SCREEN_CONFIG.Height
	local hw, hh = w * 0.5, h * 0.5

	draw.RoundedBox(4, -hw, -hh, w, h, Color(10, 32, 50, 255))
	surface.SetDrawColor(40, 140, 220, 255)
	surface.DrawOutlinedRect(-hw, -hh, w, h, 4)

	local headH = math.floor(h * 0.22)
	draw.RoundedBox(4, -hw + 10, -hh + 10, w - 20, headH, Color(16, 54, 84, 255))
	draw.SimpleText("DISPENSER LVL " .. lvl, "TF2_Dispenser_FullLarge", 0, -hh + 10 + headH * 0.5, Color(140, 235, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local scanH = math.floor(h * 0.07)
	local scanY = -hh + 14 + headH
	local scanOffset = (curTime * 220) % (w - 20)
	draw.RoundedBox(2, -hw + 10, scanY, w - 20, scanH, Color(14, 40, 64, 255))
	draw.RoundedBox(2, -hw + 10, scanY, w - 20, scanH, Color(30, 100, 160, 140))
	draw.RoundedBox(2, -hw + 10 + (scanOffset % (w - 80)), scanY, 68, scanH, Color(160, 245, 255, 255))

	local barH = math.floor(h * 0.27)
	local barY = scanY + scanH + 8
	draw.RoundedBox(4, -hw + 10, barY, w - 20, barH, Color(8, 22, 34, 255))
	draw.RoundedBox(4, -hw + 10, barY, math.floor((w - 20) * hpPct), barH, Color(50, 180, 255, 255))
	draw.SimpleText(hp .. " / " .. maxHp .. " HP", "TF2_Dispenser_FullMedium", 0, barY + barH * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local statH = math.floor(h * 0.24)
	local statY = barY + barH + 8
	draw.RoundedBox(4, -hw + 10, statY, w - 20, statH, Color(14, 42, 66, 255))
	draw.SimpleText("RESERVES: ACTIVE", "TF2_Dispenser_FullSmall", 0, statY + statH * 0.5, Color(100, 245, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ENT:Draw()
	self:SetRenderMode(RENDERMODE_NORMAL)
	self:SetColor(color_white)
	self:DrawModel()

	local curTime = CurTime()
	local lvl = self:GetNWInt("TF2_Level", 1)
	local hp = self:Health()
	local maxHp = self:GetMaxHealth()
	local fwd = self:GetForward()
	local up = self:GetUp()
	local bPos = self:GetPos()

	local fwdDist = SCREEN_CONFIG.ForwardOffset
	local upDist = SCREEN_CONFIG.HeightOffset
	local scale = SCREEN_CONFIG.Scale

	-- 1. ЭКРАН С ПЕРЕДНЕЙ СТОРОНЫ
	local frontPos = bPos + fwd * fwdDist + up * upDist
	local frontAng = self:GetAngles()
	frontAng:RotateAroundAxis(up, 90)
	frontAng:RotateAroundAxis(frontAng:Forward(), 90)

	cam.Start3D2D(frontPos, frontAng, scale)
		DrawFullTF2Screen(lvl, hp, maxHp, curTime)
	cam.End3D2D()

	-- 2. ЭКРАН С ЗАДНЕЙ СТОРОНЫ
	local backPos = bPos - fwd * fwdDist + up * upDist
	local backAng = self:GetAngles()
	backAng:RotateAroundAxis(up, -90)
	backAng:RotateAroundAxis(backAng:Forward(), 90)

	cam.Start3D2D(backPos, backAng, scale)
		DrawFullTF2Screen(lvl, hp, maxHp, curTime)
	cam.End3D2D()
end

function ENT:Think()
	if not self.IdleSoundObject then
		self.IdleSoundObject = CreateSound(self, "weapons/dispenser_idle.wav")
		if self.IdleSoundObject then
			self.IdleSoundObject:Play()
			self.IdleSoundObject:ChangeVolume(0.5, 0)
		end
	end

	local startPos = self:GetPos() + Vector(0, 0, 32)
	local plys = ents.FindInSphere(startPos, 260)
	local isHealed = false
	local activePlayers = {}

	local effectName = (self:GetSkin() == 1) and "dispenser_heal_blue" or "dispenser_heal_red"

	for _, ply in ipairs(plys) do
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
			if self:HasLineOfSightClient(ply) then
				activePlayers[ply] = true

				if ply:Health() < ply:GetMaxHealth() or ply:Armor() < 100 or (ply.TF2_GetMetal and ply:TF2_GetMetal() < 200) then
					isHealed = true
				end

				local beam = self.HealBeams[ply]
				if not beam or not beam:IsValid() then
					beam = CreateParticleSystem(self, effectName, PATTACH_CUSTOMORIGIN, 0)
					self.HealBeams[ply] = beam
				end

				if beam and beam:IsValid() then
					local targetPos = ply:WorldSpaceCenter()
					local spineBone = ply:LookupBone("ValveBiped.Bip01_Spine2")
					if spineBone and spineBone >= 0 then
						local bPos = ply:GetBonePosition(spineBone)
						if bPos and bPos ~= ply:GetPos() then
							targetPos = bPos
						end
					end

					local aimDir = (targetPos - startPos):GetNormalized()

					beam:SetControlPoint(0, startPos)
					beam:SetControlPointForwardVector(0, aimDir)

					beam:SetControlPoint(1, targetPos)
					beam:SetControlPointForwardVector(1, -aimDir)
				end
			end
		end
	end

	for ply, beam in pairs(self.HealBeams) do
		if not activePlayers[ply] or not IsValid(ply) then
			if beam and beam:IsValid() then
				beam:StopEmissionAndDestroyImmediately()
			end
			self.HealBeams[ply] = nil
		end
	end

	if isHealed then
		if not self.HealSoundObject then
			self.HealSoundObject = CreateSound(self, "weapons/dispenser_heal.wav")
			if self.HealSoundObject then
				self.HealSoundObject:Play()
				self.HealSoundObject:ChangeVolume(0.6, 0)
			end
		end
	else
		if self.HealSoundObject then
			self.HealSoundObject:Stop()
			self.HealSoundObject = nil
		end
	end

	self:NextThink(CurTime() + 0.05)
	return true
end

function ENT:OnRemove()
	if self.IdleSoundObject then self.IdleSoundObject:Stop() end
	if self.HealSoundObject then self.HealSoundObject:Stop() end
	self:StopAllHealBeams()
end
