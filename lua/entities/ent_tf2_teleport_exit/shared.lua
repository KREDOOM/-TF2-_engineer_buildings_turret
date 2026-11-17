ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Телепорт: Выход (Teleporter Exit)"
ENT.Author = "TF2 Engineer"
ENT.Category = "Team Fortress 2"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.BuildingType = TF2_ENG and TF2_ENG.BUILDING_TELE_EXIT or 4

-- Общая коллизия SOLID_BBOX для идеального предсказания на клиенте и сервере
function ENT:SetupSharedPhysics()
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(Vector(-24, -24, 0), Vector(24, 24, 12))
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
end
