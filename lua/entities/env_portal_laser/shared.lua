-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Thermal Discouragement Beam
-- ----------------------------------------------------------------------------

AddCSLuaFile()

ENT.Type = "anim"
ENT.PrintName = "#env_portal_laser_short"
ENT.Category = "Portal 2"
ENT.Spawnable = true
ENT.Editable = true

util.PrecacheSound("Flesh.LaserBurn")
PrecacheParticleSystem("reflector_start_glow")
PrecacheParticleSystem("laser_start_glow")
PrecacheParticleSystem("laser_relay_powered")
PrecacheParticleSystem("discouragement_beam_sparks")

function ENT:SetupDataTables()
    self:NetworkVar(
        "Bool",
        "State",
        {
            KeyName = "state",
            Edit = {
                type = "Bool",
                order = 1
            }
        }
    )
    self:NetworkVar("Bool", "LethalDamage")
    self:NetworkVar("Bool", "AutoAim")
    self:NetworkVar("Bool", "ShouldSpark")
    self:NetworkVar("Bool", "NoModel")
    self:NetworkVar("Vector", "HitPos")
    self:NetworkVar("Vector", "HitNormal")
    self:NetworkVar("Entity", "ParentLaser")
    self:NetworkVar("Entity", "ChildLaser")
    self:NetworkVar("Entity", "Reflector")

    self:NetworkVarNotify("State", self.OnStateChange)

    if SERVER then
        self:SetShouldSpark(true)
        self:SetState(true)
        self:SetHitPos(Vector(2 ^ 16, 2 ^ 16, 2 ^ 16))
    end
end
