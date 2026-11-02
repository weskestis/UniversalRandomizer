-- Shared modern controller menu. It owns a 640x360 surface in either engine;
-- no cartridge fonts, palettes, sprite methods or global input are replaced.
local Menu={}; Menu.__index=Menu
local W,H=640,360
local C={bg={.035,.055,.10},panel={.065,.09,.15},line={.14,.19,.27},
  text={.92,.95,1},muted={.57,.65,.76},accent={.29,.87,.72},select={.10,.22,.25},warning={1,.72,.35}}
local fonts={}
local function font(size)
  if not fonts[size] then fonts[size]=love.graphics.newFont(size) end
  return fonts[size]
end
local function text(value,x,y,size,color)
  local G=love.graphics;G.setColor(color or C.text);G.setFont(font(size));G.print(tostring(value or ''),x,y)
end
local function box(color,x,y,w,h,r)
  love.graphics.setColor(color);love.graphics.rectangle('fill',x,y,w,h,r or 0,r or 0)
end
local function prefixLength(s,f,width)
  local best=0
  for i=1,#s do
    local nextByte=s:byte(i+1)
    if not nextByte or nextByte<128 or nextByte>=192 then
      if f:getWidth(s:sub(1,i))>width then break end
      best=i
    end
  end
  return best
end
local function fit(value,size,width)
  local s=tostring(value or '');local f=font(size)
  if f:getWidth(s)<=width then return s end
  -- Clip labels only at UTF-8 boundaries. Full text is available in Help.
  return s:sub(1,prefixLength(s,f,width-f:getWidth('...')))..'...'
end
local function wrap(value,size,width)
  -- Split unbroken error paths as well as prose so nothing is discarded.
  local f=font(size);local lines={}
  for paragraph in (tostring(value or '')..'\n'):gmatch('(.-)\n') do
    local line=''
    for word in paragraph:gmatch('%S+') do
      if line~='' and f:getWidth(line..' '..word)>width then lines[#lines+1]=line;line='' end
      while f:getWidth(word)>width do
        local n=prefixLength(word,f,width)
        if n==0 then break end
        if line~='' then lines[#lines+1]=line;line='' end
        lines[#lines+1]=word:sub(1,n);word=word:sub(n+1)
      end
      line=line=='' and word or (line..' '..word)
    end
    lines[#lines+1]=line
  end
  return lines
end
function Menu.new(game,title,items,opts)
  opts=opts or {}
  return setmetatable({game=game,title=title,items=items or {},opts=opts,
    urMenu=true,index=1,scroll=0,rows=7,helpScroll=0,helpClock=0,helpFocus=false,
    footer=opts.footer,wrap=opts.wrap~=false,holdsUIAnchors=true,isOpaque=true,
    sgbPalettes=false,onChoose=opts.onChoose,onCancel=opts.onCancel,
    onAdjust=opts.onAdjust,onSelectKey=opts.onSelectKey,subtitle=opts.subtitle,
    help=opts.help,summary=opts.summary,locked=opts.locked},Menu)
end
function Menu:uiSize() return W,H end
function Menu:drawsWidescreen() return true end
function Menu:close()
  local s=self.game.stack
  if s and s.top and s:top()==self then s:pop() end
end
function Menu:isLocked() return type(self.locked)=='function' and self.locked() or self.locked==true end
function Menu:resetHelp() self.helpScroll=0;self.helpClock=0;self.helpKey=nil end
function Menu:sync()
  self.index=math.max(1,math.min(#self.items,self.index))
  self.scroll=math.max(0,math.min(self.scroll,math.max(0,#self.items-self.rows)))
  if self.index>self.scroll+self.rows then self.scroll=self.index-self.rows end
  if self.index<=self.scroll then self.scroll=self.index-1 end
end
function Menu:helpContent()
  local item=self.items[self.index] or {}
  local body=type(self.footer)=='function' and self.footer() or self.footer
  if not body then body=type(self.help)=='function' and self.help(item,self) or item.help or self.help end
  return tostring(body or ((item.label or self.title)..'\n\nA: choose. Left / right: change a value. B: back. SELECT: focus this guide and scroll with up / down.')),tostring(item.helpTitle or item.label or self.title)
end
function Menu:helpLayout()
  local body,title=self:helpContent();local key=title..'\n'..body
  if self.helpKey~=key then
    self.helpKey=key;self.helpLines=wrap(body,14,220);self.helpTitle=wrap(title,16,220)
    self.helpScroll=0;self.helpClock=0
  end
  local titleLines=math.min(2,#self.helpTitle)
  self.helpTop=105+titleLines*20
  self.helpRows=math.max(1,math.floor((284-self.helpTop)/19))
  self.helpMax=math.max(0,#self.helpLines-self.helpRows)
  self.helpScroll=math.max(0,math.min(self.helpMax,self.helpScroll))
end
function Menu:cancel()
  if self:isLocked() then return end
  if self.helpFocus then self.helpFocus=false;return end
  if self.onCancel then self.onCancel(self) else self:close() end
end
function Menu:update(dt)
  if self.refresh then self:refresh() end
  local now=love and love.timer and love.timer.getTime and love.timer.getTime()
  local elapsed=now and self.lastTime and math.max(0,math.min(.25,now-self.lastTime)) or (dt or 1/60)
  self.lastTime=now;self:sync()
  local input=self.game.input
  if not input then return end
  if self:isLocked() then self.hold=nil;return end
  if input:wasPressed('b') then self:cancel();return end
  if input:wasPressed('select') then self.helpFocus=not self.helpFocus;self.hold=nil;return end
  local direction
  for _,d in ipairs({'up','down','left','right'}) do
    if input:wasPressed(d) then direction=d;self.hold=d;self.repeatTime=.40;break end
  end
  if not direction and self.hold then
    if input.isDown and input:isDown(self.hold) then
      self.repeatTime=self.repeatTime-elapsed
      if self.repeatTime<=0 then direction=self.hold;self.repeatTime=.13 end
    else self.hold=nil end
  end
  if self.helpFocus then
    if direction=='up' or direction=='down' then
      self.helpScroll=math.max(0,math.min(self.helpMax or 0,self.helpScroll+(direction=='up' and -1 or 1)))
    elseif direction=='left' then self.helpScroll=0
    elseif direction=='right' then self.helpScroll=self.helpMax or 0
    elseif input:wasPressed('a') then self.helpFocus=false end
    return
  end
  if direction=='up' or direction=='down' then
    local next=self.index+(direction=='up' and -1 or 1)
    if self.wrap and #self.items>0 then next=(next-1)%#self.items+1 end
    self.index=math.max(1,math.min(#self.items,next));self:sync();self:resetHelp()
  elseif direction=='left' or direction=='right' then
    if self.onAdjust then self.onAdjust(self.items[self.index],self,direction=='left' and -1 or 1);self:sync();self:resetHelp() end
  elseif input:wasPressed('a') then
    if self.onChoose then self.onChoose(self.items[self.index],self);self:sync();self:resetHelp() end
  else
    self.helpClock=self.helpClock+elapsed
    if (self.helpMax or 0)>0 then
      local delay=self.helpScroll==0 and 5 or (self.helpScroll==self.helpMax and 5 or 2.2)
      if self.helpClock>=delay then
        self.helpScroll=self.helpScroll==self.helpMax and 0 or self.helpScroll+1;self.helpClock=0
      end
    end
  end
end
-- Points are mapped from the host viewport; a gesture owns one live menu.
function Menu:pointer(e,x,y)
  if e.phase=='cancelled' then self.pointerCapture=nil;return true end
  if self:isLocked() then self.pointerCapture=nil;return true end
  local function target(px,py)
    if px<0 or px>640 or py<0 or py>360 then return end
    if py>=320 and py<=355 then return 'footer',math.min(6,math.max(1,math.floor(px/ (640/6))+1)) end
    if px>=22 and px<=350 and py>=76 and py<=300 then
      local i=self.scroll+math.floor((py-76)/32)+1
      if self.items[i] then return 'row',i end
    end
    if px>=368 and px<=624 and py>=68 and py<=312 then return 'guide',1 end
  end
  if e.phase=='pressed' then
    if e.button and e.button~=1 then return true end
    if self.pointerCapture then return true end
    local kind,index=target(x,y)
    self.pointerCapture={id=e.id,kind=kind,index=index,x=x,y=y,lastY=y,scroll=self.scroll,help=self.helpScroll}
    if kind=='row' then self.index=index;self:resetHelp() end
    return true
  end
  local c=self.pointerCapture
  if not c or c.id~=e.id then return true end
  if e.phase=='moved' then
    local dx,dy=x-c.x,y-c.y;c.drag=c.drag or dx*dx+dy*dy>100
    if c.drag and c.kind=='guide' then self.helpFocus=true;self.helpScroll=math.max(0,math.min(self.helpMax or 0,c.help+math.floor(-dy/19)))
    elseif c.drag and c.kind=='row' then
      self.scroll=math.max(0,math.min(math.max(0,#self.items-self.rows),c.scroll+math.floor(-dy/32)))
      self.index=math.max(self.scroll+1,math.min(self.scroll+self.rows,self.index))
    end
  elseif e.phase=='released' then
    self.pointerCapture=nil
    local kind,index=target(x,y)
    if not c.drag and c.kind==kind and c.index==index then
      if kind=='row' then if self.onChoose then self.onChoose(self.items[index],self) end
      elseif kind=='guide' then self.helpFocus=not self.helpFocus
      elseif kind=='footer' then
        if index==1 then self:cancel()
        elseif index==2 or index==3 then
          self.index=math.max(1,math.min(#self.items,self.index+(index==2 and -1 or 1)));self:sync();self:resetHelp()
        elseif index==4 or index==5 then if self.onAdjust then self.onAdjust(self.items[self.index],self,index==4 and -1 or 1);self:resetHelp() end
        else self.helpFocus=not self.helpFocus end
      end
    end
  end
  return true
end
function Menu:draw()
  local G=love.graphics;G.push('all');self:sync();self:helpLayout()
  box(C.bg,0,0,W,H)
  text('UNIVERSAL RANDOMIZER',20,13,11,C.accent)
  text(self.title,20,30,23)
  local sub=type(self.subtitle)=='function' and self.subtitle() or self.subtitle
  if sub then
    local s=fit(sub,12,270);text(s,620-font(12):getWidth(s),20,12,C.muted)
  end
  box(C.panel,16,68,340,244,10);box(C.panel,368,68,256,244,10)
  for row=1,self.rows do
    local index=self.scroll+row;local item=self.items[index]
    if not item then break end
    local y=76+(row-1)*32
    if index==self.index then
      box(C.select,22,y,328,30,5);box(C.accent,22,y+6,3,18,1)
    end
    local right=type(item.right)=='function' and item.right() or item.right
    local rightText=right and fit(right,13,144) or ''
    local labelWidth=right and math.max(120,304-font(13):getWidth(rightText)-12) or 304
    text(fit(item.label,14,labelWidth),32,y+7,14,index==self.index and C.text or C.muted)
    if right then text(rightText,340-font(13):getWidth(rightText),y+8,13,C.accent) end
  end
  if #self.items>self.rows then
    local th=224*self.rows/#self.items;local ty=78+(224-th)*self.scroll/math.max(1,#self.items-self.rows)
    box(C.line,351,78,2,224);box(C.accent,351,ty,2,th)
  end
  text(self.helpFocus and 'GUIDE - SCROLL WITH UP / DOWN' or 'SETTING GUIDE',382,82,10,C.accent)
  for i=1,math.min(2,#self.helpTitle) do text(self.helpTitle[i],382,101+(i-1)*20,16) end
  for i=1,self.helpRows do
    local line=self.helpLines[i+self.helpScroll]
    if line then text(line,382,self.helpTop+(i-1)*19,14,C.muted) end
  end
  if self.helpMax>0 then
    text((self.helpScroll+1)..'-'..math.min(#self.helpLines,self.helpScroll+self.helpRows)..' / '..#self.helpLines,382,293,10,C.muted)
    text(self.helpFocus and 'B: return' or 'Auto scroll / SELECT: read',445,293,10,C.accent)
  end
  local foot=self.helpFocus and 'UP / DOWN  Scroll guide     LEFT / RIGHT  Top / end     B  Return'
    or 'UP / DOWN  Navigate    LEFT / RIGHT  Change    A  Choose    B  Back    SELECT  Guide'
  if self:isLocked() then foot='Validating your settings. Please wait...' end
  if self:isLocked() then text(foot,20,329,11,C.muted)
  else
    for i,label in ipairs({'Back','Up','Down','Previous','Next','Guide'}) do
      local x=8+(i-1)*640/6;box(C.select,x,322,98,29,4);text(label,x+12,330,11,C.muted)
    end
  end
  G.pop()
end
function Menu:drawWidescreen(w,h)
  local G=love.graphics;G.push('all');box(C.bg,0,0,w,h)
  local scale=math.min(w/W,h/H)
  G.translate((w-W*scale)/2,(h-H*scale)/2);G.scale(scale,scale);self:draw();G.pop()
end
return Menu
