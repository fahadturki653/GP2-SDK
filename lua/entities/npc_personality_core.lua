-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Cores
-- ----------------------------------------------------------------------------

AddCSLuaFile()
ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.AutomaticFrameAdvance = true

local CORE_MODEL = "models/npcs/personality_sphere/personality_sphere.mdl"
local CORE_SKINS_MODEL = "models/npcs/personality_sphere/personality_sphere_skins.mdl"

ENT.m_fMaxYawSpeed = 200
ENT.m_iClass = CLASS_PLAYER_ALLY

local sv_personality_core_pca_pitch = CreateConVar("sv_personality_core_pca_pitch", "180", FCVAR_NONE, "Pitch value for personality core perferred carry angles.")
local sv_personality_core_pca_yaw = CreateConVar("sv_personality_core_pca_yaw", "-90", FCVAR_NONE, "Yaw value for personality core perferred carry angles.")
local sv_personality_core_pca_roll = CreateConVar("sv_personality_core_pca_roll", "195", FCVAR_NONE, "Roll value for personality core perferred carry angles.")

PrecacheParticleSystem("")

if SERVER then
    ENT.IdleOverrideSequence = 0
end

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", "Attached" )
    self:NetworkVar( "Bool", "PickupEnabled" )
    self:NetworkVar( "Bool", "FlashlightEnabled" )
    self:NetworkVar( "Bool", "DropEnabled" )

    if SERVER then
        self:SetDropEnabled(true)
        self:SetPickupEnabled(true)
    end
end

function ENT:Initialize()
    self.IdleOverrideSequence = nil
    self.FlashLightAttachment = self:LookupAttachment("eyes")
    
    if SERVER then
        self:ChooseSkins()
        self:SetSolidFlags(FSOLID_NOT_STANDABLE)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:AddFlags(FL_UNBLOCKABLE_BY_PLAYER)
        self:CapabilitiesClear()
        self:SetHullType(HULL_SMALL_CENTERED)
        self:SetHullSizeNormal()
        self:CapabilitiesAdd(CAP_ANIMATEDFACE)
        self:SetBloodColor(DONT_BLEED)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetActivity(ACT_IDLE)
    end
end

ENT.__input2func = {
    ["setidlesequence"] = function(self, activator, caller, data)
        self:SetIdleSequence(data)
    end,
    ["clearidlesequence"] = function(self, activator, caller, data)
        self:ClearIdleSequence()
    end,
    ["explode"] = function(self, activator, caller, data)
        local pos = self:GetPos()
        local effectdata = EffectData()
        effectdata:SetOrigin(pos)

        util.Effect("Explosion", effectdata)
        util.ScreenShake(self:GetPos(), 10, 150, 1, 750, true)
        self:Remove()
    end,
    ["playattach"] = function(self, activator, caller, data)
        self:PlayScene("scenes/npc/sp_proto_sphere/sphere_plug_attach.vcd")
        self:SetAttached(true)
    end,
    ["playdetach"] = function(self, activator, caller, data)
        self:SetAttached(false)
        self:RemoveSolidFlags(FSOLID_NOT_SOLID)
    end,
    ["playlock"] = function(self, activator, caller, data)
        self:PlayScene("scenes/npc/sp_proto_sphere/sphere_plug_attach.vcd")
        self:AddSolidFlags(FSOLID_NOT_SOLID)
    end,
    ["forcepickup"] = function(self, activator, caller, data)
        local ply = Entity(1)

        if ply and IsValid(ply) then
            ply:PickupObject(self)
        end
    end,
    ["enableflashlight"] = function(self, activator, caller, data)
        self:SetFlashlightEnabled(true)
    end,
    ["disableflashlight"] = function(self, activator, caller, data)
        self:SetFlashlightEnabled(false)
    end,
    ["enablepickup"] = function(self, activator, caller, data)
        self:SetPickupEnabled(true)
    end,
    ["disablepickup"] = function(self, activator, caller, data)
        self:SetPickupEnabled(false)
    end,
    ["enablemotion"] = function(self, activator, caller, data)
        self:SetParent(NULL)
        self:PhysicsInit(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if phys and IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    end,
    ["disablemotion"] = function(self, activator, caller, data)
        local phys = self:GetPhysicsObject()

        if phys and IsValid(phys) then
            phys:EnableMotion(false)
        end
    end,
    ["clearparent"] = function(self, activator, caller, data)
        self:RemoveSolidFlags(FSOLID_NOT_SOLID)
        self:SetParent(NULL)
        self:PhysicsInit(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()        
        if phys and IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    end,               
}

function ENT:AcceptInput(name, activator, caller, data)
    name = name:lower()
    local func = self.__input2func[name]

    if func and isfunction(func) then
        func(self, activator, caller, data)
    end
end

if SERVER then
    -- Schedules
    local idleSched = ai_schedule.New( "Test Schedule" )
    idleSched:AddTask("CustomIdle")

    function ENT:KeyValue(k, v)   
        if k == "ModelSkin" then
            self.ModelSkin = tonumber(v)
        end

        if k == "altmodel" then   
            self.AltModel = tobool(v)
            
            if tobool(v) then
                print('using alt model ')
            end
        end

        if k:StartsWith("On") then
            self:StoreOutput(k, v)
        end
    end

    function ENT:ChooseSkins()
        if self.AltModel then
            self:SetModel(CORE_SKINS_MODEL)
        else
            self:SetModel(CORE_MODEL)
        end

        self:SetSkin(self.ModelSkin or 0)
    end

    function ENT:SetIdleSequence(sequence)
        self.IdleOverrideSequence = self:LookupSequence(sequence)
        self:ResetSequence(self.IdleOverrideSequence)
    end

    function ENT:ClearIdleSequence()
        self.IdleOverrideSequence = nil 
        self:SetIdealActivity(ACT_IDLE)
    end

    function ENT:RunAI()
        if not self.IdleOverrideSequence and not self:GetAttached() then
            self:MaintainActivity()
        elseif self.IdleOverrideSequence and self:IsSequenceFinished() then
            self:ResetSequence(self.IdleOverrideSequence)
        end
    end

    function ENT:TaskStart_CustomIdle(data)
    end

    function ENT:Task_CustomIdle(data)
        self:SetSequence(self.IdleOverrideSequence)
    end

    function ENT:OnPhysgunPickup(ply, ent)
        if self:GetPickupEnabled() and self:GetDropEnabled() then
            self:TriggerOutput("OnPlayerPickup")
        end

        return self:GetPickupEnabled()
    end

    function ENT:OnPhysgunDrop(ply, ent)
        if self:GetPickupEnabled() and self:GetDropEnabled() then
            self:TriggerOutput("OnPlayerDrop")
        end
    end

    function ENT:OnPlayerPickup(ply, ent)
        if self:GetDropEnabled() then
            self:TriggerOutput("OnPlayerPickup")
        end
    end

    function ENT:OnPlayerDrop(ply, ent, thrown)
        if self:GetDropEnabled() then
            self:TriggerOutput("OnPlayerDrop")            
        end
    end
    
    function ENT:GravGunPickupAllowed(ply)
        return self:GetPickupEnabled() and self:GetDropEnabled()
    end

    function ENT:OnGravGunPunt(ply)
        return false
    end

    function ENT:Use(activator, caller, useType, value)
        if not self:GetDropEnabled() then
            self:SetParent(NULL)
            self:PhysicsInit(SOLID_VPHYSICS)
            activator:PickupObject(self)
            return
        end

        if IsValid(activator) and activator:IsPlayer() and not activator:IsPlayerHolding() and self:GetPickupEnabled() then
            self:SetParent(NULL)
            self:PhysicsInit(SOLID_VPHYSICS)
            activator:PickupObject(self)
        end
    end

    function ENT:GetPreferredCarryAngles()
        return Angle(sv_personality_core_pca_pitch:GetFloat(), sv_personality_core_pca_yaw:GetFloat(), sv_personality_core_pca_roll:GetFloat())
    end
end

function ENT:Draw(flags)
    self:DrawModel()

    if self:GetFlashlightEnabled() and self.FlashLightAttachment ~= -1 then
        local attach = self:GetAttachment(self.FlashLightAttachment)

        if not IsValid(self.ProjectedTexture) then
            self.ProjectedTexture = ProjectedTexture()
            self.ProjectedTexture:SetFOV(85)
            self.ProjectedTexture:SetEnableShadows(true)
            self.ProjectedTexture:SetTexture("effects/flashlight001_improved")
            self.ProjectedTexture:SetPos(attach.Pos)
            self.ProjectedTexture:SetAngles(attach.Ang)
            self.ProjectedTexture:Update()
        else
            self.ProjectedTexture:SetPos(attach.Pos)
            self.ProjectedTexture:SetAngles(attach.Ang)
            self.ProjectedTexture:Update()
        end

        if not IsValid(self.FlashlightEffect) then
            self.FlashlightEffect = CreateParticleSystem(self, "flashlight_thirdperson", PATTACH_POINT_FOLLOW, self:LookupAttachment("flashlightAttachment"))

            if IsValid(self.FlashlightEffect) then
                self.FlashlightEffect:StartEmission(true)
            
                self.FlashlightEffect:AddControlPoint(0, self, PATTACH_CUSTOMORIGIN)
                self.FlashlightEffect:AddControlPoint(2, self, PATTACH_CUSTOMORIGIN)
            end
        else
            local tr = util.TraceLine({
                start = attach.Pos,
                endpos = attach.Pos + attach.Ang:Forward() * 256,
                mask = MASK_SHOT_PORTAL -- idk, they're removing CONTENTS_GRATE
            })

            self.FlashlightEffect:SetControlPoint(1, attach.Pos)
            self.FlashlightEffect:SetControlPoint(2, tr.HitPos)
            self.FlashlightEffect:SetControlPointForwardVector(1, attach.Ang:Forward())
        end

        local dlight = DynamicLight( self:EntIndex() )
        if ( dlight ) then
            dlight.pos = attach.Pos + attach.Ang:Forward() * 2
            dlight.r = 31
            dlight.g = 31
            dlight.b = 31
            dlight.brightness = 2
            dlight.decay = 1000
            dlight.size = 64
            dlight.dietime = CurTime() + 1e10
        end
    else
        if IsValid(self.ProjectedTexture) then
            self.ProjectedTexture:Remove()
            self.ProjectedTexture = nil
        end

        if IsValid(self.FlashlightEffect) then
            self.FlashlightEffect:StopEmission()
            self.FlashlightEffect = nil
        end
    end
end

function ENT:UpdateTransmitState()
    return self:GetFlashlightEnabled() and TRANSMIT_ALWAYS or TRANSMIT_PVS
end

function ENT:Think()
    self:NextThink(CurTime())
    return true
end