-- ----------------------------------------------------------------------------
-- GP2 Framework
-- env_portal_laser rendering
-- ----------------------------------------------------------------------------

EnvPortalLaser = EnvPortalLaser or {}

local print = GP2.Print
local table_sort = table.sort
local table_insert = table.insert
local util_TraceLine = util.TraceLine

local laserRenderList = {}
local laserLookups = {}
local laserAttachmentLookups = {}

local LASER_MATERIAL = Material("sprites/purplelaser1.vmt")
local LASER_MATERIAL_LETHAL = Material("sprites/laserbeam.vmt")
local LETHAL_COLOR = Color(100, 255, 100)
local NORMAL_COLOR = Color(255, 255, 255)

local RAY_EXTENTS = Vector(0.001, 0.001, 0.001)
local RAY_EXTENTS_NEG = -RAY_EXTENTS
local INVALID_HIT_POS = Vector(2 ^ 16, 2 ^ 16, 2 ^ 16)
local MAX_RAY_LENGTH = 2 ^ 16

function EnvPortalLaser.AddToRenderList(laser)
    if not laserLookups[laser] then
        table_insert(laserRenderList, laser)
        laserLookups[laser] = true
    end
end

local function RecursionLaserThroughPortals(laser, linkedPortal, data)
    local tr = util_TraceLine(data)
    local inTrace = ents.FindAlongRay(tr.StartPos, tr.HitPos, -RAY_EXTENTS_NEG, RAY_EXTENTS)
    local candidates = {}

    local filter = {
        prop_weighted_cube = true,
        prop_portal = true
    }

    for e = 1, #inTrace do
        local tracedEntity = inTrace[e]

        if not filter[tracedEntity:GetClass()]
            or tracedEntity == laser
            or tracedEntity == laser:GetParent()
            or tracedEntity:IsNPC()
            or tracedEntity:IsNextBot()
            or tracedEntity == linkedPortal then
            continue
        end

        local mins, maxs = tracedEntity:GetCollisionBounds()

        local intersect = util.IntersectRayWithOBB(
            tr.StartPos,
            tr.Normal * MAX_RAY_LENGTH,
            tracedEntity:GetPos(),
            tracedEntity:GetAngles(),
            mins, maxs
        )

        if intersect then
            local distanceSqr = tr.StartPos:DistToSqr(intersect)
            table.insert(candidates, {
                Entity = tracedEntity,
                HitPos = intersect,
                DistanceSqr = distanceSqr
            })
        end
    end

    table.sort(candidates, function(a, b)
        return a.DistanceSqr < b.DistanceSqr
    end)

    local rayHit = nil
    for _, candidate in ipairs(candidates) do
        local tracedEntity = candidate.Entity
        local intersect = candidate.HitPos

        -- Use small traceline to check if ray actually hits cube :/
        -- ray is thick than traceline
        local preEndPos = intersect - tr.Normal * 16

        local preEndTrace = util_TraceLine({
            start = preEndPos,
            endpos = intersect + tr.Normal * 16,
            filter = { game.GetWorld() }
        })

        if not preEndTrace.Hit or not IsValid(preEndTrace.Entity) or not filter[preEndTrace.Entity:GetClass()] then
            continue
        end

        rayHit = { 
            HitPos = intersect,
            Entity = tracedEntity,
            Distance = math.sqrt(candidate.DistanceSqr)
        }

        if tracedEntity:GetClass() == "prop_portal" then
            tr.HitPos = intersect + tr.Normal * tracedEntity:GetSize().z
        else
            tr.HitPos = intersect + tr.Normal
        end
        tr.Entity = tracedEntity

        break
    end

    render.DrawBeam(data.start, tr.HitPos, 64, 0, 1)

    if tr.Entity:IsValid() and tr.Entity:GetClass() == "prop_portal" and IsValid(tr.Entity:GetLinkedPartner()) then
        local hitPortal = tr.Entity
        local linkedPortal = hitPortal:GetLinkedPartner()

        if tr.HitNormal:Dot(hitPortal:GetUp()) > 0.9 then
            local newData = table.Copy(data)

            newData.start = PortalManager.TransformPortal(hitPortal, linkedPortal, tr.HitPos - tr.Normal * linkedPortal:GetSize().z * 2)
            newData.endpos = PortalManager.TransformPortal(hitPortal, linkedPortal, data.endpos)

            if isentity(data.filter) and data.filter:GetClass() ~= "player" then
                newData.filter = { data.filter, linkedPortal }
            else
                if istable(data.filter) then
                    table.insert(newData.filter, linkedPortal)
                else
                    newData.filter = linkedPortal
                end
            end

            return RecursionLaserThroughPortals(laser, linkedPortal, newData)
        end
    end

    return tr
end

function EnvPortalLaser.Render()
    for i = #laserRenderList, 1, -1 do
        local laser = laserRenderList[i]

        if not IsValid(laser) then
            table.remove(laserRenderList, i)
            laserLookups[laser] = nil
            continue
        end

        if not laser:GetState() then
            continue
        end

        local noModel = laser:GetNoModel()
        local modelName = laser:GetModel()
        local hitPos = laser:GetHitPos()

        if hitPos == INVALID_HIT_POS then
            continue
        end

        local attachPos
        local attachAng
        local attachForward

        if not noModel and not laserAttachmentLookups[modelName] then
            laserAttachmentLookups[modelName] = laser:LookupAttachment("laser_attachment")

            if laserAttachmentLookups[modelName] == -1 then
                print("EnvPortalLaser :: Render - laser %q with %q model has no \"laser_attachment\"", laser, modelName)
                continue
            end
        end

        if laserAttachmentLookups[modelName] ~= -1 and not noModel then
            local attach = laser:GetAttachment(laserAttachmentLookups[modelName])
            attachPos = attach.Pos
            attachAng = attach.Ang
            attachForward = attachAng:Forward()
        else
            attachPos = laser:GetPos()
            attachAng = laser:GetAngles()
            attachForward = attachAng:Forward()
        end

        render.SetMaterial(LASER_MATERIAL)

        local tr = RecursionLaserThroughPortals(laser, NULL, {
            start = attachPos,
            endpos = attachPos + attachForward * MAX_RAY_LENGTH,
            filter = {
                laser,
                "projected_wall_entity",
                "player",
                "point_laser_target",
                "prop_laser_catcher",
                "prop_laser_relay",
                laser:GetParent()
            },
            mask = MASK_OPAQUE_AND_NPCS
        })
    end
end
