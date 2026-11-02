local maps=dofile('tests/support/gen1_portals.lua')
maps.CERULEAN_CITY.warps[2].destMap='CERULEAN_MELANIES_HOUSE'
maps.ROUTE_11.warps[2].destWarp=1;maps.ROUTE_11.warps[4].destWarp=3
maps.ROUTE_2.warps[7]={x=17,y=35,destMap='ROUTE_2_GATE',destWarp=2}
return maps
