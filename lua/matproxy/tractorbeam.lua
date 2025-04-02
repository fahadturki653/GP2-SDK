-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Tractor Beam material proxy
-- ----------------------------------------------------------------------------

matproxy.Add( {
    name = "TractorBeam", 
    init = function( self, mat, values )
        -- Store the name of the variable we want to set
        self.ResultTo = values.resultvar
    end,
    bind = function( self, mat, ent )

   end 
} )