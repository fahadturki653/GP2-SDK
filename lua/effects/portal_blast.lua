-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portal gun projectile
-- ----------------------------------------------------------------------------

local cl_portal_projectile_delay_sp = CreateClientConVar("cl_portal_projectile_delay_sp", "0.14", FCVAR_CHEAT)
local cl_portal_projectile_delay_mp = CreateClientConVar("cl_portal_projectile_delay_mp", "0.1", FCVAR_CHEAT)

EFFECT.CreationPoint = Vector()
EFFECT.DeathPoint = Vector()
EFFECT.CreationTime = 0
EFFECT.AimPoint = Vector()
EFFECT.PortalGunColor = Vector(255,255,255)

--- @param data CEffectData
function EFFECT:Init(data)
    local angles = data:GetAngles()

    local vStart = data:GetOrigin()
    local vEnd = data:GetStart() 
    local owner = data:GetEntity()

    self.CreationPoint = vStart
    self.DeathPoint = vEnd

    local flProjectileDelay = cl_portal_projectile_delay_mp:GetFloat()

    if game.SinglePlayer() then
        flProjectileDelay = cl_portal_projectile_delay_sp:GetFloat()
    end

    self.CreationTime = flProjectileDelay + CurTime()
    self.DeathTime = self.CreationTime + 0.1

    local forward, right, up = angles:Forward(), angles:Right(), angles:Up()
    self.AimPoint = self.CreationPoint + forward * self.CreationPoint:Distance(self.DeathPoint)

    if not data.PlacedByPedestal then
        if owner:IsPlayer() then
            self.Particle = CreateParticleSystem(self, "portal_projectile_stream", PATTACH_ABSORIGIN_FOLLOW)
            
            if IsValid(self.Particle) then
                self.Particle:SetControlPoint(2, data:GetNormal())
            end
        end
    end
end

function EFFECT:Think()

end
