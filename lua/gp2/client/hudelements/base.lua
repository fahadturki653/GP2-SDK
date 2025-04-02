-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Base
-- ----------------------------------------------------------------------------

AddCSLuaFile()

local PANEL = {}

local cl_drawhud = GetConVar("cl_drawhud")

function PANEL:Init()
    self:SetVisible(true)
end

function PANEL:Think()

end

function PANEL:ShouldDraw()
    if not cl_drawhud:GetBool() then return false end

    return true
end

vgui.Register("GP2Panel", PANEL, "Panel")