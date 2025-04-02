-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Text
-- ----------------------------------------------------------------------------

ENT.Type = "point"

function ENT:KeyValue(k, v)
    if k == "message" then
        self.Message = v
    elseif k == "channel" then
        self.Channel = tonumber(v)
    elseif k == "x" then
        self.PosX = tonumber(v)
    elseif k == "y" then
        self.PosY = tonumber(v)
    elseif k == "effect" then
        self.EffectType = tonumber(v)
    elseif k == "fadein" then
        self.FadeInDuration = tonumber(v)
    elseif k == "fadeout" then
        self.FadeOutDuration = tonumber(v)
    elseif k == "holdtime" then
        self.HoldOutDuration = tonumber(v)
    elseif k == "fxtime" then
        self.FxTime = tonumber(v)
    elseif k == "color" then
        self.Clr = v
    elseif k == "color2" then
        self.Clr2 = v
    end
end

function ENT:Initialize()

end

function ENT:AcceptInput(name, activator, caller, data)
    name = name:lower()

    if name == "display" then
        self:Display(activator)
    elseif name == "setposx" then
        self.PosX = tonumber(data)
    elseif name == "setposy" then
        self.PosY = tonumber(data)
    elseif name == "settextcolor" then
        self.Clr = data
    elseif name == "settextcolor2" then
        self.Clr2 = data
    elseif name == "settext" then
        self.Message = data
    end
end

function ENT:Display(activator)
    local target = Entity(1)

    if IsValid(activator) and activator:IsPlayer() and not game.SinglePlayer() then
        target = activator
    end

    if not IsValid(target) then
        return
    end

    net.Start(GP2.Net.SendHudText)
        net.WriteInt(self.Channel or 0, 4)
        net.WriteString(self.Message or "")
        net.WriteFloat(self.PosX or 0)
        net.WriteFloat(self.PosY or 0)
        net.WriteInt(self.EffectType or 0, 8)
        net.WriteFloat(self.FadeInDuration or 0)
        net.WriteFloat(self.FadeOutDuration or 0)
        net.WriteFloat(self.HoldOutDuration or 0)
        net.WriteFloat(self.FxTime or 0)
        net.WriteString(self.Clr)
        net.WriteString(self.Clr2)
    
    if self:HasSpawnFlags(1) then
        net.Broadcast()
    else
        net.Send(target)
    end

    print('Sendng SendHudText')
end
 