local colors = TF2_ENG.Colors
local currentPlacementType = nil
local ghostModelEnt = nil
local ghostYaw = 0

function TF2_ENG.StartBuildingPlacement(bType)
	local lp = LocalPlayer()
	if not IsValid(lp) then return end

	local bDef = TF2_ENG.Buildings[bType]
	if not bDef then return end

	if IsValid(ghostModelEnt) then
		ghostModelEnt:Remove()
		ghostModelEnt = nil
	end

	currentPlacementType = bType
	ghostYaw = lp:EyeAngles().y

	local mdl = TF2_ENG.GetBuildingModel(bType)
	ghostModelEnt = ClientsideModel(mdl, RENDERGROUP_TRANSLUCENT)
	if IsValid(ghostModelEnt) then
		ghostModelEnt:SetNoDraw(true)
		ghostModelEnt:SetSkin(lp:TF2_GetTeamSkin())
		if bType == TF2_ENG.BUILDING_DISPENSER then
			for i = 0, ghostModelEnt:GetBoneCount() - 1 do
				local bName = ghostModelEnt:GetBoneName(i)
				if bName and string.find(string.lower(bName), "chain") then
					ghostModelEnt:ManipulateBoneScale(i, Vector(0, 0, 0))
					ghostModelEnt:ManipulateBonePosition(i, Vector(0, 0, -100))
				end
			end
		end
	end

	surface.PlaySound("weapons/draw_default.wav")
end

function TF2_ENG.CancelPlacement()
	if IsValid(ghostModelEnt) then
		ghostModelEnt:Remove()
		ghostModelEnt = nil
	end
	currentPlacementType = nil
end

hook.Add("PostDrawTranslucentRenderables", "TF2_ENG.DrawPlacementHologram", function(bDrawingDepth, bDrawingSkybox)
	if bDrawingSkybox then return end
	if not currentPlacementType or not IsValid(ghostModelEnt) then return end

	local lp = LocalPlayer()
	if not IsValid(lp) or not lp:Alive() then
		TF2_ENG.CancelPlacement()
		return
	end

	-- Без ограничений по дистанции (до 1500 юнитов вдаль)
	local tr = util.TraceLine({
		start = lp:EyePos(),
		endpos = lp:EyePos() + lp:GetAimVector() * 1500,
		filter = { lp, ghostModelEnt },
		mask = MASK_SOLID
	})

	local isTele = (currentPlacementType == TF2_ENG.BUILDING_TELE_ENTER or currentPlacementType == TF2_ENG.BUILDING_TELE_EXIT)
	local placePos = tr.HitPos
	local placeAng = Angle(0, ghostYaw, 0)

	local isSpawnOrSafe, reason = TF2_ENG.IsSpawnOrSafeZone(placePos)
	local isValidPos = tr.Hit and (isTele or tr.HitNormal.z > 0.2) and not isSpawnOrSafe

	ghostModelEnt:SetPos(placePos)
	ghostModelEnt:SetAngles(placeAng)

	local renderCol = isValidPos and colors.tf2_blueprint_valid or colors.tf2_blueprint_invalid

	render.SetColorModulation(renderCol.r / 255, renderCol.g / 255, renderCol.b / 255)
	render.SetBlend(0.65)
	ghostModelEnt:DrawModel()
	render.SetBlend(1.0)
	render.SetColorModulation(1, 1, 1)

	-- Каркасный контур основания чертежа
	local mn, mx = ghostModelEnt:GetRenderBounds()
	local boxMin = mn
	local boxMax = mx

	render.SetColorMaterial()
	render.DrawWireframeBox(placePos, placeAng, boxMin, boxMax, renderCol, true)

	-- Предупреждающая 3D2D плашка, если игрок пытается строить на спавне или в сейфзоне
	if isSpawnOrSafe then
		local lookAng = (placePos - lp:EyePos()):Angle()
		local textAng = Angle(0, lookAng.y - 90, 90)

		cam.Start3D2D(placePos + Vector(0, 0, 48), textAng, 0.12)
			draw.SimpleText("НЕЛЬЗЯ СТРОИТЬ", "Trebuchet24", 0, -14, Color(255, 60, 60, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(string.upper(reason or "НА СПАВНЕ!"), "Trebuchet18", 0, 14, Color(255, 210, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end
end)

-- Управление размещением (ЛКМ - строить, ПКМ - повернуть, R - отмена)
hook.Add("PlayerBindPress", "TF2_ENG.PlacementKeys", function(ply, bind, pressed)
	if not pressed or not currentPlacementType then return end

	if string.find(bind, "+attack2") then
		ghostYaw = (ghostYaw + 90) % 360
		surface.PlaySound("weapons/weapon_draw_01.wav")
		return true
	elseif string.find(bind, "+attack") then
		local lp = LocalPlayer()
		local tr = util.TraceLine({
			start = lp:EyePos(),
			endpos = lp:EyePos() + lp:GetAimVector() * 1500,
			filter = { lp, ghostModelEnt },
			mask = MASK_SOLID
		})

		local isTele = (currentPlacementType == TF2_ENG.BUILDING_TELE_ENTER or currentPlacementType == TF2_ENG.BUILDING_TELE_EXIT)
		local isSpawnOrSafe, reason = TF2_ENG.IsSpawnOrSafeZone(tr.HitPos)
		local isValidPos = tr.Hit and (isTele or tr.HitNormal.z > 0.2) and not isSpawnOrSafe

		if isValidPos then
			net.Start("TF2_PlaceBuilding")
			net.WriteUInt(currentPlacementType, 4)
			net.WriteVector(tr.HitPos)
			net.WriteAngle(Angle(0, ghostYaw, 0))
			net.SendToServer()

			TF2_ENG.CancelPlacement()
			return true
		else
			surface.PlaySound("player/suit_denydevice.wav")
			if isSpawnOrSafe then
				chat.AddText(Color(255, 70, 70), "[TF2 Engineer] Запрещено ставить постройки " .. (reason or "на спавне") .. "!")
			end
			return true
		end
	elseif string.find(bind, "+reload") then
		TF2_ENG.CancelPlacement()
		surface.PlaySound("weapons/draw_default.wav")
		return true
	end
end)
