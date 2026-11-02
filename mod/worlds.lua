-- Keep each cartridge family's graph and native runtime adapter isolated.
return function(G1,G2)
  local W={gen1=G1,gen2=G2,defaults=G1.defaults,choices=G1.choices,enabled=G1.enabled,checked=G1.checked,normalize=G1.normalize}
  local function module(value)
    if value and (value.generation==2 or (value.data and value.data.gen2Encounters)) then return G2 end
    return G1
  end
  for _,name in ipairs({'preflight','identity','build','replay','party','levelCap','journal','tracker','hint','present'}) do
    local key=name
    W[key]=function(first,...) return module(first)[key](first,...) end
  end
  for _,name in ipairs({'saveRun','restoreRun'}) do
    local key=name
    W[key]=function(mod,a,...) return module(a)[key](mod,a,...) end
  end
  function W.release(a) G1.release(a);G2.release(a) end
  function W.prepare(a) if a.generation==2 then G2.prepare(a) end end
  function W.install(mod,R,I) G1.install(mod,R,I);G2.install(mod,R,I) end
  return W
end
