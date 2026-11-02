-- Only the test runner needs this: the native game provides LuaJIT's bit module.
if not pcall(require,'bit') then
 package.loaded.bit=assert(load([[
 local B={}
 local function signed(x) x=x & 0xffffffff;return x>=0x80000000 and x-0x100000000 or x end
 function B.band(a,...) local v=a;for _,b in ipairs({...}) do v=v & b end;return signed(v) end
 function B.bor(a,...) local v=a;for _,b in ipairs({...}) do v=v | b end;return signed(v) end
 function B.bxor(a,...) local v=a;for _,b in ipairs({...}) do v=v ~ b end;return signed(v) end
 function B.bnot(a) return signed(~a) end
 function B.lshift(a,n) return signed(a << (n & 31)) end
 function B.rshift(a,n) return signed((a & 0xffffffff) >> (n & 31)) end
 B.tobit=signed
 return B
 ]]))()
end
