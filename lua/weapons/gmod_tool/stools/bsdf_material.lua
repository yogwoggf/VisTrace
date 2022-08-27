TOOL.Category = "Render"
TOOL.Name = "#tool.bsdf_material.name"

TOOL.Information = {
	{name = "left"},
	{name = "right"},
	{name = "reload"}
}

TOOL.ClientConVar.r = 255
TOOL.ClientConVar.g = 255
TOOL.ClientConVar.b = 255
TOOL.ClientConVar.roughness = 1
TOOL.ClientConVar.metalness = 0
TOOL.ClientConVar.ior = 1.5
TOOL.ClientConVar.difftrans = 0
TOOL.ClientConVar.spectrans = 0
TOOL.ClientConVar.thin = 0

-- Dupe support
local function SetMaterial(plr, ent, materialTbl)
	if CLIENT then return true end

	ent.BSDFMaterial = materialTbl
	if materialTbl then
		duplicator.StoreEntityModifier(ent, "BSDFMaterial", materialTbl)
		ent:SetNWBool("BSDFMaterial.Set", true)
		ent:SetNWVector("BSDFMaterial.Colour", materialTbl.Colour)
		ent:SetNWFloat("BSDFMaterial.Roughness", materialTbl.Roughness)
		ent:SetNWFloat("BSDFMaterial.Metalness", materialTbl.Metalness)
		ent:SetNWFloat("BSDFMaterial.IoR", materialTbl.IoR)
		ent:SetNWFloat("BSDFMaterial.DiffuseTransmission", materialTbl.DiffuseTransmission)
		ent:SetNWFloat("BSDFMaterial.SpecularTransmission", materialTbl.SpecularTransmission)
		ent:SetNWBool("BSDFMaterial.Thin", materialTbl.Thin)
	else
		duplicator.ClearEntityModifier(ent, "BSDFMaterial")
		ent:SetNWBool("BSDFMaterial.Set", false)
	end

	return true
end

duplicator.RegisterEntityModifier("BSDFMaterial", SetMaterial)

-- Apply
function TOOL:LeftClick(trace)
	local ent = trace.Entity
	if IsValid(ent.AttachedEntity) then ent = ent.AttachedEntity end

	if not IsValid(ent) then return false end
	if CLIENT then return true end

	local r = self:GetClientNumber("r", 255)
	local g = self:GetClientNumber("g", 255)
	local b = self:GetClientNumber("b", 255)
	local roughness = self:GetClientNumber("roughness", 1)
	local metalness = self:GetClientNumber("metalness", 0)
	local ior = self:GetClientNumber("ior", 1.5)
	local difftrans = self:GetClientNumber("difftrans", 0)
	local spectrans = self:GetClientNumber("spectrans", 0)
	local thin = self:GetClientNumber("thin", 0) ~= 0

	SetMaterial(self:GetOwner(), ent, {
		Colour = Vector(r, g, b) / 255,
		Roughness = roughness,
		Metalness = metalness,
		IoR = ior,
		DiffuseTransmission = difftrans,
		SpecularTransmission = spectrans,
		Thin = thin
	})
	return true
end

-- Copy
function TOOL:RightClick(trace)
	local ent = trace.Entity
	if IsValid(ent.AttachedEntity) then ent = ent.AttachedEntity end

	if not IsValid(ent) then return false end
	if CLIENT then return true end

	local mat = ent.BSDFMaterial or {
		Colour = Vector(1, 1, 1),
		Roughness = 1,
		Metalness = 0,
		IoR = 1.5,
		DiffuseTransmission = 0,
		SpecularTransmission = 0,
		Thin = false
	}

	self:GetOwner():ConCommand("bsdf_material_r "         .. mat.Colour[1] * 255)
	self:GetOwner():ConCommand("bsdf_material_g "         .. mat.Colour[2] * 255)
	self:GetOwner():ConCommand("bsdf_material_b "         .. mat.Colour[3] * 255)
	self:GetOwner():ConCommand("bsdf_material_roughness " .. mat.Roughness)
	self:GetOwner():ConCommand("bsdf_material_metalness " .. mat.Metalness)
	self:GetOwner():ConCommand("bsdf_material_ior "       .. mat.IoR)
	self:GetOwner():ConCommand("bsdf_material_difftrans " .. mat.DiffuseTransmission)
	self:GetOwner():ConCommand("bsdf_material_spectrans " .. mat.SpecularTransmission)
	self:GetOwner():ConCommand("bsdf_material_thin "      .. mat.Thin and "1" or "0")

	return true
