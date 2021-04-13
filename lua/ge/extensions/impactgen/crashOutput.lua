-- SPDX-License-Identifier: MIT

local M = {}

local nullDamageParts = {}
nullDamageParts['etk800_shifter_M'] = true
nullDamageParts['etk800_pedals'] = true
nullDamageParts['etk800_steer'] = true
nullDamageParts['etk800_intmirror'] = true
nullDamageParts['etk800_wipers_F'] = true
nullDamageParts['etk800_wiper_R'] = true
nullDamageParts['etk800_licenseplate_F'] = true
nullDamageParts['etk800_licenseplate_R'] = true
nullDamageParts['etk800_foglight_r'] = true
nullDamageParts['etk800_foglight_l'] = true

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

local rcom = require('utils/researchCommunication')
local jbeamIO = require('jbeam/io')

local camRadius = 7
local camHeight = 1.25

local referencePos = Point3F(-18, 610, 75)

local enabled = false
local moved = false
local rendered = false

local spawnPending = nil

local skybox = nil

local setting = nil

local objAnnotations = {}
local currentMesh = nil

local _log = log
local function log(level, msg)
    _log(level, 'crashOutput', msg)
end

local state = nop

local function fuzzyTableLookup(d, n)
    for k, v in pairs(d) do
        if string.find(string.lower(k), string.lower(n)) ~= nil then
            return v
        end
    end

    return nil
end

local function scanCurrentParts(options, known)
    if known == nil then
        known = {}
    end

    if options.slotType ~= nil then
        local slotType = options.slotType
        if options.active ~= nil and options.active then
            local c = deepcopy(options)
            if options.parts ~= nil then
                c.parts = nil
                known[slotType] = c
            end
        end
    end

    if options.parts ~= nil then
        scanCurrentParts(options.parts, known)
    end

    for k, v in pairs(options) do
        if type(v) == 'table' then
            for i, e in ipairs(v) do
                scanCurrentParts(e, known)
            end
        end
    end

    return known
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

local function getPartDamage(part, damage)
    if nullDamageParts[part] ~= nil then
        return -1
    end

    local partDamage = nil

    if damage.partDamage ~= nil then
        partDamage = fuzzyTableLookup(damage.partDamage, part)
    end

    if partDamage == nil and damage.deformGroupDamage ~= nil then
        partDamage = fuzzyTableLookup(damage.deformGroupDamage, part)
    end

    if partDamage == nil then
        partDamage = fuzzyTableLookup(damage, part)
    end

    if partDamage ~= nil and partDamage.damage ~= nil then
        return partDamage.damage
    end

    return nil
end

local function getPartColor(part)
    local c = util_partAnnotations.getPartAnnotation(part)
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

local function requestCurrentParts()
    local veh = extensions.core_vehicle_manager.getPlayerVehicleData()
    local parts = veh.chosenParts
    M.partOptions = parts
end

local function requestMesh(veh)
    extensions.util_export.export(function(gltfRoot)
        currentMesh = jsonEncode(gltfRoot)
    end)
end

local function renderPerspective(origin, angle, idx)
    local camPos = vec3(camRadius * math.cos(angle), camRadius * math.sin(angle), camHeight)
    local camDir = vec3(-camPos.x, -camPos.y, -camPos.z)
    local camRot = quatFromDir(camDir, vec3(0, 0, 1))
    camPos = camPos + origin

    local colorName = string.format('image_%02d.png', idx)
    local annotName = string.format('annotation_%02d.png', idx)

    camPos = Point3F(camPos.x, camPos.y, camPos.z)
    camRot = QuatF(camRot.x, camRot.y, camRot.z, camRot.w)

    zipper.queueImagePair(camPos, camRot)
end

M.onInit = function()
    log('INFO', 'Setting up crash output extension.')
    Engine.Annotation.enable(true)
    extensions.load('util/partAnnotations')
    registerCoreModule('util/partAnnotations')
    extensions.load('util/export')

    local anno = jsonReadFile('annotations.json')
    for k, v in pairs(anno) do
        objAnnotations[string.lower(k)] = v
    end
