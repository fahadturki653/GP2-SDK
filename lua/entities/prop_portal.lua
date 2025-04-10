-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portals
-- Original code: Mee
-- ----------------------------------------------------------------------------
AddCSLuaFile()

ENT.Type = "anim"
ENT.Spawnable    = false
ENT.Contents = MASK_OPAQUE_AND_NPCS

function ENT:SetupDataTables()
	self:NetworkVar("Bool", "Activated")
	self:NetworkVar("Bool", "PlacedByMap")
	self:NetworkVar("Entity", "LinkedPartnerInternal")
	self:NetworkVar("Vector", "SizeInternal")
	self:NetworkVar("Int", "SidesInternal")
	self:NetworkVar("Int", "Type")
	self:NetworkVar("Int", "LinkageGroup")
	self:NetworkVar("Float", "OpenTime")
	self:NetworkVar("Float", "StaticTime")
	self:NetworkVar("Vector", "ColorVectorInternal")
	self:NetworkVar("Vector", "ColorVector01Internal")

	if SERVER then
		if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
			self:SetSize(Vector(PORTAL_HEIGHT / 2, PORTAL_WIDTH / 2, 8))
		else
			self:SetSize(Vector(PORTAL_HEIGHT / 2, PORTAL_WIDTH / 2, 7))
		end
		self:SetColorVectorInternal(Vector(255,255,255))
		self:SetPlacedByMap(true)
	end

	self:NetworkVarNotify("Activated", self.OnActivated)
end

-- custom size for portal
function ENT:SetSize(n)
	self:SetSizeInternal(n)
	self:UpdatePhysmesh(n)
end

function ENT:SetRemoveExit(bool)
	self.PORTAL_REMOVE_EXIT = bool
end

function ENT:GetRemoveExit(bool)
	return self.PORTAL_REMOVE_EXIT
end

function ENT:GetSize()
	return self:GetSizeInternal()
end

local outputs = {
	["OnEntityTeleportFromMe"] = true,
	["OnEntityTeleportToMe"] = true,
	["OnPlayerTeleportFromMe"] = true,
	["OnPlayerTeleportToMe"] = true,
}

if SERVER then
	function ENT:KeyValue(k, v)
		if k == "Activated" then
			self:SetActivated(tobool(v))
		elseif k == "LinkageGroupID" then
			self:SetLinkageGroup(tonumber(v))
		elseif k == "HalfWidth" then
			local value = tonumber(v) > 0 and tonumber(v) or PORTAL_WIDTH / 2

			local size = self:GetSize()
			if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
				self:SetSize(Vector(size.x, value, 8))
			else
				self:SetSize(Vector(size.x, value, 7))
			end
		elseif k == "HalfHeight" then
			local value = tonumber(v) > 0 and tonumber(v) or PORTAL_HEIGHT / 2

			local size = self:GetSize()
			if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
				self:SetSize(Vector(value, size.y, 8))
			else
				self:SetSize(Vector(value, size.y, 7))
			end
		elseif k == "PortalTwo" then
			self:SetType(tonumber(v))
		elseif outputs[key] then
			self:StoreOutput(key, value)
		end
	end

	function ENT:AcceptInput(name, activator, caller, data)
		name = name:lower()

		if name == "setactivatedstate" then
			self:SetActivated(tobool(data))
			PortalManager.SetPortal(self:GetLinkageGroup(), self)
		elseif name == "setname" then
			self:SetName(data)
		elseif name == "fizzle" then
			self:Fizzle()
		elseif name == "setlinkagegroupid" then
			self:SetLinkageGroup(tonumber(v))
		end
	end
end

local function incrementPortal(ent)
	if CLIENT then
		local size = ent:GetSize()
		ent:SetRenderBounds(-size, size)
	end
	PortalManager.PortalIndex = PortalManager.PortalIndex + 1
