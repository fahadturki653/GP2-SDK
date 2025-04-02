-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Tractor Beam Emitter
-- ----------------------------------------------------------------------------

AddCSLuaFile()
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

PrecacheParticleSystem("tractor_beam_arm")
PrecacheParticleSystem("tractor_beam_core")

function ENT:KeyValue(k, v)
    if k == "use128model" then
        self.Use128Model = tobool(v)
    elseif k == "StartEnabled" then
        self.StartEnabled = true
    elseif k == "linearForce" then
        self.StartLinearForce = tonumber(v)
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", "Enabled") -- shared var for particles
    self:NetworkVar("Float", "_LinearForce") -- shared var for particles

    if CLIENT then
        self:NetworkVarNotify("Enabled", self.OnEnabled)
    end
end

function ENT:Initialize()
    if SERVER then
        self.RotationStart = 0
        self.RotationStartTime = CurTime()
        self.RotationDuration = 0
        self.RotationTarget = 0

        self.ArmatureStart = 0
        self.ArmatureTarget = 0
        self.ArmatureDuration = 0.75
        self.ArmatureStartTime = CurTime()

        self.StartLinearForce = self.StartLinearForce or 0
        self:Set_LinearForce(self.StartLinearForce)

        if self.Use128Model then
            self:SetModel("models/props_ingame/tractor_beam_128.mdl")
        else
            self:SetModel("models/props/tractor_beam_emitter.mdl")
        end
    
        self:PhysicsInitStatic(SOLID_VPHYSICS)
        self:ResetSequence("tractor_beam_rotation")
        self:AddEffects(EF_NOSHADOW)

        timer.Simple(0, function()
            if self.StartEnabled then
                self:Enable()
            end
        end)
    end
end

function ENT:AcceptInput(name, activator, caller, data)
    name = name:lower()

    if name == "enable" then
        self:Enable()  
    elseif name == "disable" then
        self:Disable()
    elseif name == "setlinearforce" then
        self:SetLinearForce(tonumber(data))
    end
end 

if SERVER then
    function ENT:Enable()
        if self:GetEnabled() then return end

        if not (self.Beam and IsValid(self.Beam)) then
            self.Beam = ents.Create("projected_tractor_beam_entity")
            local ang = self:GetAngles()
            self.Beam:Spawn()
            self.Beam:SetPos(self:GetPos())
            self.Beam:SetParent(self)
            self.Beam:SetRadius(self.Use128Model and 55 or 60)
            self.Beam:SetLinearForce(self.StartLinearForce)
            self.Beam:SetAngles(ang)
        end

        self.RotationStart = self:CalculateRotationPose()
        self.RotationStartTime = CurTime()
        self.RotationDuration = 0.25
        self.RotationTarget = self.StartLinearForce * 0.0083333338

        self.ArmatureStart = self:CalculateArmaturePose()
        self.ArmatureTarget = self.StartLinearForce < 0 and 0 or 1
        self.ArmatureDuration = 0.75
        self.ArmatureStartTime = CurTime()

        self:SetEnabled(true)

        if self.sndBeam then
            self.sndBeam:Stop()
        end

        self.sndBeam = CreateSound(self, self.StartLinearForce < 0 and "VFX.TBeamNegPolarity" or "VFX.TBeamPosPolarity")
        self.sndBeam:Play()

        self.sndSpinLp = CreateSound(self, "VFX.TbeamEmitterSpinLp")
        self.sndSpinLp:Play()
    end

    function ENT:Disable()
        if not self:GetEnabled() then return end

        if self.Beam and IsValid(self.Beam) then
            self.Beam:Remove()
            self.Beam = nil
        end

        self.RotationStart = self:CalculateRotationPose()
        self.RotationStartTime = CurTime()
        self.RotationDuration = 1.5
        self.RotationTarget = 0.0

        self.ArmatureStart = self:CalculateArmaturePose()
        self.ArmatureTarget = 0.5
        self.ArmatureDuration = 1.5
        self.ArmatureStartTime = CurTime()

        if self.sndBeam then
            self.sndBeam:Stop()
        end

        if self.sndSpinLp then
            self.sndSpinLp:FadeOut(self.RotationDuration)
        end

        self:SetEnabled(false)
    end

    function ENT:SetLinearForce(force)
        if self.StartLinearForce == force then
            return
        end

        force = force or 250
        
        if self.Beam and IsValid(self.Beam) then
            self.Beam:SetLinearForce(force)
        end

        if self.StartLinearForce ~= force then
            self.RotationStart = self:CalculateRotationPose()
            self.RotationStartTime = CurTime()
            self.RotationDuration = 0.25
            self.RotationTarget = force * 0.0083333338
    
            self.ArmatureStart = self:CalculateArmaturePose()
            self.ArmatureTarget = self.StartLinearForce < 0 and 0 or 1
            self.ArmatureDuration = 0.75
            self.ArmatureStartTime = CurTime()
        end

        if self.sndBeam then
            self.sndBeam:Stop()
        end

        self.sndBeam = CreateSound(self, self.StartLinearForce < 0 and "VFX.TBeamNegPolarity" or "VFX.TBeamPosPolarity")
        self.sndBeam:Play()

        self.StartLinearForce = force
        self:Set_LinearForce(self.StartLinearForce)
    end
end

function ENT:Think()
    if SERVER then
        self:SetPoseParameter("reversal", self:CalculateArmaturePose())
        self:SetPlaybackRate(self:CalculateRotationPose())
    else
        if not PropTractorBeam.IsAdded(self) then
            PropTractorBeam.AddToRenderList(self)
        end
    end
    
    self:NextThink(CurTime())
    return true
end

function ENT:CalculateRotationPose()
    local curTime = CurTime()
    
    if curTime > (self.RotationStartTime + self.RotationDuration) then
        return self.RotationTarget
    end

    local rotationGoal = self.RotationStart
    local rotationEndTime = self.RotationStartTime + self.RotationDuration
    if self.RotationStartTime == rotationEndTime then
        if curTime < rotationEndTime then
            rotationGoal = self.RotationStart
        else
            rotationGoal = self.RotationTarget
        end
    else
        local elapsedTime = (curTime - self.RotationStartTime) / (rotationEndTime - self.RotationStartTime)
        local factor = (elapsedTime * elapsedTime)
        rotationGoal = (((factor * 3.0) - (factor * 2.0 * elapsedTime)) * (self.RotationTarget - rotationGoal)) + rotationGoal
    end

    local linearForceFactor = self.StartLinearForce * 0.0083333338

    if linearForceFactor ~= 0.0 then
        local isInBounds
        if linearForceFactor >= 0.0 then
            isInBounds = rotationGoal <= linearForceFactor
        else
            isInBounds = linearForceFactor <= rotationGoal
        end
        if not isInBounds then
            return linearForceFactor
        end
    end
    
    return rotationGoal
end

function ENT:CalculateArmaturePose()
    local curTime = CurTime()

    if curTime > (self.ArmatureStartTime + self.ArmatureDuration) then
        return self.ArmatureTarget
    end

    local armatureEndTime = self.ArmatureStartTime + self.ArmatureDuration
    local armatureGoal = self.ArmatureStart

    if self.ArmatureStartTime == armatureEndTime then
        if curTime < armatureEndTime then
            armatureGoal = self.ArmatureStart
        else
            armatureGoal = self.ArmatureTarget
        end
    else
        local elapsedTime = (curTime - self.ArmatureStartTime) / (armatureEndTime - self.ArmatureStartTime)
        armatureGoal = (((elapsedTime * elapsedTime * 3.0) - ((elapsedTime * elapsedTime * 2.0) * elapsedTime))
            * (self.ArmatureTarget - armatureGoal)) + armatureGoal
    end

    if armatureGoal < 0.0 then
        return 0.0
    elseif armatureGoal > 1.0 then
        return 1.0
    else
        return armatureGoal
    end
end

function ENT:OnRemove()
	timer.Simple( 0, function()
		if not IsValid( self ) then
			if IsValid(self.sndBeam) then
                self.sndBeam:Stop()
            end
		end
	end)
end

if CLIENT then
    function ENT:OnEnabled(name, old, new)
        -- print('OnEnabled ' .. (new and 'ENABLED' or "DISABLED"))

        -- if new then
        --     self.EmitterParticles = {}

        --     for i = 1, 3 do 
        --         self.EmitterParticles[i] = CreateParticleSystem(self, "discouragement_beam_burn", PATTACH_POINT_FOLLOW, self:LookupAttachment("emitter" .. i)) 
        --         self.EmitterParticles[i]:SetControlPoint(1, Vector(255,255,255))
        --     end
        -- else
        --     for i = 1, 3 do
        --         local particle = self.EmitterParticles[i] 

        --         if IsValid(particle) then
        --             particle:StopEmission()
        --         end
        --     end
        -- end
    end
end