end

local function checkSavingZips()
    local done = zipper.checkFinishedSavingZips()
    if done then
        log('I', 'Finished saving zips.')
        state = nop
    end
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

local function waitForZip(next)
    if zipper.checkFinishedSavingZips() then
        state = next
    end
end

local function waitForSpawn(next)
    if spawnPending == nil then
        state = next
    end
end

local function waitForMesh(callback)
    log('I', 'Waiting for mesh data...')
    if currentMesh ~= nil then
        log('I', 'Got mesh data!')
        local mesh = currentMesh
        currentMesh = nil
        state = function()
            callback(mesh)
        end
    end
end

local function waitForDamage(veh, other, next)
    local dmg = map.objects[veh:getID()].damage
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
    else
        return 'west_coast_usa'
    end
end

local function renderVehicleStep(pos, baseAngle, angle, count)
    if angle > 359 then
        state = startSavingZips
        return
    end

    renderPerspective(pos, baseAngle + math.rad(angle), count)

    state = function()
        renderVehicleStep(pos, baseAngle, angle + 6, count + 1)
    end
end

local function renderVehicle()
    be:setPhysicsRunning(false)
    local veh = be:getPlayerVehicle(0)

    local pos = veh:getSpawnWorldOOBB():getCenter()
    local dir = veh:getDirectionVector()

    util_partAnnotations.annotateParts(veh:getID())

    local baseAngle = math.atan2(dir.y, dir.x)

    state = function()
        renderVehicleStep(pos, baseAngle, 0, 1)
    end
end

local function moveVehicle()
    local veh = be:getPlayerVehicle(0)
    veh:setPosition(referencePos)
    state = function ()
        waitFrames(renderVehicle, 60)
    end
end

M.onUpdate = function()
    state()
end

M.handleImpactGenSetAnnotationPaths = function(skt, msg)
    local partPath = msg['partPath']
    local objPath = msg['objPath']
    zipper.setAnnotationPaths(partPath, objPath)
    rcom.sendACK(skt, 'ImpactGenAnnotationPathsSet')
end

M.handleImpactGenSetImageProperties = function(skt, msg)
    local width = msg['imageWidth']
    local height = msg['imageHeight']
    local colorFmt = msg['colorFmt']
    local annotFmt = msg['annotFmt']
    local f = msg['fov']

    camHeight = msg['height']
    camRadius = msg['radius']

    zipper.setImageProperties(width, height, colorFmt, annotFmt, math.rad(f))

    rcom.sendACK(skt, 'ImpactGenImagePropertiesSet')
end

M.handleImpactGenGenerateOutput = function(skt, msg)
    local veh = be:getPlayerVehicle(0)

    local pos = veh:getSpawnWorldOOBB():getCenter()
    local dir = veh:getDirectionVector()

    util_partAnnotations.annotateParts(veh:getID())

    local baseAngle = math.atan2(dir.y, dir.x)

    local count = 1
    for angle = 0,359,15 do
        renderPerspective(pos, baseAngle + math.rad(angle), count)
        count = count + 1
    end

    local colorName = msg['colorName']
    local annotName = msg['annotName']

    requestMesh(veh)

    local next = function(mesh)
        state = nop
        local parts = extensions.core_vehicle_manager.getPlayerVehicleData().chosenParts
        parts = getRelevantParts(parts)
        parts = jsonEncodePretty(restructureParts(parts))

        setting.level = getLevelName()
        local scenario = jsonEncodePretty(setting)

        log('I', 'Saving zips to: ' .. colorName .. ', ' .. annotName)

        zipper.queueFile('mesh.gltf', mesh)
        zipper.startSavingZips(colorName, annotName, scenario, parts)
        if skt ~= nil then
            rcom.sendACK(skt, 'ImpactGenZipStarted')
        end
    end

    state = function()
        waitForMesh(next)
    end
end

M.handleImpactGenOutputGenerated = function(skt, msg)
    if zipper.checkFinishedSavingZips() then
        rcom.sendMessage(skt, {type = 'ImpactGenZipGenerated', state = true})
    else
        rcom.sendMessage(skt, {type = 'ImpactGenZipGenerated', state = false})
    end
end

local function continueLinear(skt, angle, aPos, bPos, bRot, throttle, config, ego, other)
    local rot = quatFromEuler(0, 0, math.rad(angle))
    ego:setPositionRotation(aPos[1], aPos[2], aPos[3], rot.x, rot.y, rot.z, rot.w)
    rot = quatFromEuler(math.rad(bRot[1]), math.rad(bRot[2]), math.rad(bRot[3]))
    other:setPositionRotation(bPos[1], bPos[2], bPos[3], rot.x, rot.y, rot.z, rot.w)

    other:queueLuaCommand('input.event("throttle", ' .. tostring(throttle) .. ', 1)')

    local next = function()
        rcom.sendACK(skt, 'ImpactGenLinearRan')
        state = nop
    end

    state = function()
        waitForDamage(ego, other, next)
    end
end

M.handleImpactGenRunLinear = function(skt, msg)
    local angle = msg['angle']
    local aPos = msg['aPosition']
    local bPos = msg['bPosition']
    local bRot = msg['bRotation']
    local throttle = msg['throttle']
    local config = msg['config']
    local ego = msg['ego']
    local other = msg['other']

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
        continueLinear(skt, angle, aPos, bPos, bRot, throttle, config, ego, other)
    end

    state = function()
        waitForSpawn(next)
    end
end

local function continueTBone(skt, angle, aPos, bPos, bRot, throttle, config, ego, other)
    local rot = quatFromEuler(0, 0, math.rad(angle))
    ego:setPositionRotation(aPos[1], aPos[2], aPos[3], rot.x, rot.y, rot.z, rot.w)
    rot = quatFromEuler(math.rad(bRot[1]), math.rad(bRot[2]), math.rad(bRot[3]))
    other:setPositionRotation(bPos[1], bPos[2], bPos[3], rot.x, rot.y, rot.z, rot.w)

    other:queueLuaCommand('input.event("throttle", ' .. tostring(throttle) .. ', 1)')

    local next = function()
        rcom.sendACK(skt, 'ImpactGenTBoneRan')
        state = nop
    end

    state = function()
        waitForDamage(ego, other, next)
    end
end

M.handleImpactGenRunTBone = function(skt, msg)
    local angle = msg['angle']
    local aPos = msg['aPosition']
    local bPos = msg['bPosition']
    local bRot = msg['bRotation']
    local throttle = msg['throttle']
    local config = msg['config']
    local ego = msg['ego']
    local other = msg['other']

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
        continueTBone(skt, angle, aPos, bPos, bRot, throttle, config, ego, other)
    end

    state = function()
        waitForSpawn(next)
    end
end

local function continuePole(skt, angle, pos, throttle, config, ego)
    local rot = quatFromEuler(0, 0, math.rad(angle))
    ego:setPositionRotation(pos[1], pos[2], pos[3], rot.x, rot.y, rot.z, rot.w)

    if throttle > 0 then
        ego:queueLuaCommand('input.event("throttle", ' ..    tostring(throttle) .. ', 1)')
    else
        ego:queueLuaCommand('input.event("brake", ' ..    tostring(-throttle) .. ', 1)')
    end

    local next = function()
        rcom.sendACK(skt, 'ImpactGenPoleRan')
        state = nop
    end

    state = function()
        waitForDamage(ego, nil, next)
    end
end

local function placePole(polePos)
    local obj = createObject('TSStatic')
    obj.shapeName = 'levels/west_coast_usa/art/shapes/objects/lamp1.dae'
    local pos = Point3F(polePos[1], polePos[2], polePos[3])
    obj:setPosition(pos)
    local scl = Point3F(1, 1, 1)
    obj:setScale(scl)

    local name = 'impactgen_pole'
    obj.canSave = false
    obj:registerObject(name)

    be:reloadCollision()
end

M.handleImpactGenRunPole = function(skt, msg)
    local angle = msg['angle']
    local pos = msg['position']
    local polePos = msg['polePosition']
    local throttle = msg['throttle']
    local ego = msg['ego']
    local config = msg['config']

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
        continuePole(skt, angle, pos, throttle, config, ego)
    end

    state = function()
        waitForSpawn(next)
    end
end

M.handleImpactGenRunNonCrash = function(skt, msg)
    log('I', 'Handling Non-Crash scenario.')
    local config = msg['config']
    local ego = msg['ego']

    setting = {}
    setting.type = 'nocrash'
    setting.ego = ego
    setting.config = config

    log('I', 'Setting vehicle config.')
    local veh = scenetree.findObject(ego)
    spawnPending = ego
    be:enterVehicle(0, veh)
    core_vehicle_partmgmt.setConfig(config)

    local next = function()
        rcom.sendACK(skt, 'ImpactGenNonCrashRan')
        state = nop
    end

    log('I', 'Waiting for vehicle to respawn.')
    state = function()
        waitForSpawn(next)
    end
end

local function placeSkybox()
    local obj = worldEditorCppApi.createObject('SkyBox')
    log('I', 'SkyBox obj created!')
    local name = 'impactgen_skybox'
    obj.canSave = false
    obj:setName(name)
    scenetree.MissionGroup:add(obj.obj)

    be:reloadCollision()

    skybox = obj
end

local function continuePostSettings(skt, skyboxMat, groundMat)
    if skyboxMat ~= nil then
        log('I', 'Setting sky mat: ' .. groundMat)
        skybox:setField('material', 0, skyboxMat)
        skybox:postApply()
    end

    if groundMat ~= nil then
        log('I', 'Setting ground mat: ' .. groundMat)
        local ground = scenetree.findClassObjects('GroundPlane')[1]
        ground = scenetree.findObjectById(ground)
        ground:setField('material', 0, groundMat)
        ground:setField('squareSize', 0, 1024)
        ground:postApply()
    end

    local notifyPostSettings = function()
        be:setPhysicsRunning(false)
        rcom.sendACK(skt, 'ImpactGenPostSet')
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
        log('I', 'Could not find class instance: ' .. clazz)
    end
end

local function setWeather(time, clouds, fog)
    setClassProperty('TimeOfDay', 'time', time)
    setClassProperty('CloudLayer', 'coverage', clouds)
    setClassProperty('LevelInfo', 'fogDensity', fog)
end

M.handleImpactGenPostSettings = function(skt, msg)
    local ego = msg['ego']
    local time = msg['time']
    local clouds = msg['clouds']
    local fog = msg['fog']
    local color = msg['color']
    local skyboxMat = msg['skybox']
    local groundMat = msg['ground']

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

    if skyboxMat ~= nil then
        if skybox == nil then
            placeSkybox()
        end
    end

    local continue = function()
        continuePostSettings(skt, skyboxMat, groundMat)
    end

    state = function()
        waitFrames(continue, 3)
    end
end

M.onSocketMessage = function(skt, msg)
    local msgType = 'handle' .. msg['type']
    local handler = M[msgType]
    if handler ~= nil then
        handler(skt, msg)
    end
end

M.onVehicleSpawned = function(vID)
    log('I', 'Got vehicle spawn: ' .. vID)
    if spawnPending ~= nil then
        local obj = scenetree.findObject(spawnPending)
        if obj ~= nil and obj:getID() == vID then
            obj:queueLuaCommand('extensions.load("impactgen/damageEvaluation")')
            spawnPending = nil
        end
    end
end

M.onScenarioRestarted = function()
    skybox = nil
end

M.partOptions = {}

return M