end

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		local angles = self:GetAngles() + Angle(90, 0, 0)
		angles:RotateAroundAxis(angles:Up(), 180)

		self:SetColor()
		self:SetAngles(angles)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)

		if not PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
			self:SetPos(self:GetPos() + self:GetAngles():Up() * 7.1)
		end

		PortalManager.PortalIndex = PortalManager.PortalIndex + 1
	end

	self:UpdatePhysmesh()

	if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
		if SERVER and self:GetPlacedByMap() then
			self:BuildPortalEnvironment()
		end
	end
	
	-- Override portal in LinkageGroup
	PortalManager.SetPortal(self:GetLinkageGroup(), self)
	PortalManager.Portals[self] = true
end

if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
	function ENT:BuildPortalEnvironment()
		self.__portalenvironmentphymesh = ents.Create("__portalenvironmentphymesh")
		self.__portalenvironmentphymesh:SetPos(self:GetPos())
		self.__portalenvironmentphymesh:SetPortalAngles(self:GetAngles())
		self.__portalenvironmentphymesh:Spawn()
	end
end

function ENT:OnRemove()
	PortalManager.PortalIndex = math.max(PortalManager.PortalIndex - 1, 0)
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetLinkedPartner())
	end
	
	if CLIENT and IsValid(self.RingParticle) then
		self.RingParticle:StopEmissionAndDestroyImmediately()
	end

	PortalManager.Portals[self] = nil
end

