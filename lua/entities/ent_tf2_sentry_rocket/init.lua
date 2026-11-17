AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/weapons/w_missile_launch.mdl")
	-- Правильная инициализация физического бокса для взаимодействия с VPhysics
	self:PhysicsInitBox(Vector(-4, -4, -4), Vector(4, 4, 4))
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableGravity(false)
		phys:Wake()
	end

	-- Дымовой след ракеты
	util.SpriteTrail(self, 0, Color(255, 200, 100, 220), true, 7, 1, 0.4, 1 / (7 + 1) * 0.5, "trails/smoke.vmt")

	self.SpawnTime = CurTime()
	self.Exploded = false

	-- Гарантированное самоуничтожение через 3 секунды
	timer.Simple(3.0, function()
		if IsValid(self) then
			self:Explode()
		end
	end)

	self:NextThink(CurTime())
end

function ENT:Think()
	if not self:IsValid() or self.Exploded then return end

	-- Корректировка физической скорости для строгого полета вперед (поскольку гравитация отключена)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(self:GetForward() * 1600)
	end

	-- Трассировка столкновения по ходу полета
	local curPos = self:GetPos()
	local fwd = self:GetForward()
	local tr = util.TraceLine({
		start = curPos - fwd * 10,
		endpos = curPos + fwd * 50,
		filter = { self, self.Sentry, self.BuildingOwner },
		mask = MASK_SOLID
	})

	if tr.Hit then
		self:SetPos(tr.HitPos)
		self:Explode(tr.Entity)
		return
	end

	self:NextThink(CurTime() + 0.02)
	return true
end

function ENT:Touch(ent)
	if ent == self.Sentry or ent == self.BuildingOwner then return end
	self:Explode(ent)
end

function ENT:PhysicsCollide(data, phys)
	if data.HitEntity == self.Sentry or data.HitEntity == self.BuildingOwner then return end
	self:Explode(data.HitEntity)
end

-- Функция нанесения урона живым существам (Игроки/NPC/Некстботы) с фильтрацией построек владельца
local function ApplyBlastDamageToLiving(pos, radius, damage, attacker, inflictor, owner)
	local entities = ents.FindInSphere(pos, radius)
	for _, ent in ipairs(entities) do
		if IsValid(ent) then
			-- Защита от дружественного огня по постройкам:
			-- Если это постройка TF2 и её владелец — это тот же Инженер, полностью игнорируем урон
			if ent.IsTF2Building or ent.TF2_Building or string.find(ent:GetClass(), "ent_tf2_") then
				local bOwner = ent.GetBuildingOwner and ent:GetBuildingOwner() or ent:GetNWEntity("BuildingOwner")
				if IsValid(bOwner) and IsValid(owner) and bOwner == owner then 
					continue 
				end
			end

			-- Наносим урон только живым целям, NPC и Некстботам (пропы обработает отдельная функция)
			if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
				-- Просчет падения урона в зависимости от расстояния от центра взрыва
				local dist = pos:Distance(ent:WorldSpaceCenter())
				local tDmg = damage * (1 - (dist / radius))
				tDmg = math.max(1, math.floor(tDmg)) -- Урон не должен быть меньше 1 и округляется

				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(tDmg)
				dmgInfo:SetAttacker(attacker)
				dmgInfo:SetInflictor(inflictor)
				dmgInfo:SetDamageType(DMG_BLAST)
				dmgInfo:SetDamagePosition(pos)

				ent:TakeDamageInfo(dmgInfo)
			end
		end
	end
end

-- Функция нанесения урона пропам в радиусе взрыва без их размораживания
local function DamagePropsInRadius(pos, radius, damage, attacker, inflictor)
	local entities = ents.FindInSphere(pos, radius)
	for _, ent in ipairs(entities) do
		-- Проверяем, что объект валиден и это НЕ игрок, НЕ NPC и НЕ постройка TF2
		if IsValid(ent) and not ent:IsPlayer() and not ent:IsNPC() and not ent.TF2_Building and not ent.IsTF2Building then
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				-- Наносим пропам чистый урон взрывного типа
				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(damage)
				dmgInfo:SetAttacker(attacker)
				dmgInfo:SetInflictor(inflictor)
				dmgInfo:SetDamageType(DMG_BLAST)
				dmgInfo:SetDamagePosition(pos)
				
				ent:TakeDamageInfo(dmgInfo)
			end
		end
	end
end

function ENT:Explode(hitEnt)
	if self.Exploded then return end
	self.Exploded = true

	local pos = self:GetPos()
	local attacker = IsValid(self.BuildingOwner) and self.BuildingOwner or (IsValid(self.Sentry) and self.Sentry or self)
	local owner = self.BuildingOwner

	-- 1. ИСПРАВЛЕНО: Умный BlastDamage живым целям с жестким иммунитетом для ваших собственных построек
	ApplyBlastDamageToLiving(pos, 130, 45, attacker, self, owner)
	
	-- 2. Наносим урон физическим пропам (45 ед. в радиусе 130) без их расфриза
	DamagePropsInRadius(pos, 130, 45, attacker, self)

	local ef = EffectData()
	ef:SetOrigin(pos)
	ef:SetScale(1.2)
	util.Effect("Explosion", ef)

	self:EmitSound("ambient/explosions/explode_4.wav", 80, 110)

	SafeRemoveEntity(self)
end