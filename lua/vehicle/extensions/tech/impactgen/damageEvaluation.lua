-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.onInit = function()
  log("I", "damageEvaluation", "Damage evaluation extension loaded.")
end

local function getCareerDamageEvaluation()
  return beamstate.getPartDamageData()
end

local function getDeformSumEvaluation()
  local damage = {}
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    local ratio = 0
    if currentLength > originalLength then
      ratio = originalLength / currentLength
    else
      ratio = currentLength / originalLength
    end
    ratio = 1 - ratio
    ratio = ratio * 15
    ratio = clamp(ratio, 0, 1)

    if damage[part] == nil then
      damage[part] = 0
    end
    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end

    damage[part] = damage[part] + ratio
    beamCounts[part] = beamCounts[part] + 1
  end

  for k, v in pairs(damage) do
    damage[k] = {damage = damage[k] / beamCounts[k]}
  end

  return damage
end

local function getDeformMaxEvaluation()
  local damage = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    local ratio = 0
    if currentLength > originalLength then
      ratio = originalLength / currentLength
    else
      ratio = currentLength / originalLength
    end
    ratio = 1 - ratio
    ratio = ratio * 2
    ratio = clamp(ratio, 0, 1)

    if damage[part] == nil then
      damage[part] = 0
    end

    if ratio > damage[part] then
      damage[part] = ratio
    end
  end

  for k, v in pairs(damage) do
    damage[k] = {damage = damage[k]}
  end

  return damage
end

local function getDeformCountEvaluation()
  local damaged = {}
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    local ratio = 0
    if currentLength > originalLength then
      ratio = originalLength / currentLength
    else
      ratio = currentLength / originalLength
    end
    ratio = 1 - ratio
    ratio = clamp(ratio, 0, 1)

    if damaged[part] == nil then
      damaged[part] = 0
    end

    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end

    if ratio > 0.01 then
      damaged[part] = damaged[part] + 1
    end

    beamCounts[part] = beamCounts[part] + 1
  end

  for k, v in pairs(damaged) do
    damaged[k] = {damage = damaged[k] / beamCounts[k]}
  end

  return damaged
end

local function getStretchSumEvaluation()
  local damage = {}
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    if damage[part] == nil then
      damage[part] = 0
    end
    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end

    beamCounts[part] = beamCounts[part] + 1

    local ratio = 0

    if currentLength > originalLength then
      ratio = originalLength / currentLength
      ratio = 1 - ratio
      ratio = ratio * 15
      ratio = clamp(ratio, 0, 1)
      damage[part] = damage[part] + ratio
    end
  end

  for k, v in pairs(damage) do
    damage[k] = {damage = damage[k] / beamCounts[k]}
  end

  return damage
end

local function getStretchMaxEvaluation()
  local damage = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = vobj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    local ratio = 0

    if damage[part] == nil then
      damage[part] = 0
    end
    if ratio > damage[part] then
      damage[part] = ratio
    end

    if currentLength > originalLength then
      ratio = originalLength / currentLength
      ratio = 1 - ratio
      ratio = ratio * 2
      ratio = clamp(ratio, 0, 1)
    end
  end

  for k, v in pairs(damage) do
    damage[k] = {damage = damage[k]}
  end

  return damage
end

local function getStretchCountEvaluation()
  local damaged = {}
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    if damaged[part] == nil then
      damaged[part] = 0
    end

    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end

    beamCounts[part] = beamCounts[part] + 1

    local ratio = 0
    if currentLength > originalLength then
      ratio = originalLength / currentLength
      ratio = 1 - ratio
      ratio = clamp(ratio, 0, 1)

      if ratio > 0.01 then
        damaged[part] = damaged[part] + 1
      end
    end
  end

  for k, v in pairs(damaged) do
    damaged[k] = {damage = damaged[k] / beamCounts[k]}
  end

  return damaged
end

local function getContractSumEvaluation()
  local damage = {}
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    if damage[part] == nil then
      damage[part] = 0
    end
    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end
    beamCounts[part] = beamCounts[part] + 1

    local ratio = 0

    if currentLength > originalLength then
      ratio = originalLength / currentLength
      ratio = 1 - ratio
      ratio = ratio * 15
      ratio = clamp(ratio, 0, 1)
      damage[part] = damage[part] + ratio
    end
  end

  for k, v in pairs(damage) do
    damage[k] = {damage = damage[k] / beamCounts[k]}
  end

  return damage
end

local function getContractMaxEvaluation()
  local damage = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    local ratio = 0

    if damage[part] == nil then
      damage[part] = 0
    end
    if ratio > damage[part] then
      damage[part] = ratio
    end

    if currentLength > originalLength then
      ratio = originalLength / currentLength
      ratio = 1 - ratio
      ratio = ratio * 2
      ratio = clamp(ratio, 0, 1)
    end
  end

  for k, v in pairs(damage) do
    damage[k] = {damage = damage[k]}
  end

  return damage