if CLIENT then
	local stencilHole = Material("models/portals/portal_stencil_hole")
	local ghostTexture = CreateMaterial("portal-ghosting", "UnlitGeneric", {
		["$basetexture"] = "models/portals/dummy-gray",
		["$nocull"] = 1,
		["$model"] = 1,
		["$alpha"] = 1,
		["$translucent"] = 1,
		["$vertexalpha"] = 1,
		["$vertexcolor"] = 1,
	})

	net.Receive(GP2.Net.SendPortalClose, function()
		local pos = net.ReadVector()
		local angle = net.ReadAngle()
		local color = net.ReadVector()

		local forward, right, up = angle:Forward(), angle:Right(), angle:Up()
	
		local particle = CreateParticleSystemNoEntity("portal_close", pos, angle)
		if IsValid(particle) then
			particle:SetControlPoint(0, pos)
			particle:SetControlPointOrientation(0, right, forward, up)
			particle:SetControlPoint(2, color)
		end
	end)
	

	local function getRenderMesh()
		if not PortalRendering.PortalMeshes[4] then
			PortalRendering.PortalMeshes[4] = { Mesh(), Mesh() }

			local invMeshTable = {}
			local meshTable = {}

			local corners = {
				Vector(-1, -1, -1),
				Vector(1, -1, -1),
				Vector(1, 1, -1),
				Vector(-1, 1, -1)
			}

			local uv = {
				Vector(0, 1),
				Vector(1, 1),
				Vector(1, 0),
				Vector(0, 0)
			}

			for i = 1, 4 do
				table.insert(meshTable, { pos = corners[i % 4 + 1], u = uv[i % 4 + 1].y, v = 1 - uv[i % 4 + 1].x })
				table.insert(meshTable, { pos = Vector(0, 0, -1), u = 0.5, v = 0.5 })
				table.insert(meshTable, { pos = corners[i], u = uv[i].y, v = 1 - uv[i].x })
			end

			for i = 1, 4 do
				table.insert(invMeshTable, { pos = corners[i], u = uv[i].y, v = 1 - uv[i].x })
				table.insert(invMeshTable, { pos = Vector(0, 0, -1), u = 0.5, v = 0.5 })
				table.insert(invMeshTable, { pos = corners[i % 4 + 1], u = uv[i % 4 + 1].y, v = 1 - uv[i % 4 + 1].x })
			end

			PortalRendering.PortalMeshes[4][1]:BuildFromTriangles(meshTable)
			PortalRendering.PortalMeshes[4][2]:BuildFromTriangles(invMeshTable)
		end

		return PortalRendering.PortalMeshes[4][2], PortalRendering.PortalMeshes[4][1]
	end
	
	
	function ENT:Draw()
		if not self:GetActivated() then return end

		if not self.RENDER_MATRIX then
			self.RENDER_MATRIX = Matrix()
		end

		debugoverlay.Text(self:GetPos(), self:GetLinkageGroup(), 0.1)

		if halo.RenderedEntity() == self then return end
		local render = render
		local cam = cam
		local size = self:GetSize()
		local renderMesh = getRenderMesh()

		if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
			if self.RENDER_MATRIX:GetTranslation() ~= self:GetPos() or (self.RENDER_MATRIX:GetScale().x ~= size.x and self.RENDER_MATRIX:GetScale().y ~= size.y) then
				self.RENDER_MATRIX:Identity()
				self.RENDER_MATRIX:SetTranslation(self:GetPos() + self:GetAngles():Up() * 8)
				self.RENDER_MATRIX:SetAngles(self:GetAngles())
				self.RENDER_MATRIX:SetScale(size * 0.999)
				size.z = -0.5
				self:SetRenderBounds(-size, size)
	
				size[3] = 0
			end
		else
			if self.RENDER_MATRIX:GetTranslation() ~= self:GetPos() or self.RENDER_MATRIX:GetScale() != size then
				self.RENDER_MATRIX:Identity()
				self.RENDER_MATRIX:SetTranslation(self:GetPos())
				self.RENDER_MATRIX:SetAngles(self:GetAngles())
				self.RENDER_MATRIX:SetScale(size * 0.999)
				
				self:SetRenderBounds(-size, size)
	
				size[3] = 0
			end
		end

		-- Try to build gradient texture for current color
		-- to override color - without shaders :( 
		local portalOverlay = PortalRendering.ValidateAndSetRingRT(self)

		-- No PortalOpenAmount proxy
		-- because it uses mesh rather entity's model
		stencilHole:SetFloat("$portalopenamount", self:GetOpenAmount())
		portalOverlay:SetFloat("$portalopenamount", self:GetOpenAmount())
		portalOverlay:SetFloat("$time", CurTime())
		
		if not PortalRendering.Rendering and IsValid(self:GetLinkedPartner()) then
			portalOverlay:SetFloat("$portalstatic", self:GetStaticAmount())
		else
			portalOverlay:SetFloat("$portalstatic", 1)
		end

		--
		-- Render portal view:
		--	- only when it's not inside portal view
		--	- there's linked partner
		--	- should render (in FOV, distance is less than threshold)
		--
		if not (PortalRendering.Rendering or not IsValid(self:GetLinkedPartner()) or not PortalManager.ShouldRender(self, EyePos(), EyeAngles(), PortalRendering.GetDrawDistance())) then
			render.ClearStencil()
			render.SetStencilEnable(true)
			render.SetStencilWriteMask(255)
			render.SetStencilTestMask(255)
			render.SetStencilReferenceValue(1)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetMaterial(stencilHole)

			-- draw inside of portal
			cam.PushModelMatrix(self.RENDER_MATRIX)
				renderMesh:Draw()
			cam.PopModelMatrix()

			-- draw the actual portal texture
			local portalmat = PortalRendering.PortalMaterials
			render.SetMaterial(portalmat[self.PORTAL_RT_NUMBER or 1])
			render.SetStencilCompareFunction(STENCIL_EQUAL)
				render.DrawScreenQuadEx(0, 0, ScrW(), ScrH())
			render.SetStencilEnable(false)
		end

		--
		-- Render border material
		-- previously I set open/static values for it
		-- Each material is local to entity
		--
		render.SetMaterial(portalOverlay)
		cam.PushModelMatrix(self.RENDER_MATRIX)
			renderMesh:Draw()
		cam.PopModelMatrix()
		
		-- 
		-- Render the ring particle only not in portal view
		-- after everything
		--
		if not PortalRendering.Rendering and IsValid(self.RingParticle) then
			self.RingParticle:Render()
		end
	end

	function ENT:DrawGhost()
		local renderMesh, renderMesh2 = getRenderMesh()
		local portalType = self:GetType()

		--
		-- Render portal ghosting
		-- Uses stencils too
		-- rendered from render.lua in PostDrawOpaqueRenderables
		--
		if not PortalRendering.Rendering and PortalRendering.GetShowGhosting() then
			render.SetStencilWriteMask( 255 )
			render.SetStencilTestMask( 255 )
			render.SetStencilReferenceValue( 1 )
			render.SetStencilCompareFunction( STENCIL_ALWAYS )
			render.SetStencilPassOperation( STENCIL_KEEP )
			render.SetStencilFailOperation( STENCIL_KEEP )
			render.SetStencilZFailOperation( STENCIL_KEEP )
			render.ClearStencil()

			render.SetStencilEnable( true )

			render.SetStencilReferenceValue( 1 )
			render.SetStencilCompareFunction( STENCIL_ALWAYS )
			render.SetStencilZFailOperation( STENCIL_REPLACE )

			render.SetColorMaterial()
			render.OverrideColorWriteEnable(true, false)
			cam.PushModelMatrix(self.RENDER_MATRIX)
				renderMesh:Draw()
				renderMesh2:Draw()
			cam.PopModelMatrix()    
			render.OverrideColorWriteEnable(false, false)

			render.SetStencilCompareFunction(STENCIL_EQUAL)

			ghostTexture:SetVector("$color", self:GetColorVector01Internal())

			render.SetMaterial(ghostTexture)
			cam.IgnoreZ(true)
			cam.PushModelMatrix(self.RENDER_MATRIX)
				renderMesh:Draw()
				renderMesh2:Draw()
			cam.PopModelMatrix() 
			cam.IgnoreZ(false)
			render.SetBlend(1)

			render.SetStencilEnable(false)
		end		
	end

	-- hacky bullet fix
	if game.SinglePlayer() then
		function ENT:TestCollision(startpos, delta, isbox, extents, mask)
			if bit.band(mask, CONTENTS_GRATE) ~= 0 then return true end
		end
	end
end

function ENT:UpdatePhysmesh()
	if not PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
		self:PhysicsInit(6)
		if self:GetPhysicsObject():IsValid() then
			local finalMesh = {}
			local size = self:GetSize()
			local sides = 8
			local angleMul = 360 / sides
			local degreeOffset = (sides * 90 + (sides % 4 ~= 0 and 0 or 45)) * (math.pi / 180)
			for side = 1, sides do
				local sidea = math.rad(side * angleMul) + degreeOffset
				local sidex = math.sin(sidea)
				local sidey = math.cos(sidea)
				local side1 = Vector(sidex, sidey, -1)
				local side2 = Vector(sidex, sidey,  0)
				table.insert(finalMesh, side1 * size)
				table.insert(finalMesh, side2 * size)
			end
			self:PhysicsInitConvex(finalMesh)
			self:EnableCustomCollisions(true)
			self:GetPhysicsObject():EnableMotion(false)
			self:GetPhysicsObject():SetContents(MASK_OPAQUE_AND_NPCS)
		else
			self:PhysicsDestroy()
			self:EnableCustomCollisions(false)
			print("Failure to create a portal physics mesh " .. self:EntIndex())
		end
	else
		self:PhysicsInit(6) -- Initialize physics as a solid
		if self:GetPhysicsObject():IsValid() then
			local size = self:GetSize() * 2
	
			-- Calculate the bounds for the mesh
			local x0, x1 = -size.x / 2, size.x / 2
			local y0, y1 = -size.y / 2, size.y / 2
			local z0, z1 = -size.z, size.z
	
			-- Define the convex quad mesh
			local mesh = {
				Vector(x0, y0, z0),
				Vector(x0, y0, z1),
				Vector(x0, y1, z0),
				Vector(x0, y1, z1),
				Vector(x1, y0, z0),
				Vector(x1, y0, z1),
				Vector(x1, y1, z0),
				Vector(x1, y1, z1)
			}
	
			self:PhysicsInitConvex(mesh)
		else
			self:PhysicsDestroy() -- Cleanup on failure
		end
	end
end

function ENT:OnPhysgunPickup(ply, ent)
    return false
end

function ENT:OnPhysgunDrop(ply, ent)
    return false
end

function ENT:GetOpenAmount()
	local currentTime = CurTime()
	local elapsedTime = currentTime - self:GetOpenTime()
	elapsedTime = math.min(elapsedTime, PORTAL_OPEN_DURATION)
	local progress = elapsedTime / PORTAL_OPEN_DURATION
	return progress
end

function ENT:GetStaticAmount()
	local currentTime = CurTime()
	local elapsedTime = currentTime - self:GetStaticTime()
	elapsedTime = math.min(elapsedTime, PORTAL_STATIC_DURATION)
	local progress = elapsedTime / PORTAL_STATIC_DURATION
	return 1 - progress
end

if CLIENT then
	function ENT:Think()
		PropPortal.AddToRenderList(self)

		if not IsValid(self.RingParticle) then
			-- they're lagging
			self.RingParticle = CreateParticleSystem(self, self:GetType() == PORTAL_TYPE_SECOND and "portal_edge_reverse" or "portal_edge", PATTACH_CUSTOMORIGIN)
			
			if IsValid(self.RingParticle) then
				self.RingParticle:StartEmission()
				self.RingParticle:SetShouldDraw(false)
			end
		else
			if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
				self.RingParticle:SetControlPoint(0, self:GetPos())
			else
				self.RingParticle:SetControlPoint(0, self:GetPos() - self:GetAngles():Up() * 7)
			end

			-- Messed up axes in Seamless Portals
			-- right is forward
			-- forward is right
			-- up is same
			local angles = self:GetAngles()
			local fwd, right, up = angles:Forward(), angles:Right(), angles:Up()
			self.RingParticle:SetControlPointOrientation(0, right, fwd, up)
			
			if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
				self.RingParticle:SetControlPoint(7, self:GetColorVector())
			else
				self.RingParticle:SetControlPoint(7, self:GetColorVector() * 0.4)
			end
		end

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
			phys:SetMaterial("glass")
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())
		elseif self:GetVelocity() == Vector() then
			self:UpdatePhysmesh()
		end
	end

	hook.Add("NetworkEntityCreated", "seamless_portal_init", function(ent)
		if ent:GetClass() == "prop_portal" then
			ent.RENDER_MATRIX = Matrix()
			timer.Simple(0, function()
				incrementPortal(ent)
			end)
		end
	end)
