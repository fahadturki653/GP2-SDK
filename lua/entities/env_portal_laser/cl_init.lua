-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Thermal Discouragement Beam
-- ----------------------------------------------------------------------------

include "shared.lua"

local CalcClosestPointOnLineSegment = GP2.Utils.CalcClosestPointOnLineSegment
local clamp = math.Clamp

function ENT:Initialize()
    if self:GetState() then
        self:StartParticles()
        self:StartLoopingSounds()
    end
end

function ENT:OnRemove()
    self:StopParticles()
    self:StopLoopingSounds()
end

function ENT:Think()
    EnvPortalLaser.AddToRenderList(self)

    self:ChangeVolumeByDistanceToBeam()

    if self:GetShouldSpark() then
        self:StartSparkParticle()

        if IsValid(self.SparksParticle) then
            self.SparksParticle:SetControlPointOrientation(0, self:GetHitNormal():Angle())
            self.SparksParticle:SetControlPoint(0, self:GetHitPos())
        end
    else
        if IsValid(self.SparksParticle) then
            self.SparksParticle:StopEmission()
            self.SparksParticle = NULL
        end
    end
end

function ENT:StartSparkParticle()
    if not IsValid(self.SparksParticle) then
        self.SparksParticle = CreateParticleSystem(self, "discouragement_beam_sparks", PATTACH_CUSTOMORIGIN)
    end
end

function ENT:StartParticles()
    if IsValid(self:GetParentLaser()) then
        self.Particle = CreateParticleSystem(self, "reflector_start_glow", PATTACH_ABSORIGIN_FOLLOW)
    else
        self.Particle = CreateParticleSystem(self, "laser_start_glow", PATTACH_POINT_FOLLOW,
            self:LookupAttachment("laser_attachment"))
    end

    self:StartSparkParticle()
end

function ENT:StopParticles()
    if IsValid(self.Particle) then
        self.Particle:StopEmission()
    end

    if IsValid(self.SparksParticle) then
        self.SparksParticle:StopEmission()
    end
end

function ENT:StartLoopingSounds()
    if not self.BeamSound then
        self.BeamSound = CreateSound(self, "Laser.BeamLoop")
        self.BeamSound:SetSoundLevel(0)
        self.BeamSound:PlayEx(0, 100)
    end
end

function ENT:StopLoopingSounds()
    if self.BeamSound then
        self.BeamSound:Stop()
        self.BeamSound = nil
    end
end

function ENT:ChangeVolumeByDistanceToBeam()
    local pos = EyePos()
    local nearest = CalcClosestPointOnLineSegment(pos, self:GetPos(), self:GetHitPos())
    local distance = (pos - nearest):Length()

    local maxDistance = 355
    local minVolume = 0
    local maxVolume = 0.25

    -- Volume based on the distance
    local volume = clamp((maxDistance - distance) / maxDistance * (maxVolume - minVolume) + minVolume, minVolume, maxVolume)

    if self.BeamSound then
        if not self.BeamSound:IsPlaying() then
            self.BeamSound:PlayEx(volume, 100)
        else
            self.BeamSound:ChangeVolume(volume)
        end
    end
end

function ENT:OnStateChange(name, old, new)
    if new then
        self:StartParticles()
        self:StartLoopingSounds()
    else
        self:StopParticles()
        self:StopLoopingSounds()
    end
end
