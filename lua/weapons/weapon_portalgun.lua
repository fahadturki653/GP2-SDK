-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portal gun
-- ----------------------------------------------------------------------------

AddCSLuaFile()
SWEP.Slot = 0
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Spawnable = true

SWEP.BobScale = 0 // Required for custom viewbob

SWEP.ViewModel = "models/weapons/v_portalgun.mdl"
SWEP.WorldModel = "models/weapons/w_portalgun.mdl"
SWEP.ViewModelFOV = 50
SWEP.Automatic = true

SWEP.Primary.Ammo = "None"
SWEP.Primary.Automatic = true
SWEP.Secondary.Ammo = "None"
SWEP.Secondary.Automatic = true

SWEP.AutoSwitchFrom = true
SWEP.AutoSwitchTo = true

SWEP.PrintName = "Portal Gun"
SWEP.Category = "Portal 2"

PrecacheParticleSystem("portal_projectile_stream")
PrecacheParticleSystem("portal_badsurface")
PrecacheParticleSystem("portal_success")

local glow1 = Material("particle/particle_glow_05")

PORTAL_PLACEMENT_FAILED = 0
PORTAL_PLACEMENT_SUCCESFULL = 1
PORTAL_PLACEMENT_BAD_SURFACE = 2
PORTAL_PLACEMENT_UNKNOWN_SURFACE = 3
PORTAL_PLACEMENT_FIZZLER_HIT = 4

local vector_origin = Vector(0,0,0)

if SERVER then
	CreateConVar("gp2_portal_placement_never_fail", "0", FCVAR_CHEAT + FCVAR_NOTIFY,
		"Can portal be placed on every surface?")
end

concommand.Add("gp2_change_linkage_group_id", function(ply, cmd, args)
	if SERVER then
		local wep = ply:GetActiveWeapon()

		if IsValid(wep) then
			if wep:GetClass() == "weapon_portalgun" then
				wep:SetLinkageGroup(tonumber(args[1]) or 0)
			end
		end
	end
end)

local gp2_portal_placement_never_fail = GetConVar("gp2_portal_placement_never_fail")

if SERVER then
	concommand.Add("upgrade_portalgun", function(ply, cmd, args)
		ply:Give("weapon_portalgun")

		for _, weapon in ipairs(ply:GetWeapons()) do
			if weapon:GetClass() == "weapon_portalgun" then
				weapon:UpdatePortalGun()
			end
		end
	end)

	concommand.Add("upgrade_potatogun", function(ply, cmd, args)
		for _, weapon in ipairs(ply:GetWeapons()) do
			if weapon:GetClass() == "weapon_portalgun" then
				weapon:UpdatePotatoGun(true)
			end
		end
	end)
else
	CreateClientConVar("gp2_portal_color1", "2 114 210", true, true, "Color for Portal 1")
	CreateClientConVar("gp2_portal_color2", "210 114 2", true, true, "Color for Portal 2")

	net.Receive(GP2.Net.SendPortalPlacementNotPortalable, function()
		local hitPos = net.ReadVector()
		local hitAngle = net.ReadAngle()
		local color = net.ReadVector()

		local forward, right, up = hitAngle:Forward(), hitAngle:Right(), hitAngle:Up()

		local particle = CreateParticleSystemNoEntity("portal_badsurface", hitPos, hitAngle)
		if IsValid(particle) then
			particle:SetControlPoint(0, hitPos)
			particle:SetControlPointOrientation(0, up, right, forward)
			particle:SetControlPoint(2, color)
		end
	end)

	net.Receive(GP2.Net.SendPortalPlacementSuccess, function()
		local hitPos = net.ReadVector()
		local hitAngle = net.ReadAngle()
		local color = net.ReadVector()

		local forward, right, up = hitAngle:Forward(), hitAngle:Right(), hitAngle:Up()

		local particle = CreateParticleSystemNoEntity("portal_success", hitPos, hitAngle)
		if IsValid(particle) then
			particle:SetControlPoint(0, hitPos)
			particle:SetControlPointOrientation(0, right, forward, up)
			particle:SetControlPoint(2, color)
		end
	end)
