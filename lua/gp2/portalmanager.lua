-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Shared manager for portals
-- Holds portal indexes and linkage group infos, also helper functions
-- Original code: Mee
-- ----------------------------------------------------------------------------
AddCSLuaFile()

--- Everything related to portal logic
PortalManager = PortalManager or {}

-- array of portal in world
PortalManager.Portals = PortalManager.Portals or {}

-- the number of portals in the map
PortalManager.PortalIndex = PortalManager.PortalIndex or 0

--- Linkage groups
--- A table used to manage linkage between portals.
--- This structure is used to pair portals, where each entry consists
--- of two portals.
---
--- **Structure**:
--- - An indexed table where the key is a linkage group.
--- - Each value is a table containing exactly two elements (portals)
PortalManager.LinkageGroups = PortalManager.LinkageGroups or {
	[0] = { NULL, NULL },
}

function PortalManager.GetLinkageGroup(linkageGroup)
	if not PortalManager.LinkageGroups[linkageGroup] then
		PortalManager.LinkageGroups[linkageGroup] = { NULL, NULL }
	end
	return PortalManager.LinkageGroups[linkageGroup]
end

--- Write/rewrite portal in specified linkage group
--- @param linkageGroup integer linkage group
--- @param entity Entity portal
function PortalManager.SetPortal(linkageGroup, entity)
	if not IsValid(entity) or entity:GetClass() ~= "prop_portal" then
		return
	end

	-- Get type of portal
	local portalType = entity:GetType()

	-- Get opposite portal type
	local oppositePortalType = entity:GetType() == PORTAL_TYPE_FIRST and PORTAL_TYPE_SECOND or PORTAL_TYPE_FIRST

	-- Get portal in group
	--- @type Entity
	local portal = PortalManager.GetLinkageGroup(linkageGroup)[portalType]

	-- Get opposite portal in group
	local oppositePortal = PortalManager.GetLinkageGroup(linkageGroup)[oppositePortalType]
	
	GP2.Print("Setting portal for linkageGroup == " .. linkageGroup .. " to " .. tostring(entity) .. " (type " .. portalType .. ")")

	-- If some portal already occupied place in group
	-- fizzle it
	if IsValid(portal) and portal ~= entity then
		if SERVER then
			portal:Fizzle()
		end
	end

	-- If opposite portal exists
	-- link with it
	if IsValid(oppositePortal) then
		entity:SetLinkedPartner(oppositePortal)
	end

	-- If portal is activated then add it to group
	-- to prevent next
	if entity:GetActivated() then
		PortalManager.GetLinkageGroup(linkageGroup)[portalType] = entity
	end
end

function PortalManager.TransformPortal(a, b, pos, ang, offsetByThick)
	if !IsValid(a) or !IsValid(b) then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		editedPos = a:WorldToLocal(pos)

		if offsetByThick then
			editedPos = editedPos + a:GetAngles():Forward() * 7
		end

		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		
		editedPos = editedPos + b:GetUp() * 0.01 -- so you dont become trapped
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))
	end

	return editedPos, editedAng
end

PortalManager.TraceLine = util.TraceLine

--- Portal version of [util.TraceLine](https://wiki.facepunch.com/gmod/util.TraceLine)
--- @param data Trace
--- @return TraceResult result Result structure of [util.TraceLine](https://wiki.facepunch.com/gmod/util.TraceLine)
function PortalManager.TraceLinePortal(data, portalClassname)
	portalClassname = portalClassname or "prop_portal"

	local tr = PortalManager.TraceLine(data)
	if tr.Entity:IsValid() then
		if tr.Entity:GetClass() == portalClassname and IsValid(tr.Entity:GetLinkedPartner()) then
			local hitPortal = tr.Entity
			if tr.HitNormal:Dot(hitPortal:GetUp()) > 0.9 then
				local editeddata = table.Copy(data)
				local exitportal = hitPortal:GetLinkedPartner()
				editeddata.start = PortalManager.TransformPortal(hitPortal, exitportal, tr.HitPos)
				editeddata.endpos = PortalManager.TransformPortal(hitPortal, exitportal, data.endpos)
				editeddata.HitPortal = true
				-- filter the exit portal from being hit by the ray
				if isentity(data.filter) and data.filter:GetClass() ~= "player" then
					editeddata.filter = {data.filter, exitportal}
				else
					if istable(editeddata.filter) then
						table.insert(editeddata.filter, exitportal)
					else
						editeddata.filter = exitportal
					end
				end
				return PortalManager.TraceLine(editeddata)
			end
		end
		if data["WorldDetour"] then tr.Entity = game.GetWorld() end
	end
	return tr
end

--- Should portal be visible according following eye position, angles and distance to portal?
--- @param portal Entity Portal to check
--- @param eyePos Vector Eyes position
--- @param eyeAngle Angle Eyes angles
--- @param distance number Threshold distance 
--- @return boolean shouldRender Render that portal? 
function PortalManager.ShouldRender(portal, eyePos, eyeAngle, distance)
    -- Check if the portal is dormant
    if portal:IsDormant() then return false end
    
    local portalPos = portal:GetPos()
    local portalUp = portal:GetUp()
    local exitSize = portal:GetSize()
    local max = math.max(exitSize[1], exitSize[2])
    local eye = (eyePos - portalPos)

    -- Check if the eye position is behind the portal
    if eye:Dot(portalUp) <= -exitSize[3] then return false end

    -- Check if the eye position is close enough to the portal
    if eye:LengthSqr() >= distance^2 * max then return false end

    -- Check if the eye position is looking towards the portal
    return eye:Dot(eyeAngle:Forward()) < max
end