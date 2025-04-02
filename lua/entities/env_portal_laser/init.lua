-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Thermal Discouragement Beam
-- ----------------------------------------------------------------------------

include "shared.lua"

local LASER_MODEL = "models/props/laser_emitter.mdl"
local MAX_RAY_LENGTH = 2 ^ 16

local portal_laser_perf_debug = CreateConVar("gp2_portal_laser_perf_debug", "0", FCVAR_CHEAT,
    "Debug perf timings for portal laser", 0, 1)
local portal_laser_normal_update = CreateConVar("gp2_portal_laser_normal_update", "0.05", FCVAR_REPLICATED)
local portal_laser_high_precision_update = CreateConVar("gp2_portal_laser_high_precision_update", "0.001",
    FCVAR_REPLICATED)


local sv_player_collide_with_laser = CreateConVar("gp2_sv_player_collide_with_laser", "1", FCVAR_NOTIFY + FCVAR_CHEAT)

local clamp = math.Clamp
local util_TraceLine = util.TraceLine
local ents_FindAlongRay = ents.FindAlongRay
local CalcClosestPointOnLineSegment = GP2.Utils.CalcClosestPointOnLineSegment
local EmitSoundAtClosestPoint = GP2.Utils.EmitSoundAtClosestPoint

local PROP_WEIGHTED_CUBE_CLASS = {
    ["prop_weighted_cube"] = true
}

local PROP_WEIGHTED_CUBE_TYPE = {
    [2] = true
}

local LASER_TARGET_CLASS = {
    ["point_laser_target"] = true
}

local RAY_EXTENTS = Vector(10, 10, 10)
local RAY_EXTENTS_NEG = -RAY_EXTENTS

local DAMAGABLE_ENTS = {
    ["point_laser_target"] = true
}

local NOT_DAMAGABLE_ENTS = {
    ["npc_security_camera"] = true
}

local TURRET_CLASS = {
    ["npc_portal_turret_floor"] = true
}


function ENT:KeyValue(k, v)
    if k == "StartState" then
        self:SetState(not tobool(v))
    elseif k == "LethalDamage" then
        self:SetLethalDamage(tobool(v))
    elseif k == "AutoAimEnabled" then
        self:SetAutoAim(tobool(v))
    elseif k == "model" then
        self.ModelName = v
    elseif k == "skin" then
        self:SetSkin(tonumber(v))
    end

    if k:StartsWith("On") then
        self:StoreOutput(k, v)
    end
end

function ENT:AcceptInput(name, activator, caller, value)
    name = name:lower()

    if name == "turnon" then
        self:SetState(true)
    elseif name == "turnoff" then
        self:SetState(false)
    elseif name == "toggle" then
        self:SetState(not self:GetState())
    end
end

function ENT:Initialize()
    if not self:GetNoModel() then
        self:SetModel(self.ModelName or LASER_MODEL)
        self.LaserAttachment = self.LaserAttachment or self:LookupAttachment("laser_attachment")
        self:PhysicsInitStatic(MOVETYPE_VPHYSICS)
    end

    self:NextThink(CurTime())
end

function ENT:Think()
    local time = os.clock()

    self:FireLaser()

    if portal_laser_perf_debug:GetBool() then
        GP2.Print("EnvPortalLaser :: Think - execution time: %.6f seconds", os.clock() - time)
    end

    if IsValid(self:GetParentLaser()) then
        self:NextThink(CurTime() + portal_laser_high_precision_update:GetFloat())
    else
        self:NextThink(CurTime() + portal_laser_normal_update:GetFloat())
    end

    return true
end

function ENT:RecursionLaserThroughPortals(data)
    local tr = util_TraceLine(data)

    self:DamageEntsAlongTheRay(data.start, tr.HitPos)

    if tr.Entity:IsValid() and tr.Entity:GetClass() == "prop_portal" and IsValid(tr.Entity:GetLinkedPartner()) then
        local hitPortal = tr.Entity
        local linkedPortal = hitPortal:GetLinkedPartner()

        -- Ensure the hit normal aligns for portal transition
        if tr.HitNormal:Dot(hitPortal:GetUp()) > 0.9 then
            local newData = table.Copy(data)

            newData.start = PortalManager.TransformPortal(hitPortal, linkedPortal, tr.HitPos)
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

            return self:RecursionLaserThroughPortals(newData)
        end
    end

    return tr
end

--- Fire laser every tick (depending on if laser is reflected or base there should be
--- diferrent delay)
function ENT:FireLaser()
    if not self:GetState() then
        return
    end

    if not self:GetNoModel() and self.LaserAttachment == -1 then
        GP2.Error("EnvPortalLaser :: FireLaser - env_portal_laser[%i] with model %q don't have \"laser_attachment\"",
            self:EntIndex(), self:GetModel())
        return
    end

    local attachPos
    local attachAng
    local attachForward

    if self:GetNoModel() then
        attachPos = self:GetPos()
        attachAng = self:GetAngles()
    else
        local attach = self:GetAttachment(self.LaserAttachment)
        attachPos = attach.Pos
        attachAng = attach.Ang
    end

    attachForward = attachAng:Forward()

    local tr = self:RecursionLaserThroughPortals({
        start = attachPos,
        endpos = attachPos + attachForward * MAX_RAY_LENGTH,
        filter = {
            self,
            "projected_wall_entity",
            "player",
            "point_laser_target",
            "prop_laser_catcher",
            "prop_laser_relay",
            self:GetParent() },
        mask = MASK_OPAQUE_AND_NPCS
    })

    local hitEntity = tr.Entity
    self:SetReflector(hitEntity)

    -- Set hit pos for client
    -- MASK_OPAQUE_AND_NPCS uses CONTENTS_WINDOW, so on client laser goes through cubes and
    -- transparent objects/surfaces
    self:SetHitPos(tr.HitPos)
    self:SetHitNormal(tr.HitNormal)

    -- If we hit reflective cube add laser into
    if IsValid(hitEntity) then
        if PROP_WEIGHTED_CUBE_CLASS[hitEntity:GetClass()] and PROP_WEIGHTED_CUBE_TYPE[hitEntity:GetCubeType()] then
            self:ReflectLaserForEntity(hitEntity)
        elseif TURRET_CLASS[hitEntity:GetClass()] and not hitEntity:IsOnFire() then
            hitEntity:Ignite(5)
        end

        self:SetShouldSpark(false)
    else
        self:SetShouldSpark(true)
    end