end

local function getSurfaceAngle(owner, norm)
	local fwd = owner:GetAimVector()
	local rgh = fwd:Cross(norm)
	fwd:Set(norm:Cross(rgh))
	return fwd:AngleEx(norm)
end

local gtCheck =
{
	["player"]                  = true,
	["prop_portal"]             = true,
	["prop_weighted_cube"]      = true,
	["grenade_helicopter"]      = true,
	["npc_portal_turret_floor"] = true,
	["prop_monster_box"]        = true,
	["npc_*"]                   = true,
}

local function gtCheckFunc(e)
	if not IsValid(e) then return end
	return ! gtCheck[e:GetClass()]
end

local cleanserCheck = {
	["trigger_portal_cleanser"] = true
}

local rayHull = Vector(0.01, 0.01, 0.01)

local function setPortalPlacementNew(owner, portal)
	local ang = Angle() -- The portal angle
	local siz = portal:GetSize()
	local pos = owner:GetShootPos()
	local aim = owner:GetAimVector()

	local tr = PortalManager.TraceLine({
		start  = pos,
		endpos = pos + aim * 99999,
		filter = gtCheckFunc,
		mask   = MASK_SHOT_PORTAL
	})

	debugoverlay.Cross(tr.HitPos, 16, 0.5)

	local alongRay = ents.FindAlongRay(tr.StartPos, tr.HitPos, -rayHull, rayHull)

	for i = 1, #alongRay do
		local ent = alongRay[i]

		-- Check if the entity is in the 'cleanserCheck' table
		if cleanserCheck[ent:GetClass()] then
			if not ent:GetEnabled() then continue end

			local rayDirection = pos + aim * 99999

			-- Intersect ray with collision bounds
			local boundsMin, boundsMax = ent:GetCollisionBounds()
			local hitPos = util.IntersectRayWithOBB(pos, rayDirection, ent:GetPos(), ent:GetAngles(), boundsMin,
				boundsMax)

			if hitPos then
				tr.HitPos = hitPos
			end

			return PORTAL_PLACEMENT_FIZZLER_HIT, tr
		end
	end

	if
		not gp2_portal_placement_never_fail:GetBool() and
		(
			not tr.Hit
			or IsValid(tr.Entity)
			or tr.HitTexture == "**studio**"
			--or bit.band(tr.DispFlags, DISPSURF_WALKABLE) ~= 0
			or bit.band(tr.SurfaceFlags, SURF_NOPORTAL) ~= 0
			or bit.band(tr.SurfaceFlags, SURF_TRANS) ~= 0
		)
	then
		return PORTAL_PLACEMENT_BAD_SURFACE, tr
	end

	if tr.HitSky then
		return PORTAL_PLACEMENT_UNKNOWN_SURFACE, tr
	end

	-- Align portals on 45 degree surfaces
	if math.abs(tr.HitNormal:Dot(ang:Up())) < 0.71 then
		ang:Set(tr.HitNormal:Angle())
		ang:RotateAroundAxis(ang:Right(), -90)
		ang:RotateAroundAxis(ang:Up(), 180)
	else -- Place portals on any surface and angle
		ang:Set(getSurfaceAngle(owner, tr.HitNormal))
	end

	-- Extrude portal from the ground
	local af, au = ang:Forward(), ang:Right()
	local angTab = {
		af * siz[1],
		-af * siz[1],
		au * siz[2],
		-au * siz[2]
	}

	for i = 1, 4 do
		local extr = PortalManager.TraceLine({
			start  = tr.HitPos + tr.HitNormal,
			endpos = tr.HitPos + tr.HitNormal - angTab[i],
			filter = ents.GetAll(),
		})

		if extr.Hit then
			tr.HitPos = tr.HitPos + angTab[i] * (1 - extr.Fraction)
		end
	end

	pos = tr.HitPos

	return PORTAL_PLACEMENT_SUCCESFULL, tr, pos, ang
end

