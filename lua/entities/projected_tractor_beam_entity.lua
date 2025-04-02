-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Tractor Beam
-- ----------------------------------------------------------------------------

AddCSLuaFile()
ENT.Type = "anim"

local MAX_RAY_LENGTH = 8192
local PROJECTED_BEAM_RADIUS = 54
local PROJECTED_BEAM_SIDES = 32

local debugNormalColor = Color(64,160,255,2)
local debugReversedColor = Color(255,160,64,2)

local developer = GetConVar("developer")

ENT.PhysicsSolidMask = CONTENTS_SOLID+CONTENTS_MOVEABLE+CONTENTS_BLOCKLOS

PrecacheParticleSystem("projected_wall_impact")

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", "Updated" )
    self:NetworkVar( "Bool", "GotInitialPosition" )
    self:NetworkVar( "Vector", "InitialPosition" )
    self:NetworkVar( "Float", "DistanceToHit" )
    self:NetworkVar( "Float", "Radius" )
    self:NetworkVar( "Float", "_LinearForce" )

    if SERVER then
        self:SetRadius(PROJECTED_BEAM_RADIUS)
    end
end

function ENT:Initialize()
    if SERVER then
        self.TraceFraction = 0
        self:SetModel("models/props_junk/PopCan01a.mdl")
    end
    self:AddEffects(EF_NODRAW)
end

function ENT:Think()
    if not self:GetUpdated() then
        self:CreateBeam()
        self:SetUpdated(true)
    end
    
if CLIENT then
    self:SetNextClientThink(CurTime())

    if not ProjectedTractorBeamEntity.IsAdded(self) then
        ProjectedTractorBeamEntity.AddToRenderList(self)
    end
end
    local startPos = self:GetPos()
    local angles = self:GetAngles()
    local fwd = angles:Forward()

    local tr = util.TraceLine({
        start = startPos,
        endpos = startPos + fwd * MAX_RAY_LENGTH,
        mask = MASK_SOLID_BRUSHONLY,
    })


    if self.TraceFraction ~= tr.Fraction then
        self:SetUpdated(false)
        self.TraceFraction = tr.Fraction
        debugoverlay.Cross(tr.HitPos, 16, 0.1, nil, true)
    end

    self:NextThink(CurTime())
    return true
end

function ENT:Draw()
end

function ENT:OnRemove(fd)
end

function ENT:CreateBeam(distance)
    distance = distance or 0

    local startPos = self:GetPos()
    local angles = self:GetAngles()
    local fwd = angles:Forward()
    local right = angles:Right()
    local up = angles:Up()

    local tr = util.TraceLine({
        start = startPos,
        endpos = startPos + fwd * MAX_RAY_LENGTH,
        mask = MASK_SOLID_BRUSHONLY,
    })

    if CLIENT then
        self.HitData = { HitPos = tr.HitPos, Angles = self:GetAngles(), Radius = self:GetRadius(), Sides = PROJECTED_BEAM_SIDES }
    end

    local hitPos = tr.HitPos
    local distance = hitPos:Distance(startPos)
    local v = -distance / 256
    self:SetDistanceToHit(distance)

    if CLIENT then
        local verts = {}

        local angleStep = (2 * math.pi) / PROJECTED_BEAM_SIDES

        for i = 0, PROJECTED_BEAM_SIDES - 1 do
            local angle = i * angleStep
            local nextAngle = (i + 1) % PROJECTED_BEAM_SIDES * angleStep

            local radius = self:GetRadius()

            local xOffset = math.cos(angle) * radius
            local yOffset = math.sin(angle) * radius
            local xNextOffset = math.cos(nextAngle) * radius
            local yNextOffset = math.sin(nextAngle) * radius

            local v1 = startPos + right * xOffset + up * yOffset
            local v2 = startPos + right * xNextOffset + up * yNextOffset
            local v3 = hitPos + right * xNextOffset + up * yNextOffset
            local v4 = hitPos + right * xOffset + up * yOffset

            local u1 = i / PROJECTED_BEAM_SIDES
            local u2 = (i + 1) / PROJECTED_BEAM_SIDES
            local uv1 = {0, u1}
            local uv2 = {0, u2}
            local uv3 = {v, u2}
            local uv4 = {v, u1}

            GP2.Utils.AddFace(verts, v1, v2, v3, v4, uv1, uv2, uv3, uv4)
        end

        if self.Mesh and self.Mesh:IsValid() then
            self.Mesh:Destroy()
        end

        self.Mesh = Mesh()
        self.Mesh:BuildFromTriangles(verts)
        ProjectedTractorBeamEntity.AddToRenderList(self, self.Mesh)
    else
        local radius =  self:GetRadius()

        if self.Trigger and IsValid(self.Trigger) then
            local pos = self:GetPos()
            local ang = self:GetAngles()

            local fwd = angles:Forward()
            local right = angles:Right()
            local up = angles:Up()

            local mins = pos - right * radius - up * radius
            local maxs = pos + right * radius + up * radius + fwd * distance

            self.Trigger:SetCollisionBoundsWS(mins, maxs)
            self.Trigger:SetAngles(self:GetAngles())
            self.Trigger.LinearForce = self:Get_LinearForce()

            if developer:GetBool() then
                debugoverlay.BoxAngles(pos, self:WorldToLocal(mins), self:WorldToLocal(maxs), ang, 0.1, self:Get_LinearForce() < 0 and debugReversedColor or debugNormalColor) 
            end
        else
            self.Trigger = ents.Create("trigger_tractorbeam")
            self.Trigger:Spawn()
            self.Trigger:SetPos(self:GetPos())
            self.Trigger:SetParent(self)
            self.Trigger:SetTractorBeam(self)
            self.Trigger.LinearForce = self:Get_LinearForce()

            local pos = self:GetPos()
            local ang = self:GetAngles()

            local fwd = angles:Forward()
            local right = angles:Right()
            local up = angles:Up()

            local mins = pos - right * radius - up * radius
            local maxs = pos + right * radius + up * radius + fwd * distance
           
            self.Trigger:SetCollisionBoundsWS(mins, maxs)
            self.Trigger:SetAngles(self:GetAngles())

            if developer:GetBool() then
                debugoverlay.BoxAngles(pos, self:WorldToLocal(mins), self:WorldToLocal(maxs), ang, 0.1, self:Get_LinearForce() < 0 and debugReversedColor or debugNormalColor) 
            end
        end
    end
end

if SERVER then
    function ENT:UpdateTransmitState()
        return TRANSMIT_ALWAYS
    end

    function ENT:SetLinearForce(force)
        self:Set_LinearForce(force)
        self:SetUpdated(false)
    end
end