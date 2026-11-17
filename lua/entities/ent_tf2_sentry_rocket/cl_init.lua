include("shared.lua")

local glowMat = Material("sprites/glow04_noz")

function ENT:Draw()
	self:DrawModel()

	-- Огненный хвост ракеты
	local fwd = self:GetForward()
	local pos = self:GetPos() - fwd * 8
	render.SetMaterial(glowMat)
	render.DrawSprite(pos, 20, 20, Color(255, 160, 40, 255))
end