local shared=require("units.shared")
return {mode="hold", update=function(u,dt,game) shared.update(u,dt,game,"hold") end}