end

local function getContractCountEvaluation()
  local damaged = {}
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin

    local p1 = obj:getNodePositionRelative(id1)
    local p2 = obj:getNodePositionRelative(id2)
    local currentLength = (p1 - p2):length()

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)
    local originalLength = (p1 - p2):length()

    if damaged[part] == nil then
      damaged[part] = 0
    end

    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end

    beamCounts[part] = beamCounts[part] + 1

    local ratio = 0
    if currentLength > originalLength then
      ratio = originalLength / currentLength
      ratio = 1 - ratio
      ratio = clamp(ratio, 0, 1)

      if ratio > 0.01 then
        damaged[part] = damaged[part] + 1
      end
    end
  end

  for k, v in pairs(damaged) do
    damaged[k] = {damage = damaged[k] / beamCounts[k]}
  end

  return damaged
end

local function getBreakPercentage()
  local partData = beamstate.getPartData()
  local beamCounts = {}

  for i, beam in pairs(v.data.beams) do
    local part = beam.partOrigin

    if beamCounts[part] == nil then
      beamCounts[part] = 0
    end

    beamCounts[part] = beamCounts[part] + 1
  end

  for k, v in pairs(beamCounts) do
    if partData[k] ~= nil and partData[k].beamsBroken ~= nil then
      beamCounts[k] = {damage = partData[k].beamsBroken / v}
    end
  end

  return beamCounts
end

local function getNodeProperties(id)
  local nodeProperties = {}
  for k, v in pairs(v.data.nodes[id]) do
    if type(v) == "string" or type(v) == "boolean" or type(v) == "number" then
      -- log('I', 'damageEvaluation', 'Node prop: ' .. tostring(k) .. ' of type: ' .. type(v))
      nodeProperties[k] = v
    end
  end
  return nodeProperties
end

local function getBeamProperties(beam)
  local beamProperties = {}
  for k, v in pairs(beam) do
    if type(v) == "string" or type(v) == "boolean" or type(v) == "number" then
      -- log('I', 'damageEvaluation', 'Beam prop: ' .. tostring(k) .. ' of type: ' .. type(v))
      beamProperties[k] = v
    end
  end
  return beamProperties
end

M.getPartBeams = function()
  local partNodeBeams = {}

  for i, beam in pairs(v.data.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin
    local n1 = v.data.nodes[id1].name
    local n2 = v.data.nodes[id2].name

    if partNodeBeams[part] == nil then
      partNodeBeams[part] = {
        nodes = {},
        originalNodes = {},
        beams = {},
        originalBeams = {}
      }
    end

    local p1
    local p2
    local length
    local entry = partNodeBeams[part]

    local properties = {}
    local nodeProperties = {}

    p1 = obj:getOriginalNodePositionRelative(id1)
    p2 = obj:getOriginalNodePositionRelative(id2)

    nodeProperties = getNodeProperties(id1)
    entry.originalNodes[n1] = {x = p1.x, y = p1.y, z = p1.z, properties = nil}

    nodeProperties = getNodeProperties(id2)
    entry.originalNodes[n2] = {x = p2.x, y = p2.y, z = p2.z, properties = nil}

    properties = getBeamProperties(beam)
    length = (p1 - p2):length()
    table.insert(entry.originalBeams, {a = n1, b = n2, length = length})

    p1 = obj:getNodePosition(id1)
    p2 = obj:getNodePosition(id2)

    nodeProperties = getNodeProperties(id1)
    entry.nodes[n1] = {x = p1.x, y = p1.y, z = p1.z, properties = nil}

    nodeProperties = getNodeProperties(id2)
    entry.nodes[n2] = {x = p2.x, y = p2.y, z = p2.z, properties = nil}

    properties = getBeamProperties(beam)
    length = (p1 - p2):length()
    table.insert(entry.beams, {a = n1, b = n2, length = length})
  end

  return partNodeBeams
end

M.evaluateVehicleDamage = function()
  log("I", "damageEvaluation", "Evaluating vehicle damage.")
  local ret = {}
  local scores = {}

  scores["career"] = getCareerDamageEvaluation()

  scores["deformSum"] = getDeformSumEvaluation()
  scores["deformMax"] = getDeformMaxEvaluation()
  scores["deformCount"] = getDeformCountEvaluation()

  scores["stretchSum"] = getStretchSumEvaluation()
  scores["stretchMax"] = getStretchMaxEvaluation()
  scores["stretchCount"] = getStretchCountEvaluation()

  scores["contractSum"] = getContractSumEvaluation()
  scores["contractMax"] = getContractMaxEvaluation()
  scores["contractCount"] = getContractCountEvaluation()

  scores["breakPercent"] = getBreakPercentage()

  local beams = M.getPartBeams()

  return {damageScores = scores, beams = beams}
end

return M