end

--- Reflect laser on this entity (reflective cube)
function ENT:ReflectLaserForEntity(reflector)
    -- If there's no laser reflected via this cube
    -- create it
    if not IsValid(reflector:GetChildLaser()) then
        local laser = ents.Create(self:GetClass())

        if IsValid(laser) then
            laser:SetNoModel(true)
            laser:SetPos(reflector:GetPos())
            laser:SetAngles(reflector:GetAngles())
            laser:SetParent(reflector)
            laser:Spawn()
            laser:AddEffects(EF_NODRAW + EF_NOSHADOW)

            reflector:SetChildLaser(laser)
            laser:SetParentLaser(self)
            self:SetChildLaser(laser)
        end
    end
end

--- Pushes player from line
--- @param player Player Who should be pushed?
--- @param startPos Vector Where laser starts
--- @param endPod Vector Where laser ends
--- @param force number Force of push (for example: 300)
local function PushPlayerAwayFromLine(player, startPos, endPos, baseForce)
    if not sv_player_collide_with_laser:GetBool() then return end

    -- Ensure the player is valid and capable of being moved
    if not IsValid(player) or not player:IsPlayer() or player:GetMoveType() == MOVETYPE_NOCLIP then
        return
    end

    -- Check if the player is on the ground
    if not player:IsOnGround() then return end

    -- Check if player portal teleporting right now
    if player.PORTAL_TELEPORTING then return end

    -- Calculate the nearest point on the line segment to the player
    local playerPos = player:GetPos()
    local nearestPoint = CalcClosestPointOnLineSegment(playerPos, startPos, endPos)

    -- Calculate the direction from the line segment to the player
    local pushDirection = (playerPos - nearestPoint):GetNormalized()
    pushDirection.z = 0 -- Keep the push direction horizontal

    -- Get the player's current velocity magnitude
    local playerVelocity = player:GetVelocity():Length()

    -- Adjust the force based on player's movement speed (but not when crouching)
    if not player:Crouching() then
        baseForce = baseForce * (playerVelocity / 100)
    end

    -- Clamp the force to a maximum of [400, 1000]
    local clampedForce = clamp(baseForce, 400, 1000)

    -- If the player is crouching, double the force
    if player:Crouching() then
        clampedForce = clampedForce * 2
    end

    -- Calculate the push velocity vector
    local pushVelocity = pushDirection * clampedForce

    -- Apply the calculated push velocity to the player
    player:SetGroundEntity(NULL)
    player:SetVelocity(pushVelocity)
end

--- Damage ents along ray (players/npcs/laser receivers)
--- @param startPos Vector Position to emit ray from
--- @param endPos Vector Ray end pos
function ENT:DamageEntsAlongTheRay(startPos, endPos)
    local rayInfo = ents_FindAlongRay(startPos, endPos, RAY_EXTENTS_NEG, RAY_EXTENTS)

    for i = 1, #rayInfo do
        local target = rayInfo[i]

        if target:IsPlayer() and not sv_player_collide_with_laser:GetBool() then continue end

        -- If target is not valid somehow, skip it
        if not IsValid(target) then continue end

        -- If target is not player, npc, nexbot or damageable ent, skip it
        if not (target:IsPlayer() or target:IsNPC() or target:IsNextBot() or DAMAGABLE_ENTS[target:GetClass()]) then
            continue
        end

        -- Don't spark
        if DAMAGABLE_ENTS[target:GetClass()] then
            self:SetShouldSpark(false)
        end

        -- Don't damage some ents
        if NOT_DAMAGABLE_ENTS[target:GetClass()] then continue end

        -- If player is not alive don't damage it
        if target:IsPlayer() and not target:Alive() then continue end

        -- Ensure the player is valid and capable of being moved
        if target:IsPlayer() and target:GetMoveType() == MOVETYPE_NOCLIP then
            continue
        end

        -- Check if the player is on the ground
        if target:IsPlayer() and not target:IsOnGround() then continue end

        -- Check if player portal teleporting right now
        if target.PORTAL_TELEPORTING then continue end

        -- Damage it now
        local damageInfo = DamageInfo()
        damageInfo:SetAttacker(self)

        if LASER_TARGET_CLASS[target:GetClass()] then
            damageInfo:SetDamage(1)
        else
            damageInfo:SetDamage(8)
        end

        target:TakeDamageInfo(damageInfo)

        -- Push it
        PushPlayerAwayFromLine(target, startPos, endPos, 400)
        EmitSoundAtClosestPoint(target, startPos, endPos, "Flesh.LaserBurn")
        EmitSoundAtClosestPoint(target, startPos, endPos, "Player.PainSmall")
    end
end

function ENT:OnStateChange(name, old, new)
    local child = self:GetChildLaser()

    if IsValid(child) then
        child:SetState(new)
    end
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 10
    local SpawnAng = ply:EyeAngles()
    SpawnAng.p = 0

    local ent = ents.Create(ClassName)
    ent:SetPos(SpawnPos)
    ent:SetAngles(SpawnAng)
    ent:Spawn()
    ent:Activate()

    return ent
end