end

-- Clear
function TOOL:Reload(trace)
	local ent = trace.Entity
	if IsValid(ent.AttachedEntity) then ent = ent.AttachedEntity end

	if not IsValid(ent) then return false end
	if CLIENT then return true end

	SetMaterial(self:GetOwner(), ent, nil)
	return true
end

if CLIENT then
	language.Add("tool.bsdf_material.name", "BSDF Material")
	language.Add("tool.bsdf_material.desc", "Change the BSDF Material used by VisTrace of an object")
	language.Add("tool.bsdf_material.left", "Apply the current material")
	language.Add("tool.bsdf_material.right", "Copy the material of an entity")
	language.Add("tool.bsdf_material.reload", "Reset the material of an entity")

	local entity = FindMetaTable("Entity")
	function entity:GetBSDFMaterial()
		if not vistrace then
			error("The required version (v" .. VISTRACE_VERSION .. ") of the VisTrace binary module is not installed (get it here https://github.com/Derpius/VisTrace/releases)")
		end

		local mat = vistrace.CreateMaterial()
		if not self:GetNWBool("BSDFMaterial.Set") then return mat end

		mat:Colour(self:GetNWVector("BSDFMaterial.Colour"))
		mat:Roughness(self:GetNWFloat("BSDFMaterial.Roughness"))
		mat:Metalness(self:GetNWFloat("BSDFMaterial.Metalness"))
		mat:IoR(self:GetNWFloat("BSDFMaterial.IoR"))
		mat:DiffuseTransmission(self:GetNWFloat("BSDFMaterial.DiffuseTransmission"))
		mat:SpecularTransmission(self:GetNWFloat("BSDFMaterial.SpecularTransmission"))
		mat:Thin(self:GetNWBool("BSDFMaterial.Thin"))

		return mat
	end

	local function DirToCubemap(map, dir, mip)
		local absX, absY, absZ = math.abs(dir[1]), math.abs(dir[2]), math.abs(dir[3])
		local posX, posY, posZ = dir[1] > 0, dir[2] > 0, dir[3] > 0

		local maxAxis = math.max(absX, absY, absZ)
		local u, v, face

		if maxAxis == absX then
			if posX then
				u = -dir[3]
				v = dir[2]
				face = 0
			else
				u = dir[3]
				v = dir[2]
				face = 1
			end
		elseif maxAxis == absY then
			if posY then
				u = dir[1]
				v = -dir[3]
				face = 2
			else
				u = dir[1]
				v = dir[3]
				face = 3
			end
		else
			if posZ then
				u = dir[1]
				v = dir[2]
				face = 4
			else
				u = -dir[1]
				v = dir[2]
				face = 5
			end
		end

		u = 0.5 * (u / maxAxis + 1)
		v = 0.5 * (v / maxAxis + 1)
		v = 1 - v

		return map:Sample(u, v, mip, 0, face)
	end

	local function Reflect(incident, normal)
		return -incident + 2 * incident:Dot(normal) * normal
	end

	local function Refract(incident, normal, invEta)
		local cosine = normal:Dot(incident)
		local k = 1 + invEta * invEta * (cosine * cosine - 1)
		if k < 0 then return Vector(0, 0, 0) end
		return -incident * invEta + (invEta * cosine - math.sqrt(k)) * normal;
	end

	-- Preview params
	local PREVIEW_RES = 256
	local PREVIEW_PADDING = 64
	local PREVIEW_SPOT_LIGHT = Vector(-4, 3, 3) -- Position of spot light relative to sphere (x points into the screen, y and z are screen x and y)
	local PREVIEW_INDIRECT_MINCOS = 0.001 -- Minimum cosine to sample (no point sampling parallel to the surface)
	local PREVIEW_INDIRECT_RES = 8       -- How many snapshots of iDotN should we take evenly between min cosine and 1
	local PREVIEW_INDIRECT_SAMPLES = 1024   -- How many samples of the BSDF to take at each snapshot

	-- Only used for displaying the background
	local FOCAL_LENGTH = 10
	local SENSOR_HEIGHT = 24

	local previewRT = GetRenderTarget("VisTrace.BSDFMaterialPreview", PREVIEW_RES, PREVIEW_RES)
	local previewMat = CreateMaterial("VisTrace.BSDFMaterialPreview", "UnlitGeneric", {
		["$basetexture"] = previewRT:GetName()
	})

	-- Cache padding calcs
	local RES_MINUS_PADDING = PREVIEW_RES - PREVIEW_PADDING
	local PAD_DIV_2 = PREVIEW_PADDING / 2

	-- Cache indirect sampling calcs
	local INDIRECT_INCREMENT = (1 - PREVIEW_INDIRECT_MINCOS) / PREVIEW_INDIRECT_RES

	-- Cache camera calcs
	local CAM_SCALE = 0.5 * SENSOR_HEIGHT / FOCAL_LENGTH

	local sampler = vistrace and vistrace.CreateSampler() or {}
	local hdri = vistrace and vistrace.LoadTexture("vistrace/material_preview/gallery002") or {}
	local hdrimips = vistrace and hdri:GetMIPLevels() or 0

	local function DrawPreview()
		if not vistrace then return end

		render.PushRenderTarget(previewRT)
		render.Clear(0, 0, 0, 255, true, true)

		local plr = LocalPlayer()
		local r         = plr:GetInfoNum("bsdf_material_r", 255) / 255
		local g         = plr:GetInfoNum("bsdf_material_g", 255) / 255
		local b         = plr:GetInfoNum("bsdf_material_b", 255) / 255
		local roughness = plr:GetInfoNum("bsdf_material_roughness", 1)
		local metalness = plr:GetInfoNum("bsdf_material_metalness", 0)
		local ior       = plr:GetInfoNum("bsdf_material_ior", 1.5)
		local difftrans = plr:GetInfoNum("bsdf_material_difftrans", 0)
		local spectrans = plr:GetInfoNum("bsdf_material_spectrans", 0)
		local thin      = plr:GetInfoNum("bsdf_material_thin", 0) ~= 0

		local mat = vistrace.CreateMaterial()
		mat:Colour(Vector(r, g, b))
		mat:Roughness(roughness)
		mat:Metalness(metalness)
		mat:IoR(ior)
		mat:DiffuseTransmission(difftrans)
		mat:SpecularTransmission(spectrans)
		mat:Thin(thin)

		-- Compute average throughput of a few iDotNs and store in a LUT
		-- This means we can approximate the intergral for indirect lighting assuming a uniform colour in all directions of the integral
		-- by linearly interpolating between LUT values
		local indirectLUTDiffuseReflection = {}
		local indirectLUTSpecularReflection = {}
		local indirectLUTSpecularTransmission = {}
		local iDotN = PREVIEW_INDIRECT_MINCOS
		for i = 1, PREVIEW_INDIRECT_RES do
			-- Convert sampled dot product to an incident vector (assuming the normal is positive Z)
			local incident = Vector(math.sin(math.acos(iDotN)), 0, iDotN)
			local normal = Vector(0, 0, 1)

			-- Sample diffuse reflection
			mat:ActiveLobes(LobeType.DiffuseReflection)
			local throughput = Vector(0, 0, 0)
			local validSamples = PREVIEW_INDIRECT_SAMPLES
			for j = 1, PREVIEW_INDIRECT_SAMPLES do
				local valid, sample = vistrace.SampleBSDF(sampler, mat, normal, incident)
				if valid then
					throughput = throughput + sample.weight
				else
					validSamples = validSamples - 1
				end
			end
			indirectLUTDiffuseReflection[i] = throughput / validSamples

			-- Sample specular reflection
			mat:ActiveLobes(bit.band(LobeType.Specular, LobeType.Reflection))
			throughput = Vector(0, 0, 0)
			validSamples = PREVIEW_INDIRECT_SAMPLES * roughness + 1
			for j = 0, PREVIEW_INDIRECT_SAMPLES * roughness do
				local valid, sample = vistrace.SampleBSDF(sampler, mat, normal, incident)
				if valid then
					throughput = throughput + sample.weight
				else
					validSamples = validSamples - 1
				end
			end
			indirectLUTSpecularReflection[i] = throughput / validSamples

			-- Sample specular transmission
			mat:ActiveLobes(bit.band(LobeType.Specular, LobeType.Transmission))
			throughput = Vector(0, 0, 0)
			validSamples = PREVIEW_INDIRECT_SAMPLES * roughness + 1
			for j = 0, PREVIEW_INDIRECT_SAMPLES * roughness do
				local valid, sample = vistrace.SampleBSDF(sampler, mat, normal, incident)
				if valid then
					throughput = throughput + sample.weight
				else
					validSamples = validSamples - 1
				end
			end
			indirectLUTSpecularTransmission[i] = throughput / validSamples

			iDotN = iDotN + INDIRECT_INCREMENT
		end
		mat:ActiveLobes(LobeType.All)

		for y = 0, PREVIEW_RES - 1 do
			for x = 0, PREVIEW_RES - 1 do
				render.SetViewPort(x, y, 1, 1)

				local u = (x - PAD_DIV_2) / RES_MINUS_PADDING
				local v = (y - PAD_DIV_2) / RES_MINUS_PADDING
				u = u * 2 - 1
				v = v * 2 - 1

				local u2, v2 = u * u, v * v
				if u2 + v2 < 1 then
					local normal = Vector(-math.sqrt(1 - u2 - v2), u, -v)
					local incident = Vector(-1, 0, 0)
					iDotN = normal:Dot(incident)
					local deltaReflect = Reflect(incident, normal)
					local deltaRefract = Refract(incident, normal, 1 / ior)

					-- Direct contribution
					local lDir = PREVIEW_SPOT_LIGHT - normal
					lDir:Normalize()
					local direct = vistrace.EvalBSDF(mat, normal, incident, lDir)

					-- Indirect contribution
					local index = iDotN * (PREVIEW_INDIRECT_RES - 1)
					local iLow, iHigh = math.floor(index), math.ceil(index)
					local diffuseReflection, specularReflection, specularTransmission
					if iLow == iHigh then
						diffuseReflection = indirectLUTDiffuseReflection[iLow + 1]
						specularReflection = indirectLUTSpecularReflection[iLow + 1]
						specularTransmission = indirectLUTSpecularTransmission[iLow + 1]
					else
						local fract = index - iLow
						diffuseReflection = (1 - fract) * indirectLUTDiffuseReflection[iLow + 1] + fract * indirectLUTDiffuseReflection[iHigh + 1]
						specularReflection = (1 - fract) * indirectLUTSpecularReflection[iLow + 1] + fract * indirectLUTSpecularReflection[iHigh + 1]
						specularTransmission = (1 - fract) * indirectLUTSpecularTransmission[iLow + 1] + fract * indirectLUTSpecularTransmission[iHigh + 1]
					end
					diffuseReflection = diffuseReflection * DirToCubemap(hdri, normal, hdrimips - 1)
					specularReflection = specularReflection * DirToCubemap(hdri, deltaReflect, roughness * (hdrimips - 1))
					specularTransmission = specularTransmission * DirToCubemap(hdri, deltaRefract, roughness * (hdrimips - 1))

					local lighting = direct + diffuseReflection + specularReflection + specularTransmission

					render.Clear(
						math.Clamp(lighting[1], 0, 1) * 255,
						math.Clamp(lighting[2], 0, 1) * 255,
						math.Clamp(lighting[3], 0, 1) * 255,
						255, true, true
					)
				else
					local xCam = (2 * (x + 0.5) / PREVIEW_RES - 1) * CAM_SCALE
					local yCam = (1 - 2 * (y + 0.5) / PREVIEW_RES) * CAM_SCALE

					local dir = Vector(1, xCam, yCam)
					dir:Normalize()

					local envcol = DirToCubemap(hdri, dir, 0)
					render.Clear(
						envcol[1] * 255,
						envcol[2] * 255,
						envcol[3] * 255,
						255, true, true
					)
				end
			end
		end

		render.PopRenderTarget()
		hook.Remove("PostRenderVGUI", "VisTrace.BSDFMaterialPreview")
	end

	local CON_VARS_DEFAULT = TOOL:BuildConVarList()
	function TOOL.BuildCPanel(CPanel)
		CPanel:ClearControls()

		CPanel:AddControl("Header", {Description = [[
			Configure a VisTrace BSDF material and apply it to entities
			You can also preview the material below if you have the latest VisTrace binary module installed
		]]})

		CPanel:ToolPresets("BSDFMaterial", CON_VARS_DEFAULT)

		local width = CPanel:GetWide()

		local diffuseMixer = vgui.Create("DColorMixer")
		diffuseMixer:SetLabel("Diffuse Colour")
		diffuseMixer:Dock(FILL)
		diffuseMixer:SetPalette(true)
		diffuseMixer:SetAlphaBar(false)
		diffuseMixer:SetWangs(true)
		diffuseMixer:SetColor(Color(255, 255, 255))
		diffuseMixer:SetConVarR("bsdf_material_r")
		diffuseMixer:SetConVarG("bsdf_material_g")
		diffuseMixer:SetConVarB("bsdf_material_b")
		CPanel:AddItem(diffuseMixer)

		CPanel:NumSlider("Metalness", "bsdf_material_metalness", 0, 1, 2)
		CPanel:NumSlider("Roughness", "bsdf_material_roughness", 0, 1, 2)
		CPanel:NumSlider("Index of Refraction", "bsdf_material_ior", 1, 5, 2)
		CPanel:NumSlider("Specular Transmission", "bsdf_material_spectrans", 0, 1, 2)
		CPanel:NumSlider("Diffuse Transmission", "bsdf_material_difftrans", 0, 1, 2)

		local BUTTON_HEIGHT = 24
		local previewContainer = vgui.Create("DPanel")
		previewContainer:Dock(TOP)
		previewContainer:SetHeight(PREVIEW_RES + BUTTON_HEIGHT)
		previewContainer.Paint = nil

		local generatePreview = vgui.Create("DButton", previewContainer)
		generatePreview:SetSize(PREVIEW_RES, BUTTON_HEIGHT)
		generatePreview:SetText("Generate Preview")
		function generatePreview:DoClick()
			hook.Add("PostRenderVGUI", "VisTrace.BSDFMaterialPreview", DrawPreview)
		end

		local previewPanel = vgui.Create("DPanel", previewContainer)
		previewPanel:SetSize(PREVIEW_RES, PREVIEW_RES)

		function previewPanel:Paint(w, h)
			surface.SetDrawColor(255, 255, 255)
			surface.SetMaterial(previewMat)
			surface.DrawTexturedRect(0, 0, w, h)
		end

		function previewContainer:PerformLayout(w, h)
			local offset = w * 0.5 - PREVIEW_RES / 2
			generatePreview:SetPos(offset, 0)
			previewPanel:SetPos(offset, BUTTON_HEIGHT)
		end

		CPanel:AddPanel(previewContainer)
	end
end
