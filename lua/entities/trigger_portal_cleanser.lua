-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portal cleanser trigger
-- ----------------------------------------------------------------------------

ENT.Type = "brush"

local math_min = math.min

local mats = {}

local ENTS_TO_DISSOLVE = {
    ["prop_physics"] = true,
    ["prop_weighted_cube"] = true,
    ["prop_monster_box"] = true,
    ["npc_portal_turret_floor"] = true,
    ["npc_turret_floor"] = true,
}

local DURATION_SLEEP = 1
local DURATION_WAKE = 1

function ENT:KeyValue(k, v)
    if k == "StartDisabled" then
        self:SetEnabled(not tobool(v))
    elseif k == "Visible" then
        self:SetVisible(tobool(v))
    elseif k == "UseScanline" then
        self:SetUseScanline(tobool(v))
    end

    if k:StartsWith("On") then
        self:StoreOutput(k, v)
    end
end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", "Enabled" )
    self:NetworkVar( "Bool", "Visible" )
    self:NetworkVar( "Bool", "UseScanline" )
    self:NetworkVar( "Float", "LastEnableTime" )

    if SERVER then
        self:SetEnabled(true)
    end
end

function ENT:Initialize()
    self:SetTrigger(true)

    if self:GetVisible() then
        self:RemoveEffects(EF_NODRAW)
    end
end

function ENT:StartTouch(ent)
    print('st')
    if not self:GetEnabled() then return end
    if not IsValid(ent) then return end

    if ent:IsPlayer() then
        local weapons = ent:GetWeapons()
        for i = 1, #weapons do
            local weapon = weapons[i]
            if IsValid(weapon) and weapon:GetClass() == "weapon_portalgun" then
                weapon:ClearPortals()
            end
        end
    end

    if not ENTS_TO_DISSOLVE[ent:GetClass()] then return end

    ent:Dissolve(0)
end

function ENT:UpdateTransmitState()
    return TRANSMIT_PVS
end

function ENT:Think()
    local surfaces = self:GetBrushSurfaces()
    local curtime = CurTime()

    -- Determine radius dynamically using collision bounds
    local minBounds, maxBounds = self:GetCollisionBounds()
    local radius = (maxBounds - minBounds):Length() / 2 -- Use the largest dimension as the radius

    local pos = self:GetPos()

    local targetPowerup = self:GetEnabled() and 1 or 0
    local duration = self:GetEnabled() and DURATION_WAKE or DURATION_SLEEP
    local powerupValue = self.FullPowerup or 0

    powerupValue = math.Approach(powerupValue, targetPowerup, FrameTime() / duration)
    self.FullPowerup = powerupValue

    for _, surface in ipairs(surfaces) do
        surface:GetMaterial():SetFloat("$powerup", powerupValue)

    end

    local entsInSphere = ents.FindInSphere(pos, radius)
    local vortexEnts = 0

    for _, ent in ipairs(entsInSphere) do
        if not ENTS_TO_DISSOLVE[ent:GetClass()] then continue end

        if ent == self or not IsValid(ent) or (ent:IsPlayer() and not ent:Alive()) then
            continue
        end

        vortexEnts = vortexEnts + 1
        if vortexEnts > 2 then break end -- Limit to two vortices

        for _, surface in ipairs(surfaces) do
            surface:GetMaterial():SetInt("$FLOW_VORTEX" .. vortexEnts, 1)
            surface:GetMaterial():SetVector("$FLOW_VORTEX_POS" .. vortexEnts, ent:GetPos())
        end
    end

    -- Disable unused vortices
    for i = vortexEnts + 1, 2 do
        for _, surface in ipairs(surfaces) do
            surface:GetMaterial():SetInt("$FLOW_VORTEX" .. i, 0)
        end
    end

    self:NextThink(CurTime())
    return true
end


function ENT:AcceptInput(name, activator, caller, value)
    name = name:lower()

    if name == "enable" then
        self:Enable()
    elseif name == "disable" then
        self:Disable()
    end
end

function ENT:Enable()
    if self:GetEnabled() then return end

    self:SetLastEnableTime(CurTime())
    self:SetEnabled(true)
    self:EmitSound("VFX.FizzlerStart")
    self:StopSound("VFX.FizzlerDestroy")
end

function ENT:Disable()
    if not self:GetEnabled() then return end

    self:SetLastEnableTime(CurTime())
    self:SetEnabled(false)
    self:EmitSound("VFX.FizzlerDestroy")
    self:StopSound("VFX.FizzlerStart")
end