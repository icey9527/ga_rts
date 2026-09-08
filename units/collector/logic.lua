local shared=require("units.shared")
return {mode="stationary", update=function(u,dt,game) shared.update(u,dt,game,"stationary") end}
