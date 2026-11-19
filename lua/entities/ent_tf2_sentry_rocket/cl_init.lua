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

-- Иконка в киллфиде для убийств ракетами (инфликтором является ракета, а не турель)
do
	local matPath = "hud/killicons/d_sentry3"
	if not file.Exists("materials/" .. matPath .. ".vmt", "GAME") then
		matPath = "vgui/entities/ent_tf2_sentry"
	end
	killicon.Add("ent_tf2_sentry_rocket", matPath, Color(255, 255, 255))
end