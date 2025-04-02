local portals = ents.FindByClass("prop_portal")

-- append to the portals list when a new portal is created
hook.Add("OnEntityCreated", "seamless_portals", function(ent)
    if ent:GetClass() == "prop_portal" then
        table.insert(portals, ent)
    end
end)

-- remove from the portals list when a portal is removed
hook.Add("EntityRemoved", "seamless_portals", function(ent)
    if ent:GetClass() == "prop_portal" then
        table.RemoveByValue(portals, ent)
    end
end)

-- add the exit portals positions to player's PVS
hook.Add("SetupPlayerVisibility", "seamless_portals", function(ply, viewEntity)
    if #portals == 0 then
        return
    end

    local distance = ply:GetInfoNum("gp2_portal_drawdistance", 250)
    local eyePos = IsValid(viewEntity) and viewEntity:GetPos() or ply:EyePos()
    local eyeAngle = IsValid(viewEntity) and viewEntity:GetAngles() or ply:EyeAngles()

    for _, portal in ipairs(portals) do
        if portal:IsValid() then
            local linkedPartner = portal:GetLinkedPartner()

            -- check the visibility of the portal and the existence of its exit portal before adding to the PVS
            if IsValid(linkedPartner) and ply:TestPVS(portal) 
                and PortalManager.ShouldRender(portal, eyePos, eyeAngle, distance) then
                
                AddOriginToPVS(linkedPartner:GetPos())
            end
        end
    end
end)