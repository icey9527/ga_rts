local shared=require("units.shared")
return {mode="orbit", update=function(u,dt,game) shared.update(u,dt,game,"orbit") end}