local function setPortalPlacementOld(owner, portal)
	local ang = Angle() -- The portal angle
	local siz = portal:GetSize()
	local pos = owner:GetShootPos()
	local aim = owner:GetAimVector()
	local mul = siz[3] * 1.1

	local tr = PortalManager.TraceLine({
		start  = pos,
		endpos = pos + aim * 99999,
		filter = gtCheckFunc,
		mask   = MASK_SHOT_PORTAL
	})

	local alongRay = ents.FindAlongRay(tr.StartPos, tr.HitPos, -rayHull, rayHull)

	for i = 1, #alongRay do
		local ent = alongRay[i]

		-- Check if the entity is in the 'cleanserCheck' table
		if cleanserCheck[ent:GetClass()] then
			if not ent:GetEnabled() then continue end

			local rayDirection = pos + aim * 99999

			-- Intersect ray with collision bounds
			local boundsMin, boundsMax = ent:GetCollisionBounds()
			local hitPos = util.IntersectRayWithOBB(pos, rayDirection, ent:GetPos(), ent:GetAngles(), boundsMin,
				boundsMax)

			if hitPos then
				tr.HitPos = hitPos
			end

			return PORTAL_PLACEMENT_FIZZLER_HIT, tr
		end
	end

	if
		not gp2_portal_placement_never_fail:GetBool() and
		(
			not tr.Hit
			or IsValid(tr.Entity)
			or tr.HitTexture == "**studio**"
			--or bit.band(tr.DispFlags, DISPSURF_WALKABLE) ~= 0
			or bit.band(tr.SurfaceFlags, SURF_NOPORTAL) ~= 0
			or bit.band(tr.SurfaceFlags, SURF_TRANS) ~= 0
		)
	then
		return PORTAL_PLACEMENT_BAD_SURFACE, tr
	end

	if tr.HitSky then
		return PORTAL_PLACEMENT_UNKNOWN_SURFACE, tr
	end

	-- Align portals on 45 degree surfaces
	if math.abs(tr.HitNormal:Dot(ang:Up())) < 0.71 then
		ang:Set(tr.HitNormal:Angle())
		ang:RotateAroundAxis(ang:Right(), -90)
		ang:RotateAroundAxis(ang:Up(), 180)
	else -- Place portals on any surface and angle
		ang:Set(getSurfaceAngle(owner, tr.HitNormal))
	end

	-- Extrude portal from the ground
	local af, au = ang:Forward(), ang:Right()
	local angTab = {
		af * siz[1],
		-af * siz[1],
		au * siz[2],
		-au * siz[2]
	}

	for i = 1, 4 do
		local extr = PortalManager.TraceLine({
			start  = tr.HitPos + tr.HitNormal,
			endpos = tr.HitPos + tr.HitNormal - angTab[i],
			filter = ents.GetAll(),
		})

		if extr.Hit then
			tr.HitPos = tr.HitPos + angTab[i] * (1 - extr.Fraction)
		end
	end

	pos:Set(tr.HitNormal)
	pos:Mul(mul)
	pos:Add(tr.HitPos)

	return PORTAL_PLACEMENT_SUCCESFULL, tr, pos, ang
end

function SWEP:Initialize()
	self:SetDeploySpeed(1)
	self:SetHoldType("shotgun")

	if SERVER then
		self.NextIdleTime = 0
	end
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", "IsPotatoGun")
	self:NetworkVar("Bool", "CanFirePortal1")
	self:NetworkVar("Bool", "CanFirePortal2")
	self:NetworkVar("Int", "LinkageGroup")
	self:NetworkVar("Entity", "LastPlacedPortal")
	self:NetworkVar("Entity", "EntityInUse")

	if SERVER then
		self:SetCanFirePortal1(true) -- default only portal 1
	end
end