end

function ENT:Fizzle()
	net.Start(GP2.Net.SendPortalClose)
		net.WriteVector(self:GetPos())
		net.WriteAngle(self:GetAngles())
		net.WriteVector(self:GetColorVector() * 0.1)
	net.Broadcast()

	EmitSound(self:GetType() == PORTAL_TYPE_SECOND and "Portal.close_red" or "Portal.close_blue", self:GetPos())

	self:Remove()
end

function ENT:OnActivated(name, old, new)
	if SERVER then
		self:SetOpenTime(CurTime())
		
		if new then
			self:EmitSound(self:GetType() == PORTAL_TYPE_SECOND and "Portal.open_red" or "Portal.open_blue")
		end
	end
	
	-- Override portal in LinkageGroup after activation change
	PortalManager.SetPortal(self:GetLinkageGroup(), self)
end

function ENT:SetLinkedPartner(partner)
	if partner:GetClass() ~= self:GetClass() then
		return
	end

	if not partner:GetActivated() then 
		return 
	end
	
	partner:SetStaticTime(CurTime())
	self:SetStaticTime(CurTime())
	self:SetLinkedPartnerInternal(partner)
	partner:SetLinkedPartnerInternal(self)	

	GP2.Print("Setting partner for " .. tostring(partner) .. " on portal " .. tostring(self))
end

function ENT:GetLinkedPartner()
	return self:GetLinkedPartnerInternal()
end

function ENT:GetColorVector()
	return self:GetColorVectorInternal()
end

--- Sets portal color (vector and color version)
---@param r number: red component
---@param g number: green component
---@param b number: blue component
function ENT:SetPortalColor(r, g, b)
	self:SetColorVectorInternal(Vector(r, g, b))
	self:SetColorVector01Internal(Vector(r * 0.5 / 255, g * 0.5 / 255, b * 0.5 / 255))
end