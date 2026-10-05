-- Idalia BladeTrail - Character 1 trail system port.
-- Based on Alba/MariaTrail's continuous UV-stretched membrane engine,
-- adapted to Idalia's CombatSystem and configurable BladeTrail source part.
BladeTrailMotion=BladeTrailMotion or{}
local T=BladeTrailMotion

T.enabled=T.enabled~=false

-- Trail tuning --------------------------------------------------------------
T.copies=T.copies or 56
T.lifeTicks=T.lifeTicks or 12
T.opacity=T.opacity or .88
T.minMovement=T.minMovement or .010
T.segmentLength=T.segmentLength or .10
T.maxSubdivisions=T.maxSubdivisions or 10
T.maxBakePerCapture=T.maxBakePerCapture or 5
T.teleportRejectDistance=T.teleportRejectDistance or 4.0

-- Pool construction is staged to avoid a one-tick model-copy spike.
T.tickBudgetFraction=T.tickBudgetFraction or .78
T.initialCopies=T.initialCopies or 16
T.buildPerTick=T.buildPerTick or 4

-- One Blade trail engine owns the live-strip budget. Existing membranes are
-- allowed to live for lifeTicks; load pressure reduces NEW subdivision density
-- instead of deleting the already-visible tail early. The hard pool cap still
-- protects against unbounded geometry growth.
T.maxLiveStrips=T.maxLiveStrips or 56
T.captureStopFraction=T.captureStopFraction or .90

T.emissive=T.emissive~=false
-- Actual native EMISSIVE, not the beacon-based CUTOUT_EMISSIVE_SOLID test.
-- No opaque/cutout base pass is added. Reload after changing these settings.
-- "EYES" is an optional diagnostic: in the Figura 1.20 branch it uses the same
-- native renderer, but is not caught by Figura's EMISSIVE-only Iris substitution.
-- Shader packs can still alter either mode; Lua cannot force their depth state.
T.trailRenderType="EMISSIVE"
T.emissiveTwoSided=T.emissiveTwoSided~=false
-- Older native eyes renderers ignore alpha when adding RGB. Fade brightness too.
-- Keep alpha fading as well for clients whose emissive path does honor it.
T.emissiveFadeRGB=T.emissiveFadeRGB~=false
T.appliedTrailRenderType=nil
T.renderTypeWarning=nil
T.stretchTexture=T.stretchTexture~=false
T.textureFlipSweep=T.textureFlipSweep==true
T.textureFlipAlong=T.textureFlipAlong==true
T.ribbonFaceSign=T.ribbonFaceSign or 1 -- +1 = EAST-like face, -1 = WEST-like face

-- Use Trail in normal form and TrailAlt in transformed form.
-- Keep the selected BladeTrail face's AUTHORED UV layout for both textures.
-- Replacement textures must match that layout; no UV stretching logic changes here.
-- Set false to use only the texture assigned to BladeTrail in Blockbench.
T.useTextureOverride=false
T.trailTextureName=T.trailTextureName or "Trail"
T.trailTextureAltName=T.trailTextureAltName or "TrailAlt"
T.trailTexture=nil
T.trailTextureAlt=nil
T.appliedTrailTexture=nil
T.appliedTrailTextureAlt=nil
T.lastError=nil
T.started=false
T.ready=false
T.tickSerial=T.tickSerial or 0
T.modelRoot=nil
T.spaceRoot=nil
T.combat=nil
T.attackStateProvider=nil
T.sourcePart=nil
T.sourceName="BladeTrail"
T.sourceSearchRoot=nil
T.families={Normal=true,Alt=true}
T.transformedProvider=nil
T.slots={}
T.freeSlots={}
T.liveQueue={}
T.liveHead=1
T.activeCount=0
T.generationSerial=0
T.lastSample=nil
T.lastSourceKey=nil
T.activeRouteKey=nil
T.lastPhase=nil
T.lastFamily=nil
T.lastStep=nil
T.strokes={}
T.freeStrokes={}
T.currentStroke=nil
T.strokeSerial=0

T.sources={
 Blade={
  key="Blade",
  route="BladeTrail",
  ready=false,
  templateRoot=nil,
  parent=nil,
  helperRoot=nil,
  geometry=nil,
  pivot=nil,
  baseLocal=nil,
  tipLocal=nil,
  vertexLayout=nil,
  bladeAxis=nil,
  motionAxis=nil,
 },
}


-- COMPACT IMPLEMENTATION -------------------------------------------------
local function safe(fn,...)local ok,a,b,c,d=pcall(fn,...)if ok then return a,b,c,d end return nil end local function clamp(v,lo,hi)return math.max(lo,math.min(hi,v))end local function lerpVec(a,b,t)return a+(b-a)*t end function T.findTexture
(name)if not name or name==""then return nil end local tex=safe(function()return textures:get(name)end)if not tex then tex=safe(function()return textures[name]end)end if not tex then tex=safe(function()return textures:get(name..".png")end)end
return tex end function T.resolveTrailTextures()if not T.trailTexture then T.trailTexture=T.findTexture(T.trailTextureName)end if not T.trailTextureAlt then T.trailTextureAlt=T.findTexture(T.trailTextureAltName)end return T.trailTexture,T.trailTextureAlt
end function T.selectedTrailTexture()if not T.useTextureOverride then return nil,false end local normal,alt=T.resolveTrailTextures()local transformed=false if type(T.transformedProvider)=="function"then transformed=safe(T.transformedProvider)==true end if transformed and alt then return alt,true end return normal,false end function T.applyTrailTexture(part)if not part or not T.useTextureOverride then return nil,false end local tex,alt=T.selectedTrailTexture()if tex then part:setPrimaryTexture("CUSTOM",tex)end return tex,alt end function T.syncTrailTextures(force)if not T.useTextureOverride then return end local tex,alt=T.selectedTrailTexture()local key=tex or false if not force and T.appliedTrailTexture==key and T.appliedTrailTextureAlt==alt then return end T.appliedTrailTexture=key T.appliedTrailTextureAlt=alt if not tex then return end for i=1,#T.slots do local visual=T.slots[i].visuals.Blade if visual then visual.part:setPrimaryTexture("CUSTOM",tex)end end end local function renderTime
(delta)return(T.tickSerial or 0)+clamp(tonumber(delta)or 0,0,1)end local function interpolateSample(a,b,t)return{base=lerpVec(a.base,b.base,t),tip=lerpVec(a.tip,b.tip,t),time=(a.time or 0)+((b.time or 0)-(a.time or 0))*t,}end local function
previousRenderPressure()if RenderBudget and type(RenderBudget.level)=="function"then local level=safe(function()return RenderBudget.level()end)return tonumber(level)or 0 end local ratio=0 local max=safe(function()return avatar:getMaxRenderCount()end)max=tonumber(max)or 0 if max>0 then local used=safe(function()return avatar:getCurrentInstructions()end)ratio=(tonumber(used)or 0)/max end if ratio>=.85 then return 3 elseif ratio>=.70 then return 2 elseif ratio>=.55 then return 1 end return 0 end local function currentRenderRatio()local max=safe(function()return avatar:getMaxRenderCount()end)max=tonumber(max)or 0 if max<=0 then return 0 end local used=safe(function()return avatar:getCurrentInstructions()end)used=tonumber(used)or 0 return used/max end local function captureRoom()local fraction=clamp(tonumber(T.captureStopFraction)or.90,.05,.98)if PerformanceBudget and type(PerformanceBudget.renderAllowed)=="function"then local allowed=safe(function()return PerformanceBudget.renderAllowed(fraction)end)if allowed~=nil then return allowed~=false end end return currentRenderRatio()<fraction end local function tickRoom(fraction)fraction=tonumber(fraction)or.78 if PerformanceBudget and type(PerformanceBudget.tickAllowed)=="function"then local allowed=safe(function()return PerformanceBudget.tickAllowed(fraction)end)if allowed~=nil then return allowed~=false end end local max=safe(function()return avatar:getMaxTickCount()end)max=tonumber(max)or 0 if max<=0 then return true end local used=safe(function()return avatar:getCurrentInstructions()end)if used==nil then return true end return(tonumber(used)or 0)<max*fraction end local function targetCopyCount()return math.max(2,math.floor(tonumber(T.copies)or 56))end local function liveStripLimit
()return math.max(4,math.floor(tonumber(T.maxLiveStrips)or 56))end local function children(part)local list=safe(function()return part:getChildren()end)if not list then return{}end local out={}for _,child in pairs(list)do out[#out+1]=child end
return out end local function hideTree(part)if not part then return end safe(function()part:setVisible(false)part:setOpacity(0)end)local list=children(part)for i=1,#list do hideTree(list[i])end end local function hideSourceTree(part)if not part
then return end safe(function()part:setVisible(false)part:setOpacity(0)part:setPrimaryRenderType("NONE")part:setSecondaryRenderType("NONE")end)local list=children(part)for i=1,#list do hideSourceTree(list[i])end end local function buildSourceChain
(source)local chain={}local part=source and source.geometry local guard=0 while part and part~=source.parent and guard<48 do table.insert(chain,1,part)part=safe(function()return part:getParent()end)guard=guard+1 end if part~=source.parent or
#chain==0 then return false end source.chain=chain return true end local function vertexGroups(part)return safe(function()return part:getAllVertices()end)or{}end local function vertexCount(part)local count=0 for _,list in pairs(vertexGroups
(part))do count=count+#list end return count end local function findGeometry(part,depth)if not part then return nil end depth=depth or 0 if depth>16 then return nil end local list=children(part)for i=1,#list do local found=findGeometry(list
[i],depth+1)if found then return found end end if vertexCount(part)>=4 then return part end return nil end local function stripChildren(part)local list=children(part)for i=1,#list do safe(function()part:removeChild(list[i])end)end end local
function axisGet(v,axis)if axis==1 then return v.x end if axis==2 then return v.y end return v.z end local function axisSet(v,axis,value)local out=vec(v.x,v.y,v.z)if axis==1 then out.x=value elseif axis==2 then out.y=value else out.z=value end
return out end local function analyzeSource(source)if not source or not source.geometry then return false end local groups=vertexGroups(source.geometry)local low=vec(math.huge,math.huge,math.huge)local high=vec(-math.huge,-math.huge,-math.huge
)local total=0 for _,list in pairs(groups)do for i=1,#list do local p=list[i]:getPos()low.x=math.min(low.x,p.x)low.y=math.min(low.y,p.y)low.z=math.min(low.z,p.z)high.x=math.max(high.x,p.x)high.y=math.max(high.y,p.y)high.z=math.max(high.z,p.
z)total=total+1 end end if total<4 then return false end local ranges={high.x-low.x,high.y-low.y,high.z-low.z}local bladeAxis=tonumber(source.bladeAxis)if bladeAxis~=1 and bladeAxis~=2 and bladeAxis~=3 then bladeAxis=1 if ranges[2]>ranges[bladeAxis
]then bladeAxis=2 end if ranges[3]>ranges[bladeAxis]then bladeAxis=3 end end local motionAxis=tonumber(source.motionAxis)if motionAxis~=1 and motionAxis~=2 and motionAxis~=3 then local best=-1 for axis=1,3 do if axis~=bladeAxis and ranges[axis
]>best then best=ranges[axis]motionAxis=axis end end end if not motionAxis or motionAxis==bladeAxis then return false end local thicknessAxis=6-bladeAxis-motionAxis local bladeMin=axisGet(low,bladeAxis)local motionMin=axisGet(low,motionAxis
)local bladeRange=ranges[bladeAxis]local motionRange=ranges[motionAxis]if bladeRange<.00001 or motionRange<.00001 then return false end local center=(low+high)*.5 source.baseLocal=axisSet(center,bladeAxis,bladeMin)source.tipLocal=axisSet(center
,bladeAxis,axisGet(high,bladeAxis))source.pivot=source.geometry:getPivot()source.vertexLayout={}source.detectedBladeAxis=bladeAxis source.detectedMotionAxis=motionAxis source.detectedThicknessAxis=thicknessAxis source.ribbonFaceCount=0 local
sign=(tonumber(T.ribbonFaceSign)or 1)>=0 and 1 or-1 local corners={}local selectedTexture=nil for texture,list in pairs(groups)do local layout={}for i=1,#list do local p=list[i]:getPos()local normal=list[i]:getNormal()local uv=list[i]:getUV
()local along=clamp((axisGet(p,bladeAxis)-bladeMin)/bladeRange,0,1)local sweep=clamp((axisGet(p,motionAxis)-motionMin)/motionRange,0,1)local nt=axisGet(normal,thicknessAxis)local use=math.abs(nt)>.5 and(nt>=0 and 1 or-1)==sign and math.abs(
nt)>=math.abs(axisGet(normal,bladeAxis))and math.abs(nt)>=math.abs(axisGet(normal,motionAxis))layout[i]={along=along,sweep=sweep,ribbonFace=use}if use then if selectedTexture and selectedTexture~=texture then T.lastError="BladeTrail's selected side must be one UV face, not multiple textures."
return false end selectedTexture=texture local corner=1+(sweep>.5 and 1 or 0)+(along>.5 and 2 or 0)if corners[corner]or math.min(sweep,1-sweep)>.00001 or math.min(along,1-along)>.00001 then T.lastError="BladeTrail must contain a single EAST/WEST quad on the selected side."
return false end corners[corner]=vec(uv.x,uv.y)source.ribbonFaceCount=source.ribbonFaceCount+1 end end source.vertexLayout[texture]=layout end if source.ribbonFaceCount~=4 or not(corners[1]and corners[2]and corners[3]and corners[4])then T.lastError
="BladeTrail has no complete selected side; check ribbonFaceSign and the source cube."return false end if T.textureFlipSweep then corners[1],corners[2]=corners[2],corners[1]corners[3],corners[4]=corners[4],corners[3]end if T.textureFlipAlong
then corners[1],corners[3]=corners[3],corners[1]corners[2],corners[4]=corners[4],corners[2]end local origin=corners[1]local sweep=corners[2]-origin local along=corners[3]-origin local affine=(corners[4]-(origin+sweep+along)):length()<.0001 local
size=safe(function()return source.geometry:getTextureSize()end)local matrixMode=affine and size and size.x>0 and size.y>0 source.uv={corners=corners,matrixMode=not not matrixMode,texture=selectedTexture}if matrixMode then source.uv.width=size
.x source.uv.height=size.y source.uv.ou=origin.x/size.x source.uv.ov=origin.y/size.y source.uv.su=sweep.x/size.x source.uv.sv=sweep.y/size.y source.uv.au=along.x/size.x source.uv.av=along.y/size.y end T.lastError=nil return true end local function partName(part)return tostring(safe(function()return part:getName()end)or"")end local function findNamed(part,name,depth)if not part then return nil end depth=depth or 0 if depth>48 then return nil end if partName(part)==name then return part end local list=children(part)for i=1,#list do local found=findNamed(list[i],name,depth+1)if found then return found end end return nil end local function resolveBladeTemplate()if T.sourcePart then return T.sourcePart end local root=T.sourceSearchRoot or T.modelRoot or models.idalia or models.model if not root then return nil end return findNamed(root,tostring(T.sourceName or"BladeTrail"),0)end local function prepareBladeSource()local source=T.sources.Blade if source.ready then return true end local template=resolveBladeTemplate()if not template then T.lastError="BladeTrail source part was not found."return false end local parent=safe(function()return template:getParent()end)if not parent then T.lastError="BladeTrail source has no animated parent."return false end local geometry=findGeometry(template)if not geometry then T.lastError="BladeTrail source has no usable geometry."return false end source.templateRoot=template source.parent=parent source.helperRoot=nil source.geometry=geometry source.bladeAxis=T.bladeAxis or source.bladeAxis source.motionAxis=T.motionAxis or source.motionAxis hideSourceTree(template)if not buildSourceChain(source)then T.lastError="BladeTrail source hierarchy could not be reconstructed."return false end source.ready=analyzeSource(source)return source.ready end local function maintainSources()local blade=T.sources.Blade if blade and blade.ready and blade.templateRoot then safe(function()blade.templateRoot:setVisible(false)blade.templateRoot:setOpacity(0)blade.templateRoot
:setPrimaryRenderType("NONE")blade.templateRoot:setSecondaryRenderType("NONE")end)end end local function styleGhost(part)part:setVisible(false)part:setOpacity(1)part:setPrimaryColor(1,1,1)local renderType=T.trailRenderType part:setPrimaryRenderType
(renderType)T.appliedTrailRenderType=renderType part:setSecondaryRenderType("NONE")if T.emissive~=false then part:setLight(15,15)safe(function()part:shading(false)end)end part:setUVMatrix(matrices.mat3())end local function addReverseFace(source
,groups,refs)local renderType=T.appliedTrailRenderType if T.emissiveTwoSided==false or(renderType~="EMISSIVE"and renderType~="EYES")then return end local layout=source.vertexLayout[source.uv.texture]local vertices=groups[source.uv.texture]if
not layout or not vertices or#refs~=4 then return end for first=1,math.min(#layout,#vertices)-3,4 do if not layout[first].ribbonFace and not layout[first+1].ribbonFace and not layout[first+2].ribbonFace and not layout[first+3].ribbonFace then
for j=1,4 do local ref=refs[j==1 and 1 or 6-j]ref.backVertex=vertices[first+j-1]ref.backVertex:setNormal(ref.vertex:getNormal()*-1)ref.backVertex:setUV(ref.vertex:getUV())end return end end T.renderTypeWarning="Native emissive: BladeTrail needs a spare quad in the selected texture group for the reverse side."
end local function setTrailFade(visual,opacity)visual.part:setOpacity(opacity)local renderType=T.appliedTrailRenderType if T.emissiveFadeRGB and(renderType=="EMISSIVE"or renderType=="EYES")then visual.part:setPrimaryColor(opacity,opacity,opacity
)end end local function makeVisual(source,name)if not source or not source.ready or not source.geometry then return nil end local visual=source.geometry:copy(name)stripChildren(visual)visual:setMatrix(matrices.mat4())styleGhost(visual)T.applyTrailTexture
(visual)local groups=vertexGroups(visual)local refs={}local c=source.uv.corners for texture,layout in pairs(source.vertexLayout)do local verts=groups[texture]if verts then for i=1,math.min(#layout,#verts)do local item=layout[i]if item.ribbonFace
then local a=item.along local u0=c[1].x+(c[3].x-c[1].x)*a local v0=c[1].y+(c[3].y-c[1].y)*a local u1=c[2].x+(c[4].x-c[2].x)*a local v1=c[2].y+(c[4].y-c[2].y)*a refs[#refs+1]={vertex=verts[i],along=a,sweep=item.sweep,u0=u0,v0=v0,du=u1-u0,dv=
v1-v0}verts[i]:setUV(u0+(u1-u0)*item.sweep,v0+(v1-v0)*item.sweep)else verts[i]:setPos(0,0,0)end end end end addReverseFace(source,groups,refs)return{part=visual,refs=refs,uv=source.uv}end local function releaseStroke(stroke)if not stroke or
not stroke.inUse or stroke.count>0 or stroke==T.currentStroke then return end stroke.inUse=false stroke.dirty=false stroke.root:setVisible(false)T.freeStrokes[#T.freeStrokes+1]=stroke end local function endStroke()local stroke=T.currentStroke
T.currentStroke=nil if stroke then releaseStroke(stroke)end T.lastSample=nil end local function beginStroke(source)endStroke()local stroke=table.remove(T.freeStrokes)if not stroke then local root=models:newPart("IdaliaTrailUVStroke"..tostring
(#T.strokes+1))root:moveTo(T.spaceRoot)root:setParentType("NONE")root:setPivot(0,0,0)root:setMatrix(matrices.mat4())stroke={root=root}T.strokes[#T.strokes+1]=stroke end T.strokeSerial=T.strokeSerial+1 stroke.id=T.strokeSerial stroke.inUse=true
stroke.count=0 stroke.head=nil stroke.tail=nil stroke.distance=0 stroke.uv=source.uv stroke.dirty=false stroke.lastStart=nil stroke.lastEnd=nil stroke.root:setUVMatrix(matrices.mat3())stroke.root:setVisible(true)T.currentStroke=stroke return
stroke end local function detachFromStroke(slot)local stroke=slot.stroke if not stroke then return end local prev,nextSlot=slot.strokePrev,slot.strokeNext if prev then prev.strokeNext=nextSlot else stroke.head=nextSlot end if nextSlot then nextSlot
.strokePrev=prev else stroke.tail=prev end stroke.count=stroke.count-1 stroke.dirty=true slot.stroke=nil slot.strokePrev=nil slot.strokeNext=nil releaseStroke(stroke)end local function refreshStrokeUV(stroke)if not stroke or not stroke.inUse
or not stroke.dirty then return end stroke.dirty=false if not stroke.head or not stroke.tail then return end if T.stretchTexture==false then return end local first=stroke.head.distanceStart local last=stroke.tail.distanceEnd if first==stroke
.lastStart and last==stroke.lastEnd then return end stroke.lastStart=first stroke.lastEnd=last local length=math.max(.000001,last-first)local uv=stroke.uv if uv.matrixMode then local su,sv=uv.su/length,uv.sv/length stroke.root:setUVMatrix(matrices
.mat3(vec(su,sv,0),vec(uv.au,uv.av,0),vec(uv.ou-su*first,uv.ov-sv*first,1)))else local slot=stroke.head while slot do local start=(slot.distanceStart-first)/length local span=(slot.distanceEnd-slot.distanceStart)/length local refs=slot.visuals
.Blade.refs for i=1,#refs do local ref=refs[i]local p=clamp(start+span*ref.sweep,0,1)local u,v=ref.u0+ref.du*p,ref.v0+ref.dv*p ref.vertex:setUV(u,v)if ref.backVertex then ref.backVertex:setUV(u,v)end end slot=slot.strokeNext end end end local
function refreshDirtyStrokes()for i=1,#T.strokes do refreshStrokeUV(T.strokes[i])end end local function makeSlot(index)local root=models:newPart("IdaliaUnifiedMembrane"..tostring(index))root:setPivot(0,0,0)root:moveTo(T.spaceRoot or T.modelRoot
)root:setParentType("MODEL")root:setMatrix(matrices.mat4())root:setVisible(false)local visuals={}local bladeVisual=makeVisual(T.sources.Blade,"IdaliaBladeMembraneVisual"..tostring(index))if bladeVisual then root:addChild(bladeVisual.part)visuals
.Blade=bladeVisual end return{root=root,visuals=visuals,poolIndex=index,inFreePool=false,active=false,renderVisible=false,sourceKey=nil,startLine=nil,endLine=nil,bornTime=0,generation=0,lastOpacity=nil,stroke=nil,strokePrev=nil,strokeNext=nil
,distanceStart=0,distanceEnd=0,}end local function releaseSlot(slot)if not slot or slot.inFreePool then return end slot.inFreePool=true T.freeSlots[#T.freeSlots+1]=slot.poolIndex end local function hideSlot(slot)if not slot then return end if
slot.active then T.activeCount=math.max(0,(T.activeCount or 0)-1)end slot.active=false slot.renderVisible=false slot.sourceKey=nil slot.startLine=nil slot.endLine=nil slot.lastOpacity=nil detachFromStroke(slot)slot.distanceStart=0 slot.distanceEnd
=0 slot.root:setVisible(false)for _,visual in pairs(slot.visuals or{})do visual.part:setVisible(false)end releaseSlot(slot)end local function cullOldest(amount)amount=math.max(0,math.floor(tonumber(amount)or 0))if amount<=0 then return 0 end
local removed=0 local q=T.liveQueue local head=math.max(1,math.floor(tonumber(T.liveHead)or 1))while head<=#q and removed<amount do local entry=q[head]head=head+1 local slot=entry and entry.slot if slot and slot.active and slot.generation==
entry.generation then hideSlot(slot)removed=removed+1 end end T.liveHead=head return removed end local function compactLiveQueue()local q=T.liveQueue local head=math.max(1,math.floor(tonumber(T.liveHead)or 1))if#q<512 and(head<256 or head<=
#q*.5)then return end local fresh={}for i=head,#q do local entry=q[i]local slot=entry and entry.slot if slot and slot.active and slot.generation==entry.generation then fresh[#fresh+1]=entry end end T.liveQueue=fresh T.liveHead=1 end local function
syncRoute(sourceKey)if T.activeRouteKey==sourceKey then return end T.activeRouteKey=sourceKey end local function expireOld(now)local life=math.max(.01,tonumber(T.lifeTicks)or 12)local q=T.liveQueue local head=math.max(1,math.floor(tonumber(
T.liveHead)or 1))while head<=#q do local entry=q[head]local slot=entry and entry.slot if not slot or not slot.active or slot.generation~=entry.generation then head=head+1 else local age=math.max(0,now-(slot.bornTime or now))if age>=life then
hideSlot(slot)head=head+1 else break end end end T.liveHead=head end local function enforceLiveLimit(extraNeeded)extraNeeded=math.max(0,math.floor(tonumber(extraNeeded)or 0))local limit=liveStripLimit()local over=(T.activeCount or 0)+extraNeeded
-limit if over>0 then cullOldest(over)end local missing=extraNeeded-#T.freeSlots if missing>0 then cullOldest(missing)end end local function acquireSlot()while#T.freeSlots>0 do local index=T.freeSlots[#T.freeSlots]T.freeSlots[#T.freeSlots]=
nil local slot=T.slots[index]if slot and slot.inFreePool then slot.inFreePool=false return slot end end cullOldest(1)while#T.freeSlots>0 do local index=T.freeSlots[#T.freeSlots]T.freeSlots[#T.freeSlots]=nil local slot=T.slots[index]if slot and
slot.inFreePool then slot.inFreePool=false return slot end end return nil end local function bakeStripModelSpace(slot,sourceKey)local visual=slot.visuals[sourceKey]if not visual then return false end local a,b=slot.startLine,slot.endLine local
anchor=(a.base+a.tip+b.base+b.tip)*.25 slot.root:setMatrix(matrices.translate4(anchor.x,anchor.y,anchor.z))local refs=visual.refs local uv=visual.uv local span=slot.distanceEnd-slot.distanceStart for i=1,#refs do local ref=refs[i]local oldPoint
=lerpVec(a.base,a.tip,ref.along)local newPoint=lerpVec(b.base,b.tip,ref.along)local pos=lerpVec(oldPoint,newPoint,ref.sweep)-anchor ref.vertex:setPos(pos)if ref.backVertex then ref.backVertex:setPos(pos)end local u,v if T.stretchTexture~=false
and uv.matrixMode then local distance=slot.distanceStart+span*ref.sweep u,v=distance*uv.width,ref.along*uv.height else u,v=ref.u0+ref.du*ref.sweep,ref.v0+ref.dv*ref.sweep end ref.vertex:setUV(u,v)if ref.backVertex then ref.backVertex:setUV(
u,v)end end return true end local function pushStrip(sourceKey,previous,current,bornTime)local stroke=T.currentStroke if not previous or not current or not stroke then return false end local slot=acquireSlot()if not slot then return false end
local visual=slot.visuals[sourceKey]if not visual then releaseSlot(slot)return false end local distance=math.max((current.base-previous.base):length(),(current.tip-previous.tip):length())if distance<=.000001 then releaseSlot(slot)return false
end slot.sourceKey=sourceKey slot.distanceStart=stroke.distance slot.distanceEnd=stroke.distance+distance slot.startLine={base=previous.base,tip=previous.tip}slot.endLine={base=current.base,tip=current.tip}slot.bornTime=tonumber(bornTime)or
current.time or T.tickSerial T.generationSerial=T.generationSerial+1 slot.generation=T.generationSerial slot.active=true slot.renderVisible=false slot.lastOpacity=nil T.activeCount=T.activeCount+1 slot.root:setVisible(false)visual.part:setVisible
(true)slot.root:moveTo(stroke.root)if not bakeStripModelSpace(slot,sourceKey)then hideSlot(slot)return false end slot.stroke=stroke slot.strokePrev=stroke.tail slot.strokeNext=nil if stroke.tail then stroke.tail.strokeNext=slot else stroke.
head=slot end stroke.tail=slot stroke.count=stroke.count+1 stroke.distance=slot.distanceEnd stroke.dirty=true T.liveQueue[#T.liveQueue+1]={slot=slot,generation=slot.generation}return true end local function adaptiveSubdivisionCount(movement
)local target=math.max(.001,tonumber(T.segmentLength)or.10)local maxParts=math.max(1,math.floor(tonumber(T.maxSubdivisions)or 10))local pieces=math.max(1,math.ceil((movement or 0)/target))pieces=math.min(pieces,maxParts)pieces=math.min(pieces
,math.max(1,math.floor(tonumber(T.maxBakePerCapture)or 5)))local pressure=previousRenderPressure()if pressure>=3 then pieces=math.min(pieces,1)elseif pressure>=2 then pieces=math.min(pieces,2)elseif pressure>=1 then pieces=math.min(pieces,4
)end return math.max(1,pieces)end local function pushSubdivided(sourceKey,previous,current,movement)if not previous or not current then return previous,false end local pieces=adaptiveSubdivisionCount(movement)local from=previous local baked
=false for i=1,pieces do if not captureRoom()then return from,baked end enforceLiveLimit(1)local to=interpolateSample(previous,current,i/pieces)if not pushStrip(sourceKey,from,to,to.time)then return from,baked end from=to baked=true end return
current,baked end local function sampleSource(source)if not source or not source.ready or not source.geometry or not source.pivot or not source.parent or not source.chain then return nil end local matrix=safe(function()local parentWorld=source
.parent:partToWorldMatrix()local m=matrices.mat4()m:rightMultiply(parentWorld)for i=1,#source.chain do m:rightMultiply(source.chain[i]:getPositionMatrix())end return m end)if not matrix then return nil end return{base=matrix:apply(source.baseLocal
-source.pivot),tip=matrix:apply(source.tipLocal-source.pivot),}end local function movementBetween(a,b)if not a or not b then return math.huge end return math.max((b.base-a.base):length(),(b.tip-a.tip):length())end local function attackState()if type(T.attackStateProvider)=="function"then local phase,family,step=safe(T.attackStateProvider)return phase,family,math.max(1,math.floor(tonumber(step)or 1))end if T.combat then local phase=safe(T.combat.getPhase)local family=safe(T.combat.getFamily)local step=safe(T.combat.getStep)return phase,family,math.max(1,math.floor(tonumber(step)or 1))end return nil,nil,1 end local function routeSource()local phase,family,step=attackState()local allowed=phase=="A"and T.families and T.families[family]==true local source=allowed and T.sources.Blade or nil if source and not source.ready then source=nil end local name=phase and family and(tostring(family)..tostring(phase).." "..tostring(step))or nil return source,name,phase,family,step,allowed and"BladeTrail"or"None" end local function clear()endStroke
()T.lastSourceKey=nil T.activeRouteKey=nil T.lastPhase=nil T.lastFamily=nil T.lastStep=nil for i=1,#T.slots do hideSlot(T.slots[i])end T.liveQueue={}T.liveHead=1 T.activeCount=0 if T.spaceRoot then T.spaceRoot:setVisible(false)end end local
function tryInit()if T.ready then return true end T.modelRoot=T.modelRoot or models.idalia or models.model if not T.modelRoot then return false end local bladeReady=prepareBladeSource()if not bladeReady then return false end if not T.spaceRoot then T.spaceRoot=models:newPart("IdaliaUnifiedTrailSpace")T.spaceRoot:setPivot(0,0,0)T.spaceRoot:moveTo(T.modelRoot)T.spaceRoot:setParentType("MODEL")T.spaceRoot:setMatrix(matrices.mat4())T
.spaceRoot:setVisible(false)end T.slots={}T.freeSlots={}T.liveQueue={}T.liveHead=1 T.activeCount=0 T.generationSerial=0 local target=targetCopyCount()local initial=math.min(target,math.max(2,math.floor(tonumber(T.initialCopies)or 16)))for i
=1,initial do if i>1 and(i>math.max(1,tonumber(T.buildPerTick)or 4)or not tickRoom(.70))then break end local slot=makeSlot(i)T.slots[i]=slot releaseSlot(slot)end maintainSources()T.ready=true return true end local function tick()T.tickSerial
=(T.tickSerial or 0)+1 if not player:isLoaded()then if T.ready then clear()end return end if not T.ready then tryInit()return end maintainSources()expireOld(T.tickSerial or 0)enforceLiveLimit(0)compactLiveQueue()local target=targetCopyCount
()local perTick=math.max(1,math.floor(tonumber(T.buildPerTick)or 4))local built=0 while#T.slots<target and built<perTick and tickRoom(T.tickBudgetFraction)do local index=#T.slots+1 local slot=makeSlot(index)T.slots[index]=slot releaseSlot(slot
)built=built+1 end end local function render(delta,context)if not T.ready then return end if T.enabled==false then clear()return end if context~="RENDER"then if T.spaceRoot then T.spaceRoot:setVisible(false)end return end maintainSources()T
.syncTrailTextures(false)local now=renderTime(delta)expireOld(now)enforceLiveLimit(0)refreshDirtyStrokes()local rootWorld=safe(function()return T.modelRoot:partToWorldMatrix()end)if not rootWorld then return end local rootInverse=safe(function
()return rootWorld:inverted()end)if not rootInverse then return end T.spaceRoot:setMatrix(rootInverse)T.spaceRoot:setVisible(true)local life=math.max(.01,tonumber(T.lifeTicks)or 12)local q=T.liveQueue local head=math.max(1,math.floor(tonumber
(T.liveHead)or 1))for i=#q,head,-1 do local entry=q[i]local slot=entry and entry.slot if slot and slot.active and slot.generation==entry.generation then local age=math.max(0,now-(slot.bornTime or now))if age>=life then hideSlot(slot)else local
remain=1-clamp(age/life,0,1)local fade=remain*remain*(3-2*remain)local opacity=(T.opacity or.88)*fade local key=slot.sourceKey local visual=key and slot.visuals and slot.visuals[key]or nil if opacity>.002 and visual then if slot.lastOpacity
==nil or math.abs(opacity-slot.lastOpacity)>=.01 then setTrailFade(visual,opacity)slot.lastOpacity=opacity end if slot.renderVisible~=true then slot.root:setVisible(true)slot.renderVisible=true end elseif slot.renderVisible~=false then slot
.root:setVisible(false)slot.renderVisible=false end end end end compactLiveQueue()end local function postRender(delta,context)if context~="RENDER"or not T.ready or T.enabled==false then return end maintainSources()local source,name,phase,family
,step=routeSource()syncRoute(source and source.key or nil)if not source then endStroke()T.lastSourceKey=nil T.lastPhase=phase T.lastFamily=family T.lastStep=step return end local current=sampleSource(source)if not current then return end current.time=renderTime(delta)local changed=T.lastSourceKey~=source.key or T.lastFamily
~=family or T.lastStep~=step or(T.lastPhase=="E"and phase=="A")if changed or not T.currentStroke then beginStroke(source)end if not T.lastSample then T.lastSample=current else local movement=movementBetween(T.lastSample,current)local minimum
=math.max(.000001,tonumber(T.minMovement)or.010)local reject=math.max(minimum,tonumber(T.teleportRejectDistance)or 4.0)if movement>reject then beginStroke(source)T.lastSample=current elseif movement>=minimum then local reached,baked=pushSubdivided
(source.key,T.lastSample,current,movement)if baked and reached then T.lastSample=reached end refreshStrokeUV(T.currentStroke)end end T.lastSourceKey=source.key T.lastPhase=phase T.lastFamily=family T.lastStep=step end local CONFIG_KEYS={enabled=true,copies=true,lifeTicks=true,opacity=true,minMovement=true,segmentLength=true,maxSubdivisions=true,maxBakePerCapture=true,teleportRejectDistance=true,tickBudgetFraction=true,initialCopies=true,buildPerTick=true,maxLiveStrips=true,captureStopFraction=true,emissive=true,trailRenderType=true,emissiveTwoSided=true,emissiveFadeRGB=true,stretchTexture=true,textureFlipSweep=true,textureFlipAlong=true,ribbonFaceSign=true,useTextureOverride=true,trailTextureName=true,trailTextureAltName=true,transformedProvider=true,combat=true,attackStateProvider=true,modelRoot=true,sourcePart=true,sourceName=true,sourceSearchRoot=true,families=true,bladeAxis=true,motionAxis=true}function T.configure(options)options=options or{}for key,value in pairs(options)do if CONFIG_KEYS[key]then T[key]=value end end if T.sources and T.sources.Blade then T.sources.Blade.bladeAxis=T.bladeAxis T.sources.Blade.motionAxis=T.motionAxis end return T end function T.start()if T
.started then return T end T.started=true events.TICK:register(tick,"idalia_unified_membrane_tick")events.RENDER:register(render,"idalia_unified_membrane_render")events.POST_RENDER:register(postRender,"idalia_unified_membrane_capture")return T
end function T.clear()clear()end function T.sourcePlacement()return{Blade=T.sourcePart or T.sourceName or"BladeTrail",}end return T