function SWEP:Deploy()
	if CLIENT then return end


	if not self.GotCustomLinkageGroup then
		self:SetLinkageGroup(self:GetOwner():EntIndex() - 1)
	end

	if self:GetIsPotatoGun() then
		self:SendWeaponAnim(ACT_VM_DEPLOY)
		self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
		self:SetBodygroup(1, 1)
	end

	local owner = self:GetOwner()
	local vm0 = owner:GetViewModel(0)
	local vm1 = owner:GetViewModel(1)

	if not IsValid(self.HoldSound) then
		local filter = RecipientFilter()
		filter:AddPlayer(owner)

		self.HoldSound = CreateSound(self, "PortalPlayer.ObjectUse", filter)
	end

	local seq = vm1:SelectWeightedSequence(ACT_VM_RELEASE)

	if IsValid(vm1) then
		vm1:SetWeaponModel(self:GetWeaponViewModel(), NULL)
		if self:GetIsPotatoGun() then
			vm1:SetBodygroup(1, 1)
		end
	end

	-- Previously we held object, use other deploy sequence
	if self.GotEntityInUse then
		self:StopSound("PortalPlayer.ObjectUse")

		-- No operator stacks
		self:EmitSound("PortalPlayer.ObjectUseStop", 0)
		self:SetEntityInUse(NULL)
		self.GotEntityInUse = false

		timer.Simple(0, function()
			vm0:SendViewModelMatchingSequence(12)
		end)
	end


	return true
end

function SWEP:Holster(arguments)
	if SERVER then
		local owner = self:GetOwner()
		local vm1 = owner:GetViewModel(1)

		if not IsValid(owner) then
			return
		end

		if IsValid(vm1) then
			vm1:SetWeaponModel(self:GetWeaponViewModel(), self)
		end

		timer.Simple(0, function()
			if !IsValid(self) then return end // Stop erroring on death!
			print('Holster')

			if IsValid(vm1) and IsValid(owner:GetEntityInUse()) then
				vm1:SendViewModelMatchingSequence(self:SelectWeightedSequence(ACT_VM_PICKUP))
				self.GotEntityInUse = true
				self:EmitSound("PortalPlayer.ObjectUse", 0)
				self:SetEntityInUse(owner:GetEntityInUse())
			else
				vm1:SetWeaponModel(self:GetWeaponViewModel(), NULL)
				if self:GetIsPotatoGun() then
					vm1:SetBodygroup(1, 1)
				end
			end
		end)
	end

	return true
end

function SWEP:PrimaryAttack()
	if not SERVER then return end
	if not self:GetCanFirePortal1() then return end

	if not self:CanPrimaryAttack() then return end
	self:GetOwner():EmitSound("Weapon_Portalgun.fire_blue")

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	self.NextIdleTime = CurTime() + 0.5

	if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
		self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
	end

	self:PlacePortal(PORTAL_TYPE_FIRST, self:GetOwner())

	self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
	if not SERVER then return end
	if not self:GetCanFirePortal2() then return end

	if not self:CanPrimaryAttack() then return end
	self:GetOwner():EmitSound("Weapon_Portalgun.fire_red")

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	self.NextIdleTime = CurTime() + 0.5

	if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
		self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
	end

	self:PlacePortal(PORTAL_TYPE_SECOND, self:GetOwner())

	self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
end

function SWEP:ClearSpawn()
end

