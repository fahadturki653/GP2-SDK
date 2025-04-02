-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Vscript entity
-- ----------------------------------------------------------------------------

ENT.Type = "point"

function ENT:KeyValue(k, v)
    local scope = self:GetOrCreateVScriptScope()

    if not scope.EntityGroup then
        scope.EntityGroup = {}
    end

    if k:StartsWith("Group") then
        local groupStr = k:sub(6)
        local groupIndex = tonumber(groupStr)

        if groupIndex then
            scope.EntityGroup[groupIndex] = ents.FindByName(v)[1]
        end
    end
end