-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local outParts = {}
outParts['etk800_body'] = {'chassis'}
outParts['etk800_fender_L'] = {'fenders', 'left'}
outParts['etk800_fender_R'] = {'fenders', 'right'}
outParts['etk800_door_FL'] = {'doors', 'front', 'left'}
outParts['etk800_door_FR'] = {'doors', 'front', 'right'}
outParts['etk800_door_RL'] = {'doors', 'back', 'left'}
outParts['etk800_door_RR'] = {'doors', 'back', 'right'}
outParts['etk800_mirror_L'] = {'mirrors', 'left'}
outParts['etk800_mirror_R'] = {'mirrors', 'right'}
outParts['etk800_bumper_F'] = {'bumpers', 'front'}
outParts['etk800_bumper_R'] = {'bumpers', 'back'}
outParts['etk800_bumperbar_F'] = {'bumperbar'}
outParts['etk800_radiator'] = {'radiator'}
outParts['etk_engine'] = {'engine'}
outParts['etk_intake'] = {'intake'}
outParts['etk_exhaust'] = {'exhaust'}
outParts['etk_transmission'] = {'transmission'}
outParts['wheel_FL_5'] = {'wheels', 'front', 'left'}
outParts['wheel_FR_5'] = {'wheels', 'front', 'right'}
outParts['wheel_RL_5'] = {'wheels', 'back', 'left'}
outParts['wheel_RR_5'] = {'wheels', 'back', 'right'}
outParts['etk800_hood'] = {'hood'}
outParts['etk800_tailgate'] = {'tailgate'}
outParts['etk800_differential_R'] = {'differential'}
outParts['etk800_seat_FL'] = {'seats', 'front', 'left'}
outParts['etk800_seat_FR'] = {'seats', 'front', 'right'}
outParts['etk800_seats_R'] = {'seats', 'back'}
outParts['etk800_glass_wagon'] = {'windows', 'windshield'}
outParts['etk800_tailgateglass'] = {'windows', 'tail'}
outParts['etk800_doorglass_FL'] = {'windows', 'front', 'left'}
outParts['etk800_doorglass_FR'] = {'windows', 'front', 'right'}
outParts['etk800_doorglass_RL'] = {'windows', 'back', 'left'}
outParts['etk800_doorglass_RR'] = {'windows', 'back', 'right'}
outParts['etk800_sideglass_L'] = {'windows', 'trunk', 'left'}
outParts['etk800_sideglass_R'] = {'windows', 'trunk', 'right'}
outParts['etk800_roof_wagon'] = {'sunroof'}
outParts['etk800_steer'] = {'steeringwheel'}
outParts['etk800_driveshaft_R'] = {'driveshaft'}
outParts['etk800_headlight_L'] = {'lights', 'front', 'left'}
outParts['etk800_headlight_R'] = {'lights', 'front', 'right'}
outParts['etk800_taillight_L'] = {'lights', 'back', 'left'}
outParts['etk800_taillight_R'] = {'lights', 'back', 'right'}
outParts['etk800_licenseplate_F'] = {'licenseplates', 'front'}
outParts['etk800_licenseplate_R'] = {'licenseplates', 'back'}
outParts['etk800_fueltank'] = {'fueltank'}
outParts['etk800_grille'] = {'grille'}
outParts['etk800_pedals'] = {'pedals'}
outParts['etk800_shifter_M'] = {'shifter'}
outParts['etk800_intmirror'] = {'mirrors', 'rearview'}
outParts['etk800_dash'] = {'dashboard'}
outParts['etk800_wipers_F'] = {'wiper', 'front'}
outParts['etk800_wiper_R'] = {'wiper', 'back'}
outParts['etk800_foglight_l'] = {'foglights', 'left'}
outParts['etk800_foglight_r'] = {'foglights', 'right'}

local camRadius = 7
local camHeight = 1.25

local spawnPending = nil
local skybox = nil
local setting = nil
local currentMesh = nil
local camera = nil
local cameraArgs = {pos = vec3(0, 0, 0), size = ({100, 100}), isSnappingDesired = false,
                    nearFarPlanes = {0.1, 1000}, isStatic = true, requestedUpdateTime = -1.0,
                    renderAnnotations = true, renderColours = true, renderDepth = false,
                    renderInstance = false, isStreaming = false}
local cameraRequest
local cameraRequestWaitFrames = 0
local sensors = extensions.tech_sensors
local renderQueue = {}
local renderIdx = 1

local exporter = extensions.util_export

local state = nop

local function fuzzyTableLookup(d, n)
  for k, v in pairs(d) do
    if string.find(string.lower(k), string.lower(n)) ~= nil then
      return v
    end
  end

  return nil
end

local function getRelevantParts(parts)
  local ret = {}

  for k, v in pairs(outParts) do
    local data = fuzzyTableLookup(parts, k)
    if data ~= nil then
      ret[k] = data
    end
  end

  for k, v in pairs(outParts) do
    if ret[k] == nil then
      ret[k] = {}
    end
  end

  return ret
end

local function getPartColor(part)
  local c = tech_partAnnotations.getPartAnnotation(part)
  if c ~= nil then
    return {c.r, c.g, c.b}
  else
    return {-1, -1, -1}
  end
end

local function restructureParts(parts)
  local ret = {}

  for part, v in pairs(parts) do
    local partEntry = {}
    partEntry.segmentation = getPartColor(part)
    partEntry.partName = part

    local current = ret
    local path = outParts[part]
    for i, p in ipairs(path) do
      if i == table.getn(path) then
        break
      end

      if current[p] == nil then
        current[p] = {}
      end

      current = current[p]
    end

    current[path[table.getn(path)]] = partEntry
  end

  return ret
end

local function requestMesh(veh)
  exporter.embedBuffers = true
  exporter.gltfBinaryFormat = false
  exporter.export(function(gltfRoot)
      currentMesh = jsonEncode(gltfRoot)
  end)
end

local function renderPerspective(request, origin, angle, idx)
  if cameraRequestWaitFrames > 20 then
    log('E', 'crashOutput', 'Camera request time out, sending a new request.')
    cameraRequest = nil
  end

  if not cameraRequest then
    log('I', 'crashOutput', 'Rendering perspective ' .. idx .. '...')
    cameraRequestWaitFrames = 0
    local camPos = vec3(camRadius * math.cos(angle), camRadius * math.sin(angle), camHeight)
    local camDir = vec3(-camPos.x, -camPos.y, -camPos.z)
    local camRot = quatFromDir(camDir, vec3(0, 0, 1))
    camPos = camPos + origin
    camPos = vec3(camPos.x, camPos.y, camPos.z)
    camRot = QuatF(camRot.x, camRot.y, camRot.z, camRot.w)

    sensors.setCameraSensorPosition(camera, camPos)
    sensors.setCameraSensorDirection(camera, camDir)

    cameraRequest = sensors.sendCameraRequest(camera)
  end

  if cameraRequest and not sensors.isRequestComplete(cameraRequest) then
    cameraRequestWaitFrames = cameraRequestWaitFrames + 1
    return false
  end

  local cameraData = sensors.collectCameraRequest(cameraRequest)
  cameraRequest = nil
  local colorName = string.format('image_%02d.png', idx)
  local annotName = string.format('annotation_%02d.png', idx)
  log('I', 'crashOutput', 'Perspective ' .. idx .. ' rendered.')
  local result = {}
  result.type = 'ImpactGenOutput'
  result[colorName] = cameraData['colour']
  result[annotName] = cameraData['annotation']

  request:sendResponse(result)
  return true
end

local function renderPerspectives(callback)
  if renderQueue[renderIdx] == nil then
    state = callback
    table.clear(renderQueue)
    return
  end

  if renderPerspective(unpack(renderQueue[renderIdx])) then
    renderIdx = renderIdx + 1
  end
end

M.onInit = function()
  log('crashOutput', 'INFO', 'Setting up crash output extension.')
  if not ResearchVerifier.isTechLicenseVerified() then
    log('crashOutput', 'E', 'BeamNG.tech license is needed for this extension to work properly.')
    return false
  end
  Engine.Annotation.enable(true)
  extensions.load('tech/partAnnotations')
  registerCoreModule('tech/partAnnotations')
  extensions.load('util/export')
end

local function waitFrames(callback, frames)
  if frames > 0 then
    state = function()
      waitFrames(callback, frames - 1)
    end
  else
    state = callback
  end
end

local function waitForSpawn(next)
  if spawnPending == nil then
    state = next
  end
end

local function waitForMesh(callback)
  log('crashOutput', 'I', 'Waiting for mesh data...')
  if currentMesh ~= nil then
    log('crashOutput', 'I', 'Got mesh data!')
    local mesh = currentMesh
    currentMesh = nil
    state = function()
      callback(mesh)
    end
  end
end

local function waitForDamage(veh, other, next)
  local dmg = map.objects[veh:getId()].damage
  if dmg > 10 then
    veh:queueLuaCommand('input.event("throttle", 0, 1)')
    veh:queueLuaCommand('input.event("brake", 0, 1)')
    veh:queueLuaCommand('input.event("parkingbrake", 1, 1)')

    if other ~= nil then
      other:queueLuaCommand('input.event("throttle", 0, 1)')
      other:queueLuaCommand('input.event("parkingbrake", 1, 1)')
    end

    state = function()
      waitFrames(next, 60)
    end
  end
end

local function getLevelName()
  local mission = getMissionFilename()
  if string.find(mission, 'smallgrid') then
    return 'smallgrid'
  end
  return 'west_coast_usa'
end

M.onUpdate = function()
  state()
end

M.handleImpactGenSetImageProperties = function(request)
  local width = request['imageWidth']
  local height = request['imageHeight']
  local f = request['fov']

  camHeight = request['height']
  camRadius = request['radius']

  cameraArgs.size = {width, height}
  cameraArgs.fovY = f
  cameraArgs.isVisualised = false

  request:sendACK('ImpactGenImagePropertiesSet')
end

M.handleImpactGenGenerateOutput = function(request)
  request:markHandled() -- we return responses later than this frame

  camera = sensors.createCamera(0, cameraArgs)
  local veh = be:getPlayerVehicle(0)

  local pos = veh:getSpawnWorldOOBB():getCenter()
  local dir = veh:getDirectionVector()

  requestMesh(veh)

  local baseAngle = math.atan2(dir.y, dir.x)
  local count = 0
  for angle = 0,359,15 do
    table.insert(renderQueue, {request, pos, baseAngle + math.rad(angle), count})
    count = count + 1
  end
  renderIdx = 1

  local next = function(mesh)
    sensors.removeSensor(camera)
    camera = nil

    state = nop
    local parts = extensions.core_vehicle_manager.getPlayerVehicleData().chosenParts
    parts = getRelevantParts(parts)
    parts = jsonEncodePretty(restructureParts(parts))

    setting.level = getLevelName()
    local scenario = jsonEncodePretty(setting)
    request:sendResponse({
      type = 'ImpactGenOutputEnd',
      mesh = mesh,
      scenario = scenario,
      parts = parts
    })
  end

  state = function()
    renderPerspectives(function() waitForMesh(next) end)
  end
end

local function continueLinear(request, angle, aPos, bPos, bRot, throttle, config, ego, other)
  local rot = quatFromEuler(0, 0, math.rad(angle))
  ego:setPositionRotation(aPos[1], aPos[2], aPos[3], rot.x, rot.y, rot.z, rot.w)
  rot = quatFromEuler(math.rad(bRot[1]), math.rad(bRot[2]), math.rad(bRot[3]))
  other:setPositionRotation(bPos[1], bPos[2], bPos[3], rot.x, rot.y, rot.z, rot.w)

  other:queueLuaCommand('input.event("throttle", ' .. tostring(throttle) .. ', 1)')

  local next = function()
    request:sendACK('ImpactGenLinearRan')
    state = nop
  end

  state = function()
    waitForDamage(ego, other, next)
  end
end

M.handleImpactGenRunLinear = function(request)
  request:markHandled()

  local angle = request['angle']
  local aPos = request['aPosition']
  local bPos = request['bPosition']
  local bRot = request['bRotation']
  local throttle = request['throttle']
  local config = request['config']
  local ego = request['ego']
  local other = request['other']

  setting = {}
  setting.type = 'linear'
  setting.angle = angle
  setting.aPos = aPos
  setting.bPos = bPos
  setting.bRot = bRot
  setting.throttle = throttle
  setting.config = config
  setting.ego = ego
  setting.other = other

  spawnPending = ego
  ego = scenetree.findObject(ego)
  other = scenetree.findObject(other)

  be:enterVehicle(0, ego)
  core_vehicle_partmgmt.setConfig(config)

  local next = function()
    continueLinear(request, angle, aPos, bPos, bRot, throttle, config, ego, other)
  end

  state = function()
    waitForSpawn(next)
  end
end

local function continueTBone(request, angle, aPos, bPos, bRot, throttle, config, ego, other)
  local rot = quatFromEuler(0, 0, math.rad(angle))
  ego:setPositionRotation(aPos[1], aPos[2], aPos[3], rot.x, rot.y, rot.z, rot.w)
  rot = quatFromEuler(math.rad(bRot[1]), math.rad(bRot[2]), math.rad(bRot[3]))
  other:setPositionRotation(bPos[1], bPos[2], bPos[3], rot.x, rot.y, rot.z, rot.w)

  other:queueLuaCommand('input.event("throttle", ' .. tostring(throttle) .. ', 1)')

  local next = function()
    request:sendACK('ImpactGenTBoneRan')
    state = nop
  end

  state = function()
    waitForDamage(ego, other, next)
  end
end

M.handleImpactGenRunTBone = function(request)
  request:markHandled()

  local angle = request['angle']
  local aPos = request['aPosition']
  local bPos = request['bPosition']
  local bRot = request['bRotation']
  local throttle = request['throttle']
  local config = request['config']
  local ego = request['ego']
  local other = request['other']

  setting = {}
  setting.type = 'tbone'
  setting.angle = angle
  setting.aPos = aPos
  setting.bPos = bPos
  setting.bRot = bRot
  setting.throttle = throttle
  setting.config = config
  setting.ego = ego
  setting.other = other

  spawnPending = ego
  ego = scenetree.findObject(ego)
  other = scenetree.findObject(other)
  be:enterVehicle(0, ego)
  core_vehicle_partmgmt.setConfig(config)

  local next = function()
    continueTBone(request, angle, aPos, bPos, bRot, throttle, config, ego, other)
  end

  state = function()
    waitForSpawn(next)
  end
end

local function continuePole(request, angle, pos, throttle, config, ego)
  local rot = quatFromEuler(0, 0, math.rad(angle))
  ego:setPositionRotation(pos[1], pos[2], pos[3], rot.x, rot.y, rot.z, rot.w)

  if throttle > 0 then
    ego:queueLuaCommand('input.event("throttle", ' ..  tostring(throttle) .. ', 1)')
  else
    ego:queueLuaCommand('input.event("brake", ' ..  tostring(-throttle) .. ', 1)')
  end

  local next = function()
    request:sendACK('ImpactGenPoleRan')
    state = nop
  end

  state = function()
    waitForDamage(ego, nil, next)
  end
end

local function placePole(polePos)
  local obj = createObject('TSStatic')
  obj.shapeName = 'levels/west_coast_usa/art/shapes/objects/lamp1.dae'
  local pos = vec3(polePos[1], polePos[2], polePos[3])
  obj:setPosition(pos)
  local scl = vec3(1, 1, 1)
  obj:setScale(scl)

  local name = 'impactgen_pole'
  obj.canSave = false
  obj:registerObject(name)

  be:reloadCollision()
end

M.handleImpactGenRunPole = function(request)
  request:markHandled()

  local angle = request['angle']
  local pos = request['position']
  local polePos = request['polePosition']
  local throttle = request['throttle']
  local ego = request['ego']
  local config = request['config']

  setting = {}
  setting.type = 'pole'
  setting.pos = pos
  setting.polePos = polePos
  setting.throttle = throttle
  setting.ego = ego
  setting.config = config

  spawnPending = ego
  ego = scenetree.findObject(ego)
  be:enterVehicle(0, ego)
  core_vehicle_partmgmt.setConfig(config)

  if polePos ~= nil then
    placePole(polePos)
  end

  local next = function()
    continuePole(request, angle, pos, throttle, config, ego)
  end

  state = function()
    waitForSpawn(next)
  end
end

M.handleImpactGenRunNonCrash = function(request)
  request:markHandled()

  log('crashOutput', 'I', 'Handling Non-Crash scenario.')
  local config = request['config']
  local ego = request['ego']

  setting = {}
  setting.type = 'nocrash'
  setting.ego = ego
  setting.config = config

  log('crashOutput', 'I', 'Setting vehicle config.')
  local veh = scenetree.findObject(ego)
  spawnPending = ego
  be:enterVehicle(0, veh)
  core_vehicle_partmgmt.setConfig(config)

  local next = function()
    request:sendACK('ImpactGenNonCrashRan')
    state = nop
  end

  log('crashOutput', 'I', 'Waiting for vehicle to respawn.')
  state = function()
    waitForSpawn(next)
  end
end

local function placeSkybox()
  local obj = worldEditorCppApi.createObject('SkyBox')
  log('crashOutput', 'I', 'SkyBox obj created!')
  local name = 'impactgen_skybox'
  obj.canSave = false
  obj:setName(name)
  scenetree.MissionGroup:add(obj.obj)

  be:reloadCollision()

  skybox = obj
end

local function continuePostSettings(request, skyboxMat, groundMat)
  if skyboxMat ~= nil then
    log('crashOutput', 'I', 'Setting sky mat: ' .. groundMat)
    skybox:setField('material', 0, skyboxMat)
    skybox:postApply()
  end

  if groundMat ~= nil then
    log('crashOutput', 'I', 'Setting ground mat: ' .. groundMat)
    local ground = scenetree.findClassObjects('GroundPlane')[1]
    ground = scenetree.findObjectById(ground)
    ground:setField('material', 0, groundMat)
    ground:setField('squareSize', 0, 1024)
    ground:postApply()
  end

  local notifyPostSettings = function()
    be:setPhysicsRunning(false)
    request:sendACK('ImpactGenPostSet')
    state = nop
  end

  state = function()
    waitFrames(notifyPostSettings, 30)
  end
end

local function setClassProperty(clazz, field, value)
  local instances = scenetree.findClassObjects(clazz)
  if table.getn(instances) > 0 then
    local instance = instances[1]
    instance = scenetree.findObject(instance)
    instance:setField(field, 0, value)
    instance:postApply()
  else
    log('crashOutput', 'I', 'Could not find class instance: ' .. clazz)
  end
end

local function setWeather(time, clouds, fog)
  setClassProperty('TimeOfDay', 'time', time)
  setClassProperty('CloudLayer', 'coverage', clouds)
  setClassProperty('LevelInfo', 'fogDensity', fog)
end

M.handleImpactGenPostSettings = function(request)
  request:markHandled()

  local ego = request['ego']
  local time = request['time']
  local clouds = request['clouds']
  local fog = request['fog']
  local color = request['color']
  local skyboxMat = request['skybox']
  local groundMat = request['ground']

  setting.time = time
  setting.clouds = clouds
  setting.fog = fog
  setting.color = color
  setting.skyboxMat = skyboxMat
  setting.groundMat = groundMat

  setWeather(time, clouds, fog)

  be:setPhysicsRunning(true)

  color = Point4F(color[1], color[2], color[3], color[4])
  local veh = scenetree.findObject(ego)
  veh:setColor(color)
  tech_partAnnotations.annotateParts(veh:getId())

  if skyboxMat ~= nil then
    if skybox == nil then
      placeSkybox()
    end
  end

  local continue = function()
    continuePostSettings(request, skyboxMat, groundMat)
  end

  state = function()
    waitFrames(continue, 3)
  end
end

M.onSocketMessage = function(request)
  local requestType = 'handle' .. request['type']
  local handler = M[requestType]
  if handler ~= nil then
    handler(request)
  end
end

M.onVehicleSpawned = function(vID)
  log('crashOutput', 'I', 'Got vehicle spawn: ' .. vID)
  if spawnPending ~= nil then
    local obj = scenetree.findObject(spawnPending)
    if obj ~= nil and obj:getId() == vID then
      obj:queueLuaCommand('extensions.load("tech/impactgen/damageEvaluation")')
      spawnPending = nil
    end
  end
end

M.onScenarioRestarted = function()
  skybox = nil
end

M.partOptions = {}

return M