function SWEP:PlacePortal(type, owner)
	local r, g, b = 255, 255, 255

	if IsValid(owner) and owner:IsPlayer() then
		local colorConvar = owner:GetInfo("gp2_portal_color" .. type + 1)
		r, g, b = unpack((colorConvar or "255 255 255"):Split(" "))
	end

	local portal = ents.Create("prop_portal")
	if not IsValid(portal) then return end

	portal:SetPlacedByMap(false)
	portal:SetPortalColor(tonumber(r or 255), tonumber(g or 255), tonumber(b or 255))
	portal:SetType(type or 0)
	portal:SetLinkageGroup(self:GetLinkageGroup())
	local placementStatus, traceResult, pos, ang

	if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
		placementStatus, traceResult, pos, ang = setPortalPlacementNew(self:GetOwner(), portal) 
	else 
		placementStatus, traceResult, pos, ang = setPortalPlacementOld(self:GetOwner(), portal)
	end

	--local effectData = EffectData()
	--effectData:SetNormal(Vector(r, g, b)) -- color
	--effectData:SetOrigin(traceResult.StartPos)
	--effectData:SetStart(traceResult.HitPos)
	--effectData:SetEntity(owner)

	--util.Effect("portal_blast", effectData)

	if placementStatus == PORTAL_PLACEMENT_BAD_SURFACE
		or placementStatus == PORTAL_PLACEMENT_FIZZLER_HIT then
		net.Start(GP2.Net.SendPortalPlacementNotPortalable)
		net.WriteVector(traceResult.HitPos)
		net.WriteAngle(traceResult.HitNormal:Angle())
		net.WriteVector(portal:GetColorVector() * 0.5)
		net.Broadcast()

		EmitSound("Portal.fizzle_invalid_surface", traceResult.HitPos, self:EntIndex(), CHAN_AUTO, 1, 60)
		return
	elseif placementStatus == PORTAL_PLACEMENT_UNKNOWN_SURFACE then
		return
	end

	portal:SetActivated(true)
	portal:Spawn()
	portal:SetPos(pos)
	portal:SetAngles(ang)
	portal:SetPlacedByMap(false)
	if PORTAL_USE_NEW_ENVIRONMENT_SYSTEM then
		portal:BuildPortalEnvironment()
	end

	--- @type Player
	local player = owner

	self:SetLastPlacedPortal(portal)

	net.Start(GP2.Net.SendPortalPlacementSuccess)
	net.WriteVector(portal:GetPos())
	net.WriteAngle(portal:GetAngles())
	net.WriteVector(portal:GetColorVector() * 0.5)
	net.Broadcast()
end

function SWEP:Think()
	if SERVER then
		local owner = self:GetOwner()
		if not IsValid(owner) then return true end

		if owner:KeyPressed(IN_USE) then
			self:SendWeaponAnim(ACT_VM_FIZZLE)
			self:EmitSound("PortalPlayer.UseDeny")
			self.NextIdleTime = CurTime() + 0.5
		end

		if CurTime() > self.NextIdleTime and self:GetActivity() ~= ACT_VM_IDLE then
			self:SendWeaponAnim(ACT_VM_IDLE)
		end

		if self:GetEntityInUse() ~= owner:GetEntityInUse() then
			self:SetEntityInUse(owner:GetEntityInUse())
		end
	else
		if LocalPlayer():InVehicle() then
			self.ViewModelFOV = 35
		end
	end

	self:NextThink(CurTime())
	return true
end

if SERVER then
	function SWEP:UpdatePortalGun()
		self:SetCanFirePortal1(true)
		self:SetCanFirePortal2(true)
	end

	function SWEP:UpdatePotatoGun(into)
		self:SetCanFirePortal1(true)
		self:SetCanFirePortal2(true)

		self:SendWeaponAnim(ACT_VM_HOLSTER)
		self:SetIsPotatoGun(into)

		self:SetNextPrimaryFire(CurTime() + 3.5)
		self:SetNextSecondaryFire(CurTime() + 3.5)

		timer.Simple(2, function()
			self:SendWeaponAnim(ACT_VM_DRAW)
			if into then
				self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
				self:SetBodygroup(1, 1)
			else
				self:GetOwner():GetViewModel(0):SetBodygroup(1, 0)
				self:SetBodygroup(1, 0)
			end
		end)

		self.NextIdleTime = CurTime() + 5
	end
end

function SWEP:OnRemove()
	self:ClearPortals()
end

function SWEP:ClearPortals()
	local portal1 = PortalManager.GetLinkageGroup(self:GetLinkageGroup())[PORTAL_TYPE_FIRST]
	local portal2 = PortalManager.GetLinkageGroup(self:GetLinkageGroup())[PORTAL_TYPE_SECOND]

	if SERVER then
		if IsValid(portal1) and self:GetCanFirePortal1() then
			portal1:Fizzle()
		end

		if IsValid(portal2) and self:GetCanFirePortal2() then
			portal2:Fizzle()
		end
	end

	self:SetLastPlacedPortal(NULL)
end

function SWEP:ViewModelDrawn(vm)
	local owner = vm:GetOwner()
	local vm0 = owner:GetViewModel(0)
	local vm1 = owner:GetViewModel(1)

	if not self.TopLightFirstPersonAttachment then
		self.TopLightFirstPersonAttachment = vm0:LookupAttachment("Body_light")
	end

	if not self.TopLightFirstPerson2Attachment then
		self.TopLightFirstPerson2Attachment = vm1:LookupAttachment("Body_light")
	end

	local lastPlacedPortal = self:GetLastPlacedPortal()
	local lightColor

	if not IsValid(lastPlacedPortal) then
		lightColor = vector_origin
	else
		lightColor = lastPlacedPortal:GetColorVector() * 0.2
		lightColor.g = lightColor.g * 1.05
	end

	if self.TopLightColor ~= lightColor then
		-- Set color to current portal placed
		if IsValid(self.TopLightFirstPerson) then
			self.TopLightFirstPerson:SetControlPoint(1, lightColor)
		end

		if IsValid(self.TopLightFirstPerson2) then
			self.TopLightFirstPerson2:SetControlPoint(1, lightColor)
		end

		self.TopLightColor = lightColor
	end

	if not self.TopLightColor then
		self.TopLightColor = Vector()
	end

	-- Top light particle (and beam)
	if not IsValid(self.TopLightFirstPerson) then
		self.TopLightFirstPerson = CreateParticleSystem(vm0, "portalgun_top_light_firstperson", PATTACH_POINT_FOLLOW,
			self.TopLightFirstPersonAttachment)
		if IsValid(self.TopLightFirstPerson) then
			self.TopLightFirstPerson:SetIsViewModelEffect(true)
			self.TopLightFirstPerson:SetShouldDraw(false)

			-- Beam particles
			self.TopLightFirstPerson:AddControlPoint(2, owner, PATTACH_CUSTOMORIGIN)
			self.TopLightFirstPerson:AddControlPoint(3, vm0, PATTACH_POINT_FOLLOW, "Beam_point1")
			self.TopLightFirstPerson:AddControlPoint(4, vm0, PATTACH_POINT_FOLLOW, "Beam_point5")
		end
	else
		if vm == vm0 then
			self.TopLightFirstPerson:Render()
		end
	end

	-- Top light particle (and beam) for second vm
	if not IsValid(self.TopLightFirstPerson2) then
		self.TopLightFirstPerson2 = CreateParticleSystem(vm1, "portalgun_top_light_firstperson", PATTACH_POINT_FOLLOW,
			self.TopLightFirstPerson2Attachment)
		if IsValid(self.TopLightFirstPerson2) then
			self.TopLightFirstPerson2:SetIsViewModelEffect(true)
			self.TopLightFirstPerson2:SetShouldDraw(false)

			-- Beam particles
			self.TopLightFirstPerson2:AddControlPoint(2, owner, PATTACH_CUSTOMORIGIN)
			self.TopLightFirstPerson2:AddControlPoint(3, vm1, PATTACH_POINT_FOLLOW, "Beam_point1")
			self.TopLightFirstPerson2:AddControlPoint(4, vm1, PATTACH_POINT_FOLLOW, "Beam_point5")
		end
	else
		if vm == vm1 then
			self.TopLightFirstPerson2:Render()
		end
	end

	if vm0:GetModel() != vm1:GetModel() then return end // Fix stupid holding particle bug

	-- Holding particle for second vm
	if vm == vm1 then
		if not self.FirstPersonMuzzleAttachment then
			self.FirstPersonMuzzleAttachment = vm1:LookupAttachment("muzzle")
		end

		if not self.FirstPersonMuzzleAttachment2 then
			self.FirstPersonMuzzleAttachment2 = vm1:LookupAttachment("muzzle")
		end

		self.HoldingParticleFirstPersonDieTime = self.HoldingParticleFirstPersonDieTime or CurTime() + 0.5

		if not IsValid(self.HoldingParticleFirstPerson) then
			self.HoldingParticleFirstPerson = CreateParticleSystem(vm1, "portalgun_beam_holding_FP", PATTACH_POINT_FOLLOW,
				self.FirstPersonMuzzleAttachment2)

			if IsValid(self.HoldingParticleFirstPerson) then
				self.HoldingParticleFirstPerson:AddControlPoint(1, vm1, PATTACH_POINT_FOLLOW, "Arm1_attach3")
				self.HoldingParticleFirstPerson:AddControlPoint(2, vm1, PATTACH_POINT_FOLLOW, "Arm2_attach3")
				self.HoldingParticleFirstPerson:AddControlPoint(3, vm1, PATTACH_POINT_FOLLOW, "Arm3_attach3")
				self.HoldingParticleFirstPerson:AddControlPoint(4, owner, PATTACH_CUSTOMORIGIN)
				self.HoldingParticleFirstPerson:SetControlPointEntity(4, vm1)
				--self.HoldingParticleFirstPerson:AddControlPoint(5, owner:GetEntityInUse(), PATTACH_ABSORIGIN_FOLLOW, 0)
				self.HoldingParticleFirstPersonDieTime = CurTime() + 0.5
			end
		elseif CurTime() > self.HoldingParticleFirstPersonDieTime then
			self.HoldingParticleFirstPerson:StopEmission()
			self.HoldingParticleFirstPerson = NULL
		end
	else
		if IsValid(self.HoldingParticleFirstPerson) then
			self.HoldingParticleFirstPerson:StopEmission(false, true)
			self.HoldingParticleFirstPerson = NULL
		end
	end
end

function SWEP:DrawWorldModel(studio)
	local lastPlacedPortal = self:GetLastPlacedPortal()
	local lightColor

	if not IsValid(lastPlacedPortal) then
		lightColor = vector_origin
	else
		lightColor = lastPlacedPortal:GetColorVector() * 0.2
		lightColor.g = lightColor.g * 1.05
	end

	if not self.TopLightThirdPersonAttachment then
		self.TopLightThirdPersonAttachment = self:LookupAttachment("Body_light")
	end

	if not self.TopLightColor then
		self.TopLightColor = Vector()
	end

	-- Top light particle (and beam) - world model
	if not IsValid(self.TopLightThirdPerson) then
		self.TopLightThirdPerson = CreateParticleSystem(self, "portalgun_top_light_thirdperson", PATTACH_POINT_FOLLOW,
			self.TopLightThirdPersonAttachment)
		if IsValid(self.TopLightThirdPerson) then
			self.TopLightThirdPerson:SetShouldDraw(false)

			-- Beam particles
			self.TopLightThirdPerson:AddControlPoint(2, self:GetOwner(), PATTACH_CUSTOMORIGIN)
			self.TopLightThirdPerson:AddControlPoint(3, self, PATTACH_POINT_FOLLOW, "Beam_point1")
			self.TopLightThirdPerson:AddControlPoint(4, self, PATTACH_POINT_FOLLOW, "Beam_point5")
		end
	else
		self.TopLightThirdPerson:Render()

		-- Set color to current portal placed
		-- TODO: Make portals recolorable, since this code sucks
		self.TopLightThirdPerson:SetControlPoint(1, lightColor)
		self.TopLightThirdPerson:SetControlPoint(0, self:GetAttachment(self.TopLightThirdPersonAttachment).Pos)

		if self.TopLightColor ~= lightColor then
			lightColor.x = lightColor.x * 0.5
			lightColor.y = lightColor.y * 0.5
			lightColor.z = lightColor.z * 0.5

			-- Set color to current portal placed
			self.TopLightThirdPerson:SetControlPoint(1, lightColor)

			self.TopLightColor = lightColor
		end
	end

	self:DrawModel(studio)
end

function SWEP:Reload()
	if CLIENT then return end

	local portal1 = PortalManager.GetLinkageGroup(self:GetLinkageGroup())[PORTAL_TYPE_FIRST]
	local portal2 = PortalManager.GetLinkageGroup(self:GetLinkageGroup())[PORTAL_TYPE_SECOND]

	if not (IsValid(portal1) or IsValid(portal2)) then
		return
	end

	self:ClearPortals()

	self:SendWeaponAnim(ACT_VM_FIZZLE)
	self.NextIdleTime = CurTime() + 0.5
end

// Viewbob Code, because why not? (Ported from P2ASW)
local g_lateralBob, g_verticalBob = 0,0
local HL2_BOB_CYCLE_MIN,HL2_BOB_CYCLE_MAX,HL2_BOB,HL2_BOB_UP = 1,.45,.002,.5
local bobtime,lastbobtime = 0,0

local function CalcViewmodelBob(self)
	local cycle = 0

	local plr = self:GetOwner():IsPlayer() && self:GetOwner()
	if !plr then return end

	local speed = plr:GetVelocity():Length()
	speed = math.Clamp(speed,-plr:GetMaxSpeed(), plr:GetMaxSpeed())
	local boboffset = math.Remap(speed,0, plr:GetMaxSpeed(), 0, 1)

	bobtime = bobtime + (CurTime()-lastbobtime)*boboffset
	lastbobtime = CurTime()

    // Vertical Bob
    cycle = bobtime - math.floor(bobtime/HL2_BOB_CYCLE_MAX)*HL2_BOB_CYCLE_MAX
	cycle = cycle / HL2_BOB_CYCLE_MAX

	if cycle < HL2_BOB_UP then
		cycle = math.pi * cycle / HL2_BOB_UP
	else
		cycle = math.pi+math.pi*(cycle-HL2_BOB_UP)/(1-HL2_BOB_UP)
	end

	g_verticalBob = speed*.005
	g_verticalBob = g_verticalBob*.3 + g_verticalBob*.7*math.sin(cycle)

	g_verticalBob = math.Clamp(g_verticalBob,-7,4)

    // Lateral Bob

	cycle = bobtime - math.floor(bobtime/HL2_BOB_CYCLE_MAX*2)*HL2_BOB_CYCLE_MAX*2
	cycle = cycle / (HL2_BOB_CYCLE_MAX*2)

	if cycle < HL2_BOB_UP then
		cycle = math.pi * cycle / HL2_BOB_UP
	else
		cycle = math.pi+math.pi*(cycle-HL2_BOB_UP)/(1-HL2_BOB_UP)
	end

	g_lateralBob = speed*.005
	g_lateralBob = g_lateralBob*.3 + g_lateralBob*.7*math.sin(cycle)
	g_lateralBob = math.Clamp(g_lateralBob,-7,4)
end

local function VectorMA(start,scale,dir,dest)
	dest.x = start.x + scale * dir.x
	dest.y = start.y + scale * dir.y
	dest.z = start.z + scale * dir.z
end

function SWEP:AddViewmodelBob(vm,origin,ang)
	local forward,right,up = ang:Forward(),ang:Right(),ang:Up()

	CalcViewmodelBob(self)

	/*local plr = self:GetOwner():IsPlayer() && self:GetOwner()
	if !plr then return end*/

	VectorMA(origin,g_verticalBob*.1,forward,origin)

	origin = origin + (g_verticalBob*.1*forward)

	VectorMA(origin,g_lateralBob*.8,right,origin)

	local rollAngle = g_verticalBob*.5
	local rotAxis = right:Cross(up):GetNormalized()
	local rotMatrix = ang
	rotMatrix:RotateAroundAxis(rotAxis,rollAngle)
	up = rotMatrix:Up()
	forward = rotMatrix:Forward()
	right = rotMatrix:Right()

	local pitchAngle = -g_verticalBob*.4
	rotAxis = right;
	rotMatrix:RotateAroundAxis(rotAxis,pitchAngle)
	up = rotMatrix:Up()
	forward = rotMatrix:Forward()

	local yawAngle = -g_lateralBob*.3
	rotAxis = up
	rotMatrix:RotateAroundAxis(rotAxis,yawAngle)
	forward = rotMatrix:Forward()

	ang = forward:AngleEx(up)

	return origin,ang
end

function SWEP:CalcViewModelView(vm,_,_,pos,ang)
	pos,ang = self:AddViewmodelBob(vm, pos, ang)

	return pos,ang
end