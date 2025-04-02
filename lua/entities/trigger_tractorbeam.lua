-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Trigger Tractor beams
-- ----------------------------------------------------------------------------

ENT.Type = "brush"
ENT.Base = "base_brush"
ENT.TouchingEnts = {}
ENT.TractorBeam = NULL

local TRACTOR_BEAM_VALID_ENTS = {
    --["player"] = true, -- player movement handled by Move hook
    ["prop_physics"] = true,
    ["func_physbox"] = true,
    ["prop_monster_box"] = true,
    ["prop_weighted_cube"] = true,
    ["npc_personality_core"] = true,
    ["npc_portal_turret_floor"] = true,
    ["prop_ragdoll"] = true,
    ["prop_exploding_futbol"] = true,
    ["npc_grenade_frag"] = true,
    ["npc_manhack"] = true,
    ["npc_cscanner"] = true,
    ["npc_clawscanner"] = true,
    ["npc_rollermine"] = true,
}

function ENT:Initialize()
    self:SetSolid(SOLID_BBOX)
    self:SetTrigger(true)
end

function ENT:SetTractorBeam(tbeam)
    self.TractorBeam = tbeam
end

function ENT:Think()
    if not self.TractorBeam or not IsValid(self.TractorBeam) then
        self:Remove()
        return
    end

    local mins, maxs = self:GetCollisionBounds()

    local fwd = self:GetAngles():Forward()
    local right = self:GetAngles():Right()
    self.DistanceToHit = math.abs((maxs - mins):Dot(right))

    for i = #self.TouchingEnts, 1, -1 do
        local ent = self.TouchingEnts[i]

        if not IsValid(ent) then
            table.remove(self.TouchingEnts, i)

            if ent:IsPlayer() then
                GP2.GameMovement.PlayerExitedFromTractorBeam(ent, self)
            end
        else
            self:ProcessEntity(ent) 
        end
    end

    self:NextThink(CurTime())
    return true
end

function ENT:StartTouch(ent)
    if IsValid(self.TractorBeam) then
        
        if (TRACTOR_BEAM_VALID_ENTS[ent:GetClass()]) then
            table.insert(self.TouchingEnts, ent)
        elseif ent:IsPlayer() then
            GP2.GameMovement.PlayerEnteredToTractorBeam(ent, self)

            if self.sndPlayerInBeam then
                self.sndPlayerInBeam:Stop()
            end
            
            local filter = RecipientFilter(true)
            filter:AddPlayer(ent)

            self.sndPlayerInBeam = CreateSound(ent, "VFX.PlayerEnterTbeam", filter)
            self.sndPlayerInBeam:Play()
        elseif ent:IsNPC() or ent:IsNextBot() or ent:IsVehicle() then
            table.insert(self.TouchingEnts, ent)
        end
    end
end

function ENT:ProcessEntity(ent)
    local phys = ent:GetPhysicsObject()

    local entPos = ent:WorldSpaceCenter()
    local centerPos = self:WorldSpaceCenter()
    local angles = self:GetAngles()

    local toCenter = centerPos - entPos
    local sidewayForce = angles:Right() * toCenter:Dot(angles:Right()) + angles:Up() * toCenter:Dot(angles:Up())
    local baseForce = (self.LinearForce or 0) * 0.5
    local forwardForce = angles:Forward() * baseForce

    local totalForce

    if (TRACTOR_BEAM_VALID_ENTS[ent:GetClass()] or ent:IsVehicle()) and IsValid(phys) then
        local normalizedForwardForce = forwardForce:GetNormalized()

        local mins, maxs = ent:GetCollisionBounds()
        local boxSize = (maxs - mins):Length()
    
        local trMovementFrontFace = entPos + normalizedForwardForce * (boxSize / 2)

        local tr = util.QuickTrace(trMovementFrontFace, normalizedForwardForce * boxSize, {self, ent})

        if tr.Fraction < 0.1 then 
            totalForce = sidewayForce
        else
            totalForce = (forwardForce + sidewayForce) * tr.Fraction
            phys:AddAngleVelocity((forwardForce + sidewayForce) * tr.Fraction / phys:GetMass())
        end    

        phys:Wake()
        phys:SetVelocity(totalForce)
        phys:SetAngleVelocity(totalForce)
    else
        totalForce = forwardForce + sidewayForce
        ent:SetLocalVelocity(totalForce)
    end

    ent:SetGroundEntity(NULL)
end


function ENT:EndTouch(ent)
    table.RemoveByValue(self.TouchingEnts, ent)

    if ent:IsPlayer() then
        GP2.GameMovement.PlayerExitedFromTractorBeam(ent, self)

        if self.sndPlayerInBeam then
            self.sndPlayerInBeam:FadeOut(5)
        end
    end
end

function ENT:OnRemove()
    if self.sndPlayerInBeam then
        self.sndPlayerInBeam:Stop()
    end
end