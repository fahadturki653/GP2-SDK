ENT.Type = "brush"
ENT.TouchingEnts = 0
ENT.Button = NULL

local SF_INACTIVE = 1

function ENT:KeyValue(k, v)
    if k:StartsWith("On") then
        self:StoreOutput(k, v)
    end

    if k == "spawnflags" and bit.band(tonumber(v), SF_INACTIVE) ~= 0 then
        self:SetEnabled(false)
    end
end

ENT.__input2func = {
    ["enable"] = function(self, activator, caller, data)
        self:SetEnabled(true)
    end,
    ["disable"] = function(self, activator, caller, data)
        if not self:GetEnabled() then return end

        self:SetEnabled(false)
    end,
    ["toggle"] = function(self, activator, caller, data)
        self:SetEnabled(not self:GetEnabled())
    end,
}

function ENT:AcceptInput(name, activator, caller, data)
    name = name:lower()
    local func = self.__input2func[name]

    if func and isfunction(func) then
        func(self, activator, caller, data)
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", "Enabled")

    if SERVER then
        self:SetEnabled(true)
    end
end

function ENT:Initialize()
    self:SetSolid(SOLID_BBOX)
    self:SetTrigger(true)

    self.TrackedPortals = {}
end

function ENT:Think()
    if not self:GetEnabled() then return end
    for portal in pairs(PortalManager.Portals) do
        if IsValid(portal) then
            local isInside = self:IsPortalInside(portal)

            -- If portal is inside bounding box and not already tracked
            if isInside and not self.TrackedPortals[portal] then
                self.TrackedPortals[portal] = true
                self:TriggerOutput("OnStartTouchPortal", portal)
                print("Portal entered trigger and added to tracking list")
            -- If portal is not inside anymore but was tracked
            elseif not isInside and self.TrackedPortals[portal] then
                self.TrackedPortals[portal] = nil
                self:TriggerOutput("OnEndTouchPortal", portal)
                print("Portal left trigger and removed from tracking list")
            end
        end
    end

    self:NextThink(CurTime() + 0.25)
    return true
end

-- Check if the entity is within the bounding box of this trigger
function ENT:IsPortalInside(ent)
    local entPos = ent:GetPos()
    local mins, maxs = self:WorldSpaceAABB()

    return entPos.x >= mins.x and entPos.x <= maxs.x and
           entPos.y >= mins.y and entPos.y <= maxs.y and
           entPos.z >= mins.z and entPos.z <= maxs.z
end