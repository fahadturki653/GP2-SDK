-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Message (game_text)
-- ----------------------------------------------------------------------------

AddCSLuaFile()

local PANEL = {}
PANEL.BaseClass = baseclass.Get("GP2Panel")

PANEL.Channels = {
    [0] = nil,
    [1] = { 
        Alpha = 0,
        PosX = 0, PosY = 0, 
        Message = "", EffectType = 0, 
        FadeInDuration = 0, FadeOutDuration = 0, 
        HoldOutDuration = 0, FxTime = 0, 
        Clr = Color(255,255,255),
        Clr2 = Color(255,255,255)
    },
    [2] = { 
        Alpha = 0,
        PosX = 0, PosY = 0, 
        Message = "", EffectType = 0, 
        FadeInDuration = 0, FadeOutDuration = 0, 
        HoldOutDuration = 0, FxTime = 0, 
        Clr = Color(255,255,255),
        Clr2 = Color(255,255,255)
    },
    [3] = { 
        Alpha = 0,
        PosX = 0, PosY = 0, 
        Message = "", EffectType = 0, 
        FadeInDuration = 0, FadeOutDuration = 0, 
        HoldOutDuration = 0, FxTime = 0, 
        Clr = Color(255,255,255),
        Clr2 = Color(255,255,255)
    },
    [4] = { 
        Alpha = 0,
        PosX = 0, PosY = 0, 
        Message = "", EffectType = 0, 
        FadeInDuration = 0, FadeOutDuration = 0, 
        HoldOutDuration = 0, FxTime = 0, 
        Clr = Color(255,255,255),
        Clr2 = Color(255,255,255)
    },
    [5] = { 
        Alpha = 0,
        PosX = 0, PosY = 0, 
        Message = "", EffectType = 0, 
        FadeInDuration = 0, FadeOutDuration = 0, 
        HoldOutDuration = 0, FxTime = 0, 
        Clr = Color(255,255,255),
        Clr2 = Color(255,255,255) 
    },
}

net.Receive(GP2.Net.SendHudText, function(len, ply)
    local channel = net.ReadInt(4)

    local channelData = PANEL.Channels[channel]

    channelData.Message = language.GetPhrase(net.ReadString())
    channelData.PosX = net.ReadFloat()
    channelData.PosY = net.ReadFloat()
    channelData.EffectType = net.ReadInt(8)
    channelData.FadeInDuration = net.ReadFloat()
    channelData.FadeOutDuration = net.ReadFloat()
    channelData.HoldOutDuration = net.ReadFloat()
    channelData.FxTime = net.ReadFloat()
    local clr = net.ReadString():Split(" ")
    channelData.Clr = Color(tonumber(clr[1]) or 0, tonumber(clr[2]) or 0, tonumber(clr[3]) or 0, tonumber(clr[4]) or 255)
    
    local clr2 = net.ReadString():Split(" ")
    channelData.Clr2 = Color(tonumber(clr2[1]) or 0, tonumber(clr2[2]) or 0, tonumber(clr2[3]) or 0, tonumber(clr2[4]) or 255)

    channelData.Alpha = 255
    channelData.DieTime = CurTime() + channelData.FadeInDuration + channelData.HoldOutDuration
    channelData.SpawnTime = CurTime()

    print('got text')
end)

function PANEL:Init()
    self:SetWidth(ScrW())
    self:SetTall(ScrH())
    self:SetParent(GetHUDPanel())
end

function PANEL:Paint(w, h)
    for i, data in ipairs(self.Channels) do
        if i == 2 then
            surface.SetFont("CenterPrintText2Blur")
        elseif i == 3 then
            surface.SetFont("CenterPrintText1Blur")
        else
            surface.SetFont("CenterPrintText0Blur")
        end

        data.DieTime = data.DieTime or 0
        data.SpawnTime = data.SpawnTime or CurTime()

        local message = data.Message

        local width, height = surface.GetTextSize(data.Message)

        local posX = w * (data.PosX ~= -1 and data.PosX or 0.5) - (width / 2)
        local posY = h * (data.PosY ~= -1 and data.PosY or 0.5)

        local timeSinceStart = CurTime() - data.SpawnTime

        surface.SetTextColor(0, 0, 0, data.Alpha)
        surface.SetTextPos(posX, posY)
        surface.DrawText(message)
        surface.SetTextPos(posX, posY)
        surface.DrawText(message)

        if i == 2 then
            surface.SetFont("CenterPrintText2")
        elseif i == 3 then
            surface.SetFont("CenterPrintText1")
        else
            surface.SetFont("CenterPrintText0")
        end
        
        -- Render underlying text for Scan Out
        if data.EffectType == 2 then
            surface.SetTextColor(data.Clr2.r, data.Clr2.g, data.Clr2.b, data.Alpha)
            surface.SetTextPos(posX, posY)
    
            surface.DrawText(message)
        end

        surface.SetTextColor(data.Clr.r, data.Clr.g, data.Clr.b, data.Alpha)
        surface.SetTextPos(posX, posY)

        if data.EffectType == 2 then
            local fillProgress = math.min(1, timeSinceStart / data.FxTime)
            local charCount = math.floor(#message * fillProgress)
            surface.DrawText(message:sub(1, charCount))
        else
            surface.DrawText(message)
        end

        if CurTime() > data.DieTime then
            local timeSinceDie = CurTime() - data.DieTime
            local fadeProgress = timeSinceDie / data.FadeOutDuration
            data.Alpha = math.max(0, data.Alpha * (1 - fadeProgress))
        else
            local fadeProgress = math.min(1, timeSinceStart / data.FadeInDuration)
            data.Alpha = 255 * fadeProgress
        end
    end
end

function PANEL:ShouldDraw()
    if not self.BaseClass.ShouldDraw() then
        return false
    end

    return true
end

vgui.Register("GP2HudMessage", PANEL, "GP2Panel")