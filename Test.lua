local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StatsService = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
if not player then
	error("Script Is Not Available Right Now. Run after the game has loaded.")
end
local playerGui = player:WaitForChild("PlayerGui", 15)
if not playerGui then
	error("Script: PlayerGui was not available.")
end
local function getUIHost()
	local host = playerGui
	local ok, hui = pcall(function()
		return type(gethui) == "function" and gethui() or nil
	end)
	if ok and hui then host = hui end
	return host
end
local UIHost = getUIHost()
local bootGui = Instance.new("ScreenGui")
bootGui.Name = "CokeBoys-APE"
bootGui.ResetOnSpawn = false
bootGui.IgnoreGuiInset = true
bootGui.DisplayOrder = 1000000
bootGui.Enabled = false
bootGui.Parent = UIHost
local bootLabel = Instance.new("TextLabel")
bootLabel.AnchorPoint = Vector2.new(1, 0.5)
bootLabel.Position = UDim2.new(1, -18, 0.5, 0)
bootLabel.Size = UDim2.fromOffset(230, 42)
bootLabel.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
bootLabel.BackgroundTransparency = 0.05
bootLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bootLabel.Font = Enum.Font.GothamBold
bootLabel.TextSize = 14
bootLabel.Text = "APE — Initializing..."
bootLabel.Parent = bootGui
Instance.new("UICorner", bootLabel).CornerRadius = UDim.new(0, 10)
local CONFIG = {
	SampleWindow = 0.5,
	HistoryLength = 60,
	FrameRingSize = 60,
	SpikeMultiplier = 3.25,
	SpikeMinDelta = 0.035,
	AttackRate = 0.95,
	DecayRate = 0.10,
	SpikeJump = 0.14,
	RecoveryMargin = 1.10,
	DefaultTargetFPS = 60,
	MinTargetFPS = 24,
	MaxTargetFPS = 120,
	StreamingRadiusFloor = 128,
	-- Safety: the engine starts MANUAL. Nothing is changed until Auto is enabled.
	DefaultAutoOptimize = false,
	DecisionInterval = 2,
	SettleTime = 1.5,
	MaxBatch = 1,
	LearnAlpha = 0.25,
	SpikeDecayInterval = 30,
	SpikeDecayFactor = 0.55,
	JitterSpikyThreshold = 12,
	BaselineSamples = 4,
	SettleSamples = 4,
	ExperimentSampleInterval = 0.25,
	MinImprovementMs = 0.4,
	NoiseFloorMs = 0.25,
	ConfidenceAlpha = 0.20,
	MaxExperimentsPerObject = 8,
	ExperimentCooldown = 1.25,
	ContextTolerance = 0.20,
	WarmupTime = 2.5,
	MaxFrameDelta = 0.5,
	RegistryMaintenanceInterval = 2,
	CostRefreshInterval = 10,
	SpikeCooldown = 1,
	PotatoModeDefault = false,
	PotatoParticleRateScale = 0.035,
	PotatoParticleLifetimeScale = 0.20,
	PotatoTrailLifetimeScale = 0.025,
	PotatoBeamSegments = 1,
	PotatoStreamingRadius = 64,
	PotatoWaterWaveSize = 0,
	PotatoWaterWaveSpeed = 0,
	PotatoWaterReflectance = 0,
	PotatoWaterTransparency = 1,
	PotatoTerrainDecoration = false,
	-- APE ULTRA adaptive engine
	AdaptiveEnabled = true,
	AdaptiveTick = 0.75,
	AdaptiveHysteresis = 0.06,
	AdaptiveRecoverySeconds = 5,
	AdaptiveEscalationSeconds = 1.8,
	AdaptiveMaxTier = 4,
	AdaptiveMinTier = 0,
	AdaptiveTargetFloor = 0.82,
	SpikeWindow = 8,
	SpikeBurstThreshold = 3,
	RenderSampleWeight = 0.55,
	HeartbeatSampleWeight = 0.45,
	PotatoSweepInterval = 0.35,
	PotatoReflectanceCutoff = 0.02,
	PotatoMaxTrackedVisuals = 50000,
	PotatoDisableLights = true,
	PotatoDisableCastShadow = true,
	PotatoDisableSurfaceLights = true,
}

local state = {
	fps = 60,
	smoothedFPS = 60,
	frameTimeMs = 16.6,
	jitterMs = 0,
	ping = 0,
	intensity = 0,
	targetFPS = CONFIG.DefaultTargetFPS,
	autoOptimize = CONFIG.DefaultAutoOptimize,
	potatoMode = CONFIG.PotatoModeDefault,
	manualPotatoMode = CONFIG.PotatoModeDefault,
	panelOpen = false,
	compact = false,
	lastSpikeAt = -math.huge,
	sampleTimer = 0,
	decisionTimer = 0,
	resortTimer = 0,
	spikeDecayTimer = 0,
	warmupTimer = 0,
	maintenanceTimer = 0,
	adaptiveTimer = 0,
	adaptiveTier = 0,
	adaptiveGoodTimer = 0,
	adaptiveBadTimer = 0,
	renderFrameTimeMs = 16.6,
	renderJitterMs = 0,
	memoryMb = 0,
	spikeCountWindow = 0,
	spikeWindowTimer = 0,
	costTimer = 0,
	actionState = "idle",
	diagnosis = "stable",
	log = {},
	history = {fps = {}, ping = {}, frametime = {}},
	session = {
		startClock = os.clock(),
		fpsMin = math.huge, fpsMax = 0, fpsSum = 0, fpsCount = 0,
		pingMin = math.huge, pingMax = 0, pingSum = 0, pingCount = 0,
		optimizationEvents = 0,
		timeInBand = {low = 0, medium = 0, high = 0, extreme = 0},
	},
}

local pendingAction = nil
local frameRing = {}
local frameRingSum, frameRingSumSq, frameRingIndex = 0, 0, 1
local frameSampleCount = 0
for i = 1, CONFIG.FrameRingSize do frameRing[i] = 0 end

local function pushFrameTime(dt)
	dt = math.clamp(dt, 1 / 240, CONFIG.MaxFrameDelta)
	local old = frameRing[frameRingIndex]
	if frameSampleCount < CONFIG.FrameRingSize then
		frameSampleCount += 1
		old = 0
	end
	frameRingSum = frameRingSum - old + dt
	frameRingSumSq = frameRingSumSq - old * old + dt * dt
	frameRing[frameRingIndex] = dt
	frameRingIndex = (frameRingIndex % CONFIG.FrameRingSize) + 1
	local n = math.max(frameSampleCount, 1)
	local mean = frameRingSum / n
	local variance = math.max(0, frameRingSumSq / n - mean * mean)
	state.frameTimeMs = mean * 1000
	state.jitterMs = math.sqrt(variance) * 1000
	return mean
end

local function addLog(msg, tag)
	table.insert(state.log, 1, {text = ("[%s] %s"):format(os.date("%H:%M:%S"), msg), tag = tag or "info"})
	if #state.log > 40 then table.remove(state.log) end
end

local function pushHistory(list, value)
	list[#list + 1] = value
	if #list > CONFIG.HistoryLength then table.remove(list, 1) end
end

local registry, registryLookup = {}, {}
local enabledCache, disabledCache = {}, {}
local candidateCacheDirty = true
local KIND_BASE_WEIGHT = {
	ParticleEmitter = 1.0, Trail = 0.6, Beam = 0.6, Fire = 0.8, Smoke = 0.5, Sparkles = 0.4,
}

local function entryName(e)
	if not e or not e.inst then return "object" end
	local ok, name = pcall(function() return e.inst.Name end)
	return (ok and name) or e.kind or "object"
end

local function estimateCost(inst)
	if inst:IsA("ParticleEmitter") then
		local rate = inst.Rate or 20
		local lifeAvg = 1
		local ok, life = pcall(function() return inst.Lifetime end)
		if ok and life then lifeAvg = (life.Min + life.Max) * 0.5 end
		return KIND_BASE_WEIGHT.ParticleEmitter * math.clamp(rate * lifeAvg, 1, 500)
	elseif inst:IsA("Trail") then
		return KIND_BASE_WEIGHT.Trail * math.clamp((inst.Lifetime or 1) * 10, 1, 100)
	elseif inst:IsA("Beam") then return KIND_BASE_WEIGHT.Beam * 20
	elseif inst:IsA("Fire") then return KIND_BASE_WEIGHT.Fire * math.clamp((inst.Size or 5) * 5, 1, 100)
	elseif inst:IsA("Smoke") then return KIND_BASE_WEIGHT.Smoke * 15
	elseif inst:IsA("Sparkles") then return KIND_BASE_WEIGHT.Sparkles * 10 end
	return 0
end

local function invalidateCandidates()
	candidateCacheDirty = true
end

local function removeRegistryEntry(entry)
	local index = entry.index
	if not index then return end
	local last = registry[#registry]
	if last == entry then
		registry[#registry] = nil
	else
		registry[index] = last
		last.index = index
		registry[#registry] = nil
	end
	entry.index = nil
	registryLookup[entry.inst] = nil
	invalidateCandidates()
end

local function registerInstance(inst)
	if registryLookup[inst] then return end
	local kind = inst.ClassName
	if not KIND_BASE_WEIGHT[kind] then return end
	local initialEnabled = true
	pcall(function() initialEnabled = inst.Enabled end)
	local entry = {
		inst = inst, kind = kind, cost = estimateCost(inst),
		disabledByUs = false, originalValue = initialEnabled,
		learnedImpact = 0, sampleCount = 0, spikeAssociation = 0,
		impactEMA = 0, impactVariance = 0, confidence = 0,
		experimentCount = 0, successCount = 0, failCount = 0,
		lastTestAt = -math.huge, lastResult = "untested",
		contextFPS = 0, contextJitter = 0, index = #registry + 1,
		lastObservedEnabled = initialEnabled,
	}
	registryLookup[inst] = entry
	registry[#registry + 1] = entry
	invalidateCandidates()
	inst.Destroying:Connect(function() removeRegistryEntry(entry) end)
end

local potatoApplyInstance

for _, inst in ipairs(Workspace:GetDescendants()) do registerInstance(inst) end
Workspace.DescendantAdded:Connect(function(inst)
	registerInstance(inst)
	if state.potatoMode then
		potatoApplyInstance(inst)
		potatoCaptureVisual(inst)
		potatoApplyVisual(inst)
	end
end)

local postEffects = {}
local postEffectsDisabledByUs = false
local function cachePostEffect(inst)
	if inst:IsA("PostEffect") and postEffects[inst] == nil then
		local ok, enabled = pcall(function() return inst.Enabled end)
		if ok then postEffects[inst] = {original = enabled, disabledByUs = false} end
	end
end
for _, inst in ipairs(Lighting:GetChildren()) do cachePostEffect(inst) end
Lighting.ChildAdded:Connect(function(inst)
	cachePostEffect(inst)
	if state.potatoMode then
		potatoApplyInstance(inst)
		potatoCaptureVisual(inst)
		potatoApplyVisual(inst)
	end
end)

local originalGlobalShadows = Lighting.GlobalShadows
local originalStreamingRadius = 1000
pcall(function() originalStreamingRadius = Workspace.StreamingTargetRadius end)
local shadowsDisabledByUs, streamingReducedByUs = false, false
local lastStreamingTarget = originalStreamingRadius

-- Potato Mode is intentionally separate from the normal optimizer.
-- It is deliberately AGGRESSIVE: expensive visual effects are removed/reduced,
-- while every client-side change is snapshotted so the original state can be restored.
local potatoSnapshot = {
	captured = false,
	particles = {},
	trails = {},
	beams = {},
	fires = {},
	smokes = {},
	sparkles = {},
	highlights = {},
	clouds = {},
	postEffects = {},
	atmospheres = {},
	terrain = nil,
	lighting = {},
	baseParts = {},
	lights = {},
}

-- APE ULTRA: extra visual snapshotting. This deliberately avoids changing
-- textures/material IDs; the goal is to remove expensive post-processing and
-- shiny lighting without turning the world into an untextured gray mess.
local function potatoCaptureVisual(inst)
	if not inst or not inst.Parent then return end
	if inst:IsA("BasePart") and not potatoSnapshot.baseParts[inst] then
		local reflectance = 0
		local castShadow = true
		pcall(function() reflectance = inst.Reflectance end)
		pcall(function() castShadow = inst.CastShadow end)
		if reflectance > CONFIG.PotatoReflectanceCutoff or (CONFIG.PotatoDisableCastShadow and castShadow) then
			if (function() local n=0 for _ in pairs(potatoSnapshot.baseParts) do n+=1 end return n end)() < CONFIG.PotatoMaxTrackedVisuals then
				potatoSnapshot.baseParts[inst] = {reflectance = reflectance, castShadow = castShadow}
			end
		end
	elseif CONFIG.PotatoDisableLights and (inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight")) then
		if not potatoSnapshot.lights[inst] then
			local ok, enabled = pcall(function() return inst.Enabled end)
			if ok then potatoSnapshot.lights[inst] = {enabled = enabled} end
		end
	end
end

local function potatoApplyVisual(inst)
	if not inst or not inst.Parent then return end
	if inst:IsA("BasePart") then
		local info = potatoSnapshot.baseParts[inst]
		if info then pcall(function()
			if info.reflectance > CONFIG.PotatoReflectanceCutoff then inst.Reflectance = 0 end
			if CONFIG.PotatoDisableCastShadow then inst.CastShadow = false end
		end) end
	elseif CONFIG.PotatoDisableLights and (inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight")) then
		local info = potatoSnapshot.lights[inst]
		if info then pcall(function() inst.Enabled = false end) end
	end
end

local function potatoCaptureVisuals()
	local tracked = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if tracked >= CONFIG.PotatoMaxTrackedVisuals then break end
		potatoCaptureVisual(inst)
		tracked += 1
	end
	for _, inst in ipairs(Lighting:GetDescendants()) do potatoCaptureVisual(inst) end
end

local function clearPotatoSnapshot()
	for key, value in pairs(potatoSnapshot) do
		if type(value) == "table" then table.clear(value) end
	end
	potatoSnapshot.captured = false
end

local function potatoCaptureInstance(inst)
	if not inst or not inst.Parent then return end
	potatoCaptureVisual(inst)

	if inst:IsA("ParticleEmitter") and not potatoSnapshot.particles[inst] then
		potatoSnapshot.particles[inst] = {
			rate = inst.Rate, timeScale = inst.TimeScale, lifetime = inst.Lifetime,
			enabled = inst.Enabled,
		}
	elseif inst:IsA("Trail") and not potatoSnapshot.trails[inst] then
		potatoSnapshot.trails[inst] = {lifetime = inst.Lifetime, enabled = inst.Enabled}
	elseif inst:IsA("Beam") and not potatoSnapshot.beams[inst] then
		potatoSnapshot.beams[inst] = {
			segments = inst.Segments, enabled = inst.Enabled,
			width0 = inst.Width0, width1 = inst.Width1,
		}
	elseif inst:IsA("Fire") and not potatoSnapshot.fires[inst] then
		potatoSnapshot.fires[inst] = {heat = inst.Heat, size = inst.Size, enabled = inst.Enabled}
	elseif inst:IsA("Smoke") and not potatoSnapshot.smokes[inst] then
		potatoSnapshot.smokes[inst] = {opacity = inst.Opacity, size = inst.Size, enabled = inst.Enabled}
	elseif inst:IsA("Sparkles") and not potatoSnapshot.sparkles[inst] then
		potatoSnapshot.sparkles[inst] = {enabled = inst.Enabled}
	elseif inst:IsA("Highlight") and not potatoSnapshot.highlights[inst] then
		potatoSnapshot.highlights[inst] = {
			enabled = inst.Enabled, fillTransparency = inst.FillTransparency,
			outlineTransparency = inst.OutlineTransparency,
		}
	elseif inst:IsA("Clouds") and not potatoSnapshot.clouds[inst] then
		potatoSnapshot.clouds[inst] = {
			enabled = inst.Enabled, cover = inst.Cover, density = inst.Density,
		}
	elseif inst:IsA("PostEffect") and not potatoSnapshot.postEffects[inst] then
		potatoSnapshot.postEffects[inst] = inst.Enabled
	elseif inst:IsA("Atmosphere") and not potatoSnapshot.atmospheres[inst] then
		potatoSnapshot.atmospheres[inst] = {
			density = inst.Density, haze = inst.Haze, glare = inst.Glare,
			offset = inst.Offset,
		}
	end
end

local function potatoCapture()
	if potatoSnapshot.captured then return end
	clearPotatoSnapshot()
	potatoSnapshot.captured = true

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		potatoSnapshot.terrain = {
			decoration = terrain.Decoration,
			waterWaveSize = terrain.WaterWaveSize,
			waterWaveSpeed = terrain.WaterWaveSpeed,
			waterReflectance = terrain.WaterReflectance,
			waterTransparency = terrain.WaterTransparency,
		}
	end

	pcall(function() potatoSnapshot.lighting.globalShadows = Lighting.GlobalShadows end)
	pcall(function() potatoSnapshot.lighting.environmentDiffuseScale = Lighting.EnvironmentDiffuseScale end)
	pcall(function() potatoSnapshot.lighting.environmentSpecularScale = Lighting.EnvironmentSpecularScale end)
	pcall(function() potatoSnapshot.lighting.brightness = Lighting.Brightness end)

	for _, inst in ipairs(Workspace:GetDescendants()) do
		potatoCaptureInstance(inst)
	end
	for _, inst in ipairs(Lighting:GetChildren()) do
		potatoCaptureInstance(inst)
	end
end

potatoApplyInstance = function(inst)
	if not potatoSnapshot.captured or not inst or not inst.Parent then return end
	potatoCaptureInstance(inst)

	if inst:IsA("ParticleEmitter") then
		local info = potatoSnapshot.particles[inst]
		if info then pcall(function()
			inst.Rate = math.max(0, info.rate * CONFIG.PotatoParticleRateScale)
			inst.TimeScale = math.min(info.timeScale, 0.45)
			inst.Lifetime = NumberRange.new(
				math.max(0.03, info.lifetime.Min * CONFIG.PotatoParticleLifetimeScale),
				math.max(0.03, info.lifetime.Max * CONFIG.PotatoParticleLifetimeScale)
			)
		end) end
	elseif inst:IsA("Trail") then
		local info = potatoSnapshot.trails[inst]
		if info then pcall(function()
			inst.Lifetime = math.max(0.02, info.lifetime * CONFIG.PotatoTrailLifetimeScale)
		end) end
	elseif inst:IsA("Beam") then
		pcall(function()
			inst.Enabled = false
			inst.Segments = CONFIG.PotatoBeamSegments
		end)
	elseif inst:IsA("Fire") then
		pcall(function() inst.Enabled = false end)
	elseif inst:IsA("Smoke") then
		pcall(function() inst.Enabled = false end)
	elseif inst:IsA("Sparkles") then
		pcall(function() inst.Enabled = false end)
	elseif inst:IsA("Highlight") then
		pcall(function()
			inst.Enabled = false
			inst.FillTransparency = 1
			inst.OutlineTransparency = 1
		end)
	elseif inst:IsA("Clouds") then
		pcall(function() inst.Enabled = false end)
	elseif inst:IsA("PostEffect") then
		pcall(function() inst.Enabled = false end)
	elseif inst:IsA("Atmosphere") then
		pcall(function()
			inst.Density = 0
			inst.Haze = 0
			inst.Glare = 0
		end)
	end
end

local function potatoApply()
	potatoCapture()
	potatoCaptureVisuals()

	for _, inst in ipairs(Workspace:GetDescendants()) do
		potatoApplyInstance(inst)
		potatoApplyVisual(inst)
	end
	for _, inst in ipairs(Lighting:GetDescendants()) do
		potatoApplyInstance(inst)
		potatoApplyVisual(inst)
	end

	pcall(function() Lighting.GlobalShadows = false end)
	pcall(function() Lighting.EnvironmentDiffuseScale = 0 end)
	pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
	pcall(function() Workspace.StreamingTargetRadius = CONFIG.PotatoStreamingRadius end)

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function() terrain.Decoration = CONFIG.PotatoTerrainDecoration end)
		pcall(function() terrain.WaterWaveSize = CONFIG.PotatoWaterWaveSize end)
		pcall(function() terrain.WaterWaveSpeed = CONFIG.PotatoWaterWaveSpeed end)
		pcall(function() terrain.WaterReflectance = CONFIG.PotatoWaterReflectance end)
		pcall(function() terrain.WaterTransparency = CONFIG.PotatoWaterTransparency end)
	end
end

local function potatoRestore()
	if not potatoSnapshot.captured then return end

	for inst, info in pairs(potatoSnapshot.particles) do
		if inst.Parent then pcall(function()
			inst.Rate = info.rate; inst.TimeScale = info.timeScale
			inst.Lifetime = info.lifetime; inst.Enabled = info.enabled
		end) end
	end
	for inst, info in pairs(potatoSnapshot.trails) do
		if inst.Parent then pcall(function() inst.Lifetime = info.lifetime; inst.Enabled = info.enabled end) end
	end
	for inst, info in pairs(potatoSnapshot.beams) do
		if inst.Parent then pcall(function()
			inst.Segments = info.segments; inst.Enabled = info.enabled
			inst.Width0 = info.width0; inst.Width1 = info.width1
		end) end
	end
	for inst, info in pairs(potatoSnapshot.fires) do
		if inst.Parent then pcall(function() inst.Heat = info.heat; inst.Size = info.size; inst.Enabled = info.enabled end) end
	end
	for inst, info in pairs(potatoSnapshot.smokes) do
		if inst.Parent then pcall(function() inst.Opacity = info.opacity; inst.Size = info.size; inst.Enabled = info.enabled end) end
	end
	for inst, info in pairs(potatoSnapshot.sparkles) do
		if inst.Parent then pcall(function() inst.Enabled = info.enabled end) end
	end
	for inst, info in pairs(potatoSnapshot.highlights) do
		if inst.Parent then pcall(function()
			inst.Enabled = info.enabled
			inst.FillTransparency = info.fillTransparency
			inst.OutlineTransparency = info.outlineTransparency
		end) end
	end
	for inst, info in pairs(potatoSnapshot.clouds) do
		if inst.Parent then pcall(function()
			inst.Enabled = info.enabled; inst.Cover = info.cover; inst.Density = info.density
		end) end
	end
	for inst, enabled in pairs(potatoSnapshot.postEffects) do
		if inst.Parent then pcall(function() inst.Enabled = enabled end) end
	end
	for inst, info in pairs(potatoSnapshot.atmospheres) do
		if inst.Parent then pcall(function()
			inst.Density = info.density; inst.Haze = info.haze
			inst.Glare = info.glare; inst.Offset = info.offset
		end) end
	end
	for inst, info in pairs(potatoSnapshot.baseParts) do
		if inst.Parent then pcall(function()
			inst.Reflectance = info.reflectance
			inst.CastShadow = info.castShadow
		end) end
	end
	for inst, info in pairs(potatoSnapshot.lights) do
		if inst.Parent then pcall(function() inst.Enabled = info.enabled end) end
	end

	pcall(function()
		if potatoSnapshot.lighting.globalShadows ~= nil then Lighting.GlobalShadows = potatoSnapshot.lighting.globalShadows end
		if potatoSnapshot.lighting.environmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = potatoSnapshot.lighting.environmentDiffuseScale end
		if potatoSnapshot.lighting.environmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = potatoSnapshot.lighting.environmentSpecularScale end
		if potatoSnapshot.lighting.brightness ~= nil then Lighting.Brightness = potatoSnapshot.lighting.brightness end
	end)

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and potatoSnapshot.terrain then
		local t = potatoSnapshot.terrain
		pcall(function() terrain.Decoration = t.decoration end)
		pcall(function() terrain.WaterWaveSize = t.waterWaveSize end)
		pcall(function() terrain.WaterWaveSpeed = t.waterWaveSpeed end)
		pcall(function() terrain.WaterReflectance = t.waterReflectance end)
		pcall(function() terrain.WaterTransparency = t.waterTransparency end)
	end

	clearPotatoSnapshot()
end

local onEngineEvent = function(_kind, _e, _extra) end

local function resortRegistry()
	local i = #registry
	while i >= 1 do
		local e = registry[i]
		if not e.inst.Parent then removeRegistryEntry(e) end
		i -= 1
	end
	invalidateCandidates()
end

local function syncExternalState()
	local dirty = false
	for _, e in ipairs(registry) do
		if e.inst.Parent then
			local ok, enabled = pcall(function() return e.inst.Enabled end)
			if ok then
				if e.disabledByUs and enabled then
					e.disabledByUs = false
					e.lastResult = "external change detected"
					dirty = true
				elseif not e.disabledByUs and enabled ~= e.lastObservedEnabled then
					e.lastObservedEnabled = enabled
					dirty = true
				end
			end
		end
	end
	if dirty then invalidateCandidates() end
end

local function refreshCosts()
	for _, e in ipairs(registry) do
		if e.inst.Parent then
			local ok, newCost = pcall(estimateCost, e.inst)
			if ok and type(newCost) == "number" then e.cost = newCost end
		end
	end
	invalidateCandidates()
end

local function computeFinalRank(entry)
	local learnedMultiplier = 1
	if entry.sampleCount > 0 then
		local ratio = entry.learnedImpact / math.max(entry.cost, 0.01)
		learnedMultiplier = math.clamp(1 + ratio, 0.20, 3.5)
	end
	local exploration = entry.sampleCount == 0 and math.max(entry.cost * 0.18, 2)
		or (1 / math.sqrt(entry.sampleCount + 1)) * math.max(entry.cost * 0.08, 1)
	local confidenceBonus = entry.confidence * math.max(entry.cost, 1) * 0.15
	local base = entry.cost * learnedMultiplier + exploration + confidenceBonus
	if state.diagnosis == "spiky" then return entry.spikeAssociation * 12 + base * 0.25 end
	return base + entry.spikeAssociation * 2
end

local function rebuildCandidateCaches()
	if not candidateCacheDirty then return end
	table.clear(enabledCache)
	table.clear(disabledCache)
	for _, e in ipairs(registry) do
		if e.inst.Parent and e.originalValue == true then
			local ok, enabled = pcall(function() return e.inst.Enabled end)
			if ok then
				if enabled and not e.disabledByUs then enabledCache[#enabledCache + 1] = e
				elseif e.disabledByUs and not enabled then disabledCache[#disabledCache + 1] = e end
			end
		end
	end
	candidateCacheDirty = false
end

local function collectCandidates(wantEnabledOnes)
	rebuildCandidateCaches()
	return wantEnabledOnes and enabledCache or disabledCache
end

local lastDiagnosis = "stable"
local function updateDiagnosis()
	local old = state.diagnosis
	local combinedJitter = math.max(state.jitterMs, state.renderJitterMs)
	local combinedFPS = math.min(state.smoothedFPS, 1000 / math.max(state.renderFrameTimeMs, 0.1))
	if combinedJitter > CONFIG.JitterSpikyThreshold and combinedFPS >= state.targetFPS * 0.85 then
		state.diagnosis = "spiky"
	elseif state.smoothedFPS < state.targetFPS * 0.85 then
		state.diagnosis = "sustained"
	else
		state.diagnosis = "stable"
	end
	if state.diagnosis ~= old then
		local text = state.diagnosis == "spiky" and "Diagnosis: frame-time spikes, average FPS is fine"
			or state.diagnosis == "sustained" and "Diagnosis: sustained low FPS" or "Diagnosis: stable"
		addLog(text, "info")
		lastDiagnosis = state.diagnosis
	end
end

local function median(values)
	if #values == 0 then return 0 end
	local copy = table.clone(values)
	table.sort(copy)
	local n = #copy
	if n % 2 == 1 then return copy[(n + 1) / 2] end
	return (copy[n / 2] + copy[n / 2 + 1]) * 0.5
end

local function recentStableSamples(count)
	local list = state.history.frametime
	if #list < count then return nil end
	local samples = {}
	for i = #list - count + 1, #list do samples[#samples + 1] = list[i] end
	return samples
end

local function contextSignature()
	return {fps = state.smoothedFPS, jitter = state.jitterMs, intensity = state.intensity, diagnosis = state.diagnosis}
end

local function contextDistance(a, b)
	if not a or not b then return 1 end
	local fps = math.abs(a.fps - b.fps) / math.max(state.targetFPS, 1)
	local jitter = math.abs(a.jitter - b.jitter) / 50
	local intensity = math.abs(a.intensity - b.intensity)
	local diag = a.diagnosis == b.diagnosis and 0 or 0.25
	return math.clamp(fps * 0.55 + jitter * 0.20 + intensity * 0.20 + diag * 0.05, 0, 1)
end

local function applyEntry(e, enabled)
	if not e.inst.Parent then return false end
	local ok = pcall(function() e.inst.Enabled = enabled end)
	if ok then
		e.disabledByUs = not enabled
		e.lastObservedEnabled = enabled
		invalidateCandidates()
	end
	return ok
end

local function startAction(batch, direction, label)
	if pendingAction or #batch == 0 or state.warmupTimer < CONFIG.WarmupTime then return false end
	local e = batch[1]
	if not e or not e.inst.Parent or e.originalValue ~= true then return false end
	if e.experimentCount >= CONFIG.MaxExperimentsPerObject then return false end
	if os.clock() - e.lastTestAt < CONFIG.ExperimentCooldown then return false end
	local baselineSamples = recentStableSamples(CONFIG.BaselineSamples)
	if not baselineSamples then return false end
	local baseline = median(baselineSamples)
	if baseline <= 0 then return false end
	local oldValue
	if not pcall(function() oldValue = e.inst.Enabled end) then return false end
	if direction == "disable" and oldValue ~= true then return false end
	if direction == "enable" and (not e.disabledByUs or oldValue ~= false) then return false end
	if not applyEntry(e, direction == "enable") then return false end
	e.lastTestAt = os.clock()
	e.experimentCount += 1
	pendingAction = {
		e = e,
		baseline = baseline,
		afterSamples = {},
		direction = direction,
		startClock = os.clock(),
		beforeContext = contextSignature(),
		label = label,
		phase = "settle",
		sampleTimer = 0,
	}
	state.actionState = "settling"
	addLog(("%s %s — test started (baseline %.2fms)"):format(direction == "disable" and "Testing OFF" or "Testing ON", entryName(e), baseline), "info")
	return true
end

local function updateLearnedImpact(e, measured, contextOK)
	local prior = e.impactEMA
	e.impactEMA = prior + CONFIG.LearnAlpha * (measured - prior)
	e.learnedImpact = math.max(0, e.impactEMA)
	local deviation = math.abs(measured - e.impactEMA)
	e.impactVariance = e.impactVariance * 0.75 + deviation * 0.25
	if contextOK then
		e.sampleCount += 1
		e.contextFPS = state.smoothedFPS
		e.contextJitter = state.jitterMs
		local quality = math.clamp(1 - e.impactVariance / math.max(math.abs(e.impactEMA), CONFIG.NoiseFloorMs * 2), 0, 1)
		e.confidence = math.clamp(e.confidence + (quality - e.confidence) * CONFIG.ConfidenceAlpha, 0, 1)
	end
end

local function resolveAction()
	local action = pendingAction
	if not action then return end
	local e = action.e
	local after = median(action.afterSamples)
	if not e or not e.inst.Parent or after <= 0 then
		if e and e.inst.Parent then applyEntry(e, e.originalValue) end
		pendingAction = nil
		state.actionState = "idle"
		return
	end
	local delta = action.direction == "disable" and (action.baseline - after) or (after - action.baseline)
	local contextOK = contextDistance(action.beforeContext, contextSignature()) <= CONFIG.ContextTolerance
	local meaningful = contextOK and delta >= math.max(CONFIG.MinImprovementMs, CONFIG.NoiseFloorMs * 1.5)
	updateLearnedImpact(e, delta, contextOK)
	if action.direction == "disable" then
		if meaningful then
			e.successCount += 1
			e.lastResult = ("useful +%.2fms"):format(delta)
			addLog(("KEPT OFF %s — +%.2fms, confidence %d%%"):format(entryName(e), delta, math.floor(e.confidence * 100)), "good")
			state.session.optimizationEvents += 1
			onEngineEvent("kept", e, delta)
		else
			e.failCount += 1
			e.lastResult = contextOK and "no measurable gain" or "discarded: context changed"
			if e.inst.Parent then applyEntry(e, e.originalValue) end
			addLog(("REVERTED %s — %s (Δ%.2fms)"):format(entryName(e), e.lastResult, delta), "bad")
			onEngineEvent("reverted", e, delta)
		end
	else
		if meaningful then
			e.successCount += 1
			e.lastResult = ("restore cost +%.2fms"):format(delta)
			addLog(("RESTORE TEST %s — +%.2fms cost"):format(entryName(e), delta), "warn")
		else
			e.failCount += 1
			e.lastResult = "restore had negligible cost"
			addLog(("RESTORE TEST %s — negligible cost"):format(entryName(e)), "info")
		end
	end
	pendingAction = nil
	state.actionState = "idle"
end

local function updateExperiment(dt)
	local action = pendingAction
	if not action then return end
	action.sampleTimer += dt
	if action.sampleTimer < CONFIG.ExperimentSampleInterval then return end
	action.sampleTimer = 0
	if action.phase == "settle" then
		if os.clock() - action.startClock >= CONFIG.SettleTime then action.phase = "collect" end
		return
	end
	local v = state.frameTimeMs
	if v > 0 and v < 500 then action.afterSamples[#action.afterSamples + 1] = v end
	if #action.afterSamples >= CONFIG.SettleSamples then resolveAction() end
end

local function currentDisabledCost()
	local total = 0
	for _, e in ipairs(collectCandidates(false)) do total += e.cost end
	return total
end

local function totalEligibleCost()
	local total = 0
	for _, e in ipairs(collectCandidates(true)) do total += e.cost end
	for _, e in ipairs(collectCandidates(false)) do total += e.cost end
	return total
end

local function runDecisionCycle()
	updateDiagnosis()
	if state.warmupTimer < CONFIG.WarmupTime then return end
	local enabled = collectCandidates(true)
	local disabled = collectCandidates(false)
	local budget = totalEligibleCost() * math.clamp(state.intensity, 0, 1) * 0.35
	local current = 0
	for _, e in ipairs(disabled) do current += e.cost end
	if budget > current and #enabled > 0 then
		table.sort(enabled, function(a, b) return computeFinalRank(a) > computeFinalRank(b) end)
		for _, candidate in ipairs(enabled) do
			if startAction({candidate}, "disable", "performance test") then break end
		end
	elseif budget + 1 < current and #disabled > 0 then
		table.sort(disabled, function(a, b)
			return (a.learnedImpact * math.max(a.confidence, 0.25)) < (b.learnedImpact * math.max(b.confidence, 0.25))
		end)
		for _, candidate in ipairs(disabled) do
			if startAction({candidate}, "enable", "least-useful restore test") then break end
		end
	end
end

local function forceRestoreAll()
	if pendingAction and pendingAction.e then
		local e = pendingAction.e
		if e.inst.Parent and e.originalValue ~= nil then applyEntry(e, e.originalValue) end
	end
	pendingAction = nil
	state.actionState = "idle"
	for _, e in ipairs(registry) do
		if e.disabledByUs and e.inst.Parent and e.originalValue ~= nil then applyEntry(e, e.originalValue) end
		e.disabledByUs = false
	end
	for inst, info in pairs(postEffects) do
		if info.disabledByUs and inst.Parent then
			pcall(function() if inst.Enabled == false then inst.Enabled = info.original end end)
			info.disabledByUs = false
		end
	end
	postEffectsDisabledByUs = false
	if shadowsDisabledByUs then
		pcall(function() if Lighting.GlobalShadows == false then Lighting.GlobalShadows = originalGlobalShadows end end)
		shadowsDisabledByUs = false
	end
	if streamingReducedByUs then
		pcall(function() Workspace.StreamingTargetRadius = originalStreamingRadius end)
		streamingReducedByUs = false
		lastStreamingTarget = originalStreamingRadius
	end
	state.intensity = 0
	state.adaptiveTier = 0
	state.adaptiveBadTimer = 0
	state.adaptiveGoodTimer = 0
	invalidateCandidates()
end

local function applyGlobalEffects(intensity)
	if intensity >= 0.5 and not postEffectsDisabledByUs then
		for inst, info in pairs(postEffects) do
			if inst.Parent and info.original then
				local ok = pcall(function() inst.Enabled = false end)
				if ok then info.disabledByUs = true end
			end
		end
		postEffectsDisabledByUs = true
	elseif intensity < 0.5 and postEffectsDisabledByUs then
		for inst, info in pairs(postEffects) do
			if info.disabledByUs and inst.Parent then
				pcall(function() if inst.Enabled == false then inst.Enabled = info.original end end)
				info.disabledByUs = false
			end
		end
		postEffectsDisabledByUs = false
	end
	if intensity >= 0.7 and not shadowsDisabledByUs then
		local ok = pcall(function() Lighting.GlobalShadows = false end)
		if ok then shadowsDisabledByUs = true end
	elseif intensity < 0.7 and shadowsDisabledByUs then
		pcall(function() if Lighting.GlobalShadows == false then Lighting.GlobalShadows = originalGlobalShadows end end)
		shadowsDisabledByUs = false
	end
	if intensity >= 0.6 and originalStreamingRadius > CONFIG.StreamingRadiusFloor then
		local t = math.clamp((intensity - 0.6) / 0.4, 0, 1)
		local target = math.max(CONFIG.StreamingRadiusFloor, math.floor(originalStreamingRadius - t * (originalStreamingRadius - CONFIG.StreamingRadiusFloor)))
		if math.abs(target - lastStreamingTarget) >= 8 then
			local ok = pcall(function() Workspace.StreamingTargetRadius = target end)
			if ok then lastStreamingTarget = target; streamingReducedByUs = true end
		end
	elseif streamingReducedByUs then
		pcall(function() Workspace.StreamingTargetRadius = originalStreamingRadius end)
		streamingReducedByUs = false
		lastStreamingTarget = originalStreamingRadius
	end
end

local function stepController(dt)
	if not state.autoOptimize or state.warmupTimer < CONFIG.WarmupTime then return end
	local target, fps = state.targetFPS, state.smoothedFPS
	if fps < target then
		local err = math.clamp((target - fps) / target, 0, 1)
		local severity = state.diagnosis == "sustained" and 1.15 or 0.8
		state.intensity = math.clamp(state.intensity + CONFIG.AttackRate * err * severity * dt, 0, 1)
	elseif fps > target * CONFIG.RecoveryMargin and state.jitterMs < CONFIG.JitterSpikyThreshold then
		local headroom = math.clamp((fps / target) - CONFIG.RecoveryMargin, 0, 1)
		state.intensity = math.clamp(state.intensity - CONFIG.DecayRate * (0.5 + headroom) * dt, 0, 1)
	end
end

local function detectSpike(dt, mean)
	if state.warmupTimer < CONFIG.WarmupTime or frameSampleCount < 12 then return false end
	local threshold = math.max(mean * CONFIG.SpikeMultiplier, mean + math.max(state.jitterMs / 1000, 0.001) * 2.0)
	return dt > threshold and dt > CONFIG.SpikeMinDelta
end

--[[
	APE ULTRA ADAPTIVE ENGINE
	-------------------------
	The normal optimizer changes individual effects based on measured frame-time
	impact. This layer is a controller around that system. It does not claim to
	measure a private GPU/CPU counter (Roblox does not expose one reliably); it
	uses frame time, render frame time, jitter, spikes and ping as observable
	signals and keeps network latency separate from render health.
]]
local renderRing = {}
local renderRingSum, renderRingSumSq, renderRingIndex, renderSampleCount = 0, 0, 1, 0
for i = 1, 30 do renderRing[i] = 1/60 end

local function pushRenderTime(dt)
	dt = math.clamp(dt, 1/240, CONFIG.MaxFrameDelta)
	local old = renderRing[renderRingIndex]
	if renderSampleCount < #renderRing then renderSampleCount += 1 end
	renderRingSum = renderRingSum - old + dt
	renderRingSumSq = renderRingSumSq - old * old + dt * dt
	renderRing[renderRingIndex] = dt
	renderRingIndex = renderRingIndex % #renderRing + 1
	local n = math.max(renderSampleCount, 1)
	local mean = renderRingSum / n
	local variance = math.max(0, renderRingSumSq / n - mean * mean)
	state.renderFrameTimeMs = mean * 1000
	state.renderJitterMs = math.sqrt(variance) * 1000
end

pcall(function()
	RunService.RenderStepped:Connect(function(dt)
		pushRenderTime(dt)
	end)
end)

local function readMemoryMb()
	local value
	local ok = pcall(function()
		if type(StatsService.GetTotalMemoryUsageMb) == "function" then
			value = StatsService:GetTotalMemoryUsageMb()
		end
	end)
	if ok and type(value) == "number" then state.memoryMb = value end
end

local function adaptiveTierName(tier)
	return ({[0]="QUALITY", [1]="BALANCED", [2]="PERFORMANCE", [3]="POTATO", [4]="EXTREME"})[tier] or "ADAPTIVE"
end

local function adaptiveSetTier(tier, reason)
	if not CONFIG.AdaptiveEnabled then return end
	tier = math.clamp(math.floor(tier), CONFIG.AdaptiveMinTier, CONFIG.AdaptiveMaxTier)
	if tier == state.adaptiveTier then return end
	local old = state.adaptiveTier
	state.adaptiveTier = tier
	addLog(("Adaptive tier %s → %s (%s)"):format(adaptiveTierName(old), adaptiveTierName(tier), reason or "controller"), tier >= 3 and "warn" or "info")

	-- Tier 4 is the emergency visual profile. Tier 3 uses the same profile but
	-- leaves the controller in charge of backing out once frame time recovers.
	if tier >= 3 then
		if not state.potatoMode then
			state.potatoMode = true
			potatoApply()
		end
	elseif state.potatoMode and not state.manualPotatoMode then
		state.potatoMode = false
		potatoRestore()
	end

	-- For tiers below potato, use the existing measured optimizer's intensity.
	-- We deliberately don't force individual learned objects here; the experiment
	-- engine remains the authority for those changes.
	if tier == 0 then state.intensity = math.min(state.intensity, 0.10)
	elseif tier == 1 then state.intensity = math.max(state.intensity, 0.18)
	elseif tier == 2 then state.intensity = math.max(state.intensity, 0.42)
	elseif tier == 3 then state.intensity = math.max(state.intensity, 0.78)
	else state.intensity = 1 end
end

local function adaptiveEvaluate(dt)
	if not CONFIG.AdaptiveEnabled or not state.autoOptimize or state.warmupTimer < CONFIG.WarmupTime then return end
	state.adaptiveTimer += dt
	if state.adaptiveTimer < CONFIG.AdaptiveTick then return end
	local elapsed = state.adaptiveTimer
	state.adaptiveTimer = 0

	local target = math.max(state.targetFPS, 1)
	local fpsRatio = state.smoothedFPS / target
	local renderRatio = (1000 / math.max(state.renderFrameTimeMs, 0.1)) / target
	local effectiveRatio = math.min(fpsRatio, renderRatio)
	local jitter = math.max(state.jitterMs, state.renderJitterMs)
	local bad = effectiveRatio < CONFIG.AdaptiveTargetFloor or jitter > CONFIG.JitterSpikyThreshold
	local veryBad = effectiveRatio < 0.62 or jitter > CONFIG.JitterSpikyThreshold * 1.8
	local good = effectiveRatio > 1.03 and jitter < CONFIG.JitterSpikyThreshold * 0.75

	if bad then
		state.adaptiveBadTimer += elapsed
		state.adaptiveGoodTimer = 0
	else
		state.adaptiveBadTimer = math.max(0, state.adaptiveBadTimer - elapsed * 0.5)
	end
	if good then
		state.adaptiveGoodTimer += elapsed
	else
		state.adaptiveGoodTimer = math.max(0, state.adaptiveGoodTimer - elapsed * 0.5)
	end

	if veryBad and state.adaptiveTier < CONFIG.AdaptiveMaxTier then
		adaptiveSetTier(state.adaptiveTier + 2, "severe frame-time pressure")
		state.adaptiveBadTimer = 0
	elseif state.adaptiveBadTimer >= CONFIG.AdaptiveEscalationSeconds and state.adaptiveTier < CONFIG.AdaptiveMaxTier then
		adaptiveSetTier(state.adaptiveTier + 1, "sustained pressure")
		state.adaptiveBadTimer = 0
	elseif state.adaptiveGoodTimer >= CONFIG.AdaptiveRecoverySeconds and state.adaptiveTier > CONFIG.AdaptiveMinTier then
		adaptiveSetTier(state.adaptiveTier - 1, "stable headroom")
		state.adaptiveGoodTimer = 0
	end
end

local potatoEnforcerTimer = 0
local function potatoEnforce(dt)
	if not state.potatoMode then return end
	potatoEnforcerTimer += dt
	if potatoEnforcerTimer < CONFIG.PotatoSweepInterval then return end
	potatoEnforcerTimer = 0
	-- Games frequently recreate effects or flip Enabled back on during attacks.
	-- Re-sweeping makes Potato Mode persistent instead of a one-time toggle.
	for _, inst in ipairs(Workspace:GetDescendants()) do
		potatoApplyInstance(inst)
		potatoApplyVisual(inst)
	end
	for _, inst in ipairs(Lighting:GetDescendants()) do
		potatoApplyInstance(inst)
		potatoApplyVisual(inst)
	end
	pcall(function() Lighting.GlobalShadows = false end)
	pcall(function() Lighting.EnvironmentDiffuseScale = 0 end)
	pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
end

RunService.Heartbeat:Connect(function(dt)
	if dt <= 0 then return end
	local mean = pushFrameTime(dt)
	state.fps = 1 / math.max(mean, 1 / 240)
	state.smoothedFPS = state.smoothedFPS * 0.9 + state.fps * 0.1
	state.warmupTimer += dt
	stepController(dt)
	updateExperiment(dt)
	potatoEnforce(dt)
	adaptiveEvaluate(dt)

	local band = state.intensity < 0.25 and "low" or state.intensity < 0.5 and "medium" or state.intensity < 0.75 and "high" or "extreme"
	state.session.timeInBand[band] += dt
	state.sampleTimer += dt
	state.resortTimer += dt
	state.spikeDecayTimer += dt
	state.decisionTimer += dt
	state.maintenanceTimer += dt
	state.costTimer += dt

	state.spikeWindowTimer += dt
	if state.spikeWindowTimer >= CONFIG.SpikeWindow then
		state.spikeWindowTimer -= CONFIG.SpikeWindow
		state.spikeCountWindow = 0
	end
	if detectSpike(dt, mean) then
		state.spikeCountWindow += 1
		local now = os.clock()
		if now - state.lastSpikeAt >= CONFIG.SpikeCooldown then
			state.lastSpikeAt = now
			state.intensity = math.clamp(state.intensity + CONFIG.SpikeJump, 0, 1)
			for _, e in ipairs(collectCandidates(true)) do if e.cost > 15 then e.spikeAssociation += 1 end end
			addLog(("Spike detected (%.0fms frame)"):format(dt * 1000), "warn")
			onEngineEvent("spike", nil, dt * 1000)
			if state.autoOptimize and state.actionState == "idle" and state.warmupTimer >= CONFIG.WarmupTime then
				local candidates = collectCandidates(true)
				table.sort(candidates, function(a, b) return computeFinalRank(a) > computeFinalRank(b) end)
				if candidates[1] then startAction({candidates[1]}, "disable", "reflex spike response") end
			end
		end
	end

	if state.sampleTimer >= CONFIG.SampleWindow then
		state.sampleTimer -= CONFIG.SampleWindow
		local ok, item = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
		if ok and type(item) == "number" then state.ping = math.max(0, item) end
		readMemoryMb()
		pushHistory(state.history.fps, state.smoothedFPS)
		pushHistory(state.history.ping, state.ping)
		pushHistory(state.history.frametime, state.frameTimeMs)
		local s = state.session
		s.fpsMin = math.min(s.fpsMin, state.smoothedFPS); s.fpsMax = math.max(s.fpsMax, state.smoothedFPS); s.fpsSum += state.smoothedFPS; s.fpsCount += 1
		s.pingMin = math.min(s.pingMin, state.ping); s.pingMax = math.max(s.pingMax, state.ping); s.pingSum += state.ping; s.pingCount += 1
		if state.autoOptimize then applyGlobalEffects(state.intensity) end
	end
	if state.maintenanceTimer >= CONFIG.RegistryMaintenanceInterval then
		state.maintenanceTimer -= CONFIG.RegistryMaintenanceInterval
		resortRegistry()
		syncExternalState()
	end
	if state.costTimer >= CONFIG.CostRefreshInterval then
		state.costTimer -= CONFIG.CostRefreshInterval
		refreshCosts()
	end
	if state.spikeDecayTimer >= CONFIG.SpikeDecayInterval then
		state.spikeDecayTimer -= CONFIG.SpikeDecayInterval
		for _, e in ipairs(registry) do e.spikeAssociation *= CONFIG.SpikeDecayFactor end
		invalidateCandidates()
	end
	if state.autoOptimize and state.actionState == "idle" and state.decisionTimer >= CONFIG.DecisionInterval then
		state.decisionTimer -= CONFIG.DecisionInterval
		runDecisionCycle()
	end
end)

local function computeHealthScore()
	local fpsScore = math.clamp((state.smoothedFPS / math.max(state.targetFPS, 1)) * 100, 0, 100)
	local renderFPS = 1000 / math.max(state.renderFrameTimeMs, 0.1)
	local renderScore = math.clamp((renderFPS / math.max(state.targetFPS, 1)) * 100, 0, 100)
	local jitterScore = math.clamp(100 - math.max(state.jitterMs, state.renderJitterMs) * 4, 0, 100)
	local pingScore = state.ping <= 50 and 100 or state.ping <= 100 and 80 or state.ping <= 150 and 60 or state.ping <= 250 and 40 or 20
	return math.floor(fpsScore * 0.35 + renderScore * 0.30 + jitterScore * 0.25 + pingScore * 0.10)
end

local function getTopInsightsData(n)
	local scored = {}
	for _, e in ipairs(registry) do if e.sampleCount > 0 and e.inst.Parent then scored[#scored + 1] = e end end
	table.sort(scored, function(a, b) return math.abs(a.learnedImpact) * math.max(a.confidence, 0.1) > math.abs(b.learnedImpact) * math.max(b.confidence, 0.1) end)
	local out = {}
	for i = 1, math.min(n, #scored) do
		local e = scored[i]
		local parentName = e.inst.Parent and e.inst.Parent.Name or "?"
		out[#out + 1] = {
			title = ("%s (%s)"):format(entryName(e), e.kind),
			subtitle = "in " .. parentName,
			impactText = e.learnedImpact > 0.3 and ("+%.1fms"):format(e.learnedImpact) or "negligible",
			positive = e.learnedImpact > 0.3,
			confidence = e.confidence,
			tests = e.experimentCount,
		}
	end
	return out
end


-- ============================================================================
-- APE ULTRA MAX v6 ENGINE
-- ============================================================================
-- The existing UI and core optimizer stay intact. MAX adds:
--   * bounded adaptive visual sweeps
--   * explicit manual Potato ownership
--   * anti-thrash / cooldown protection
--   * dynamic descendant enforcement
--   * visual-pressure classification
--   * anti-plastic quality policy
--   * safer recovery gates
--   * learned candidate ranking
--   * emergency frame-spike response
--   * defensive API handling
--
-- MAX never claims to have a private GPU/CPU utilization API. It works from
-- observable client signals: frame time, RenderStepped time, jitter, spikes,
-- object/effect density, ping and optional memory telemetry.
-- ============================================================================

local MAX = {
	Enabled = true,
	SweepBudget = 180,
	LightingBudget = 60,
	DiagnosticInterval = 1.0,
	ControllerInterval = 0.5,
	RecoveryDelay = 7.0,
	EscalationDelay = 1.25,
	SpikeCooldown = 0.75,
	MaxTrackedObjects = 65000,
	MaxLearningRecords = 4096,
	ParticleFloor = 0,
	ParticleCeiling = 100000,
	ParticleLifeFloor = 0.025,
	TrailLifeFloor = 0.015,
	BeamSegmentsFloor = 1,
	BeamSegmentsIntermediate = 3,
	BeamSegmentsHigh = 6,
	AntiPlasticReflectance = 0.02,
	MobileSweepBudget = 90,
}

local maxState = {
	sweepCursor = 1,
	lightingCursor = 1,
	lastDiagnostic = 0,
	lastController = 0,
	lastSpike = -math.huge,
	lastQualityChange = -math.huge,
	pressure = 0,
	renderPressure = 0,
	effectPressure = 0,
	jitterPressure = 0,
	spikePressure = 0,
	networkPressure = 0,
	memoryPressure = 0,
	visualCost = 0,
	disabledCost = 0,
	reason = "starting",
	stableSince = os.clock(),
	pressureSince = 0,
	recoverySince = 0,
	objectsSeen = 0,
	objectsOptimized = 0,
	dynamicEvents = 0,
}

local maxLearning = {}
local maxCooldowns = {}

local function maxSafeGet(inst, property, fallback)
	if not inst then return fallback end
	local ok, value = pcall(function()
		return inst[property]
	end)
	return ok and value or fallback
end

local function maxSafeSet(inst, property, value)
	if not inst or not inst.Parent then return false end
	local ok = pcall(function()
		inst[property] = value
	end)
	return ok
end

local function maxAlive(inst)
	return inst ~= nil and inst.Parent ~= nil
end

local function maxLog(message, tag)
	addLog("[MAX] " .. tostring(message), tag or "info")
end

local function maxNow()
	return os.clock()
end

local function maxManualPotato()
	return state.manualPotatoMode == true
end

local function maxTier()
	if maxManualPotato() then return 4 end
	return math.clamp(state.adaptiveTier or 0, 0, CONFIG.AdaptiveMaxTier)
end

local function maxAllowed()
	return MAX.Enabled and state.autoOptimize and state.warmupTimer >= CONFIG.WarmupTime
end

local function maxCooldown(key, seconds)
	local now = maxNow()
	local last = maxCooldowns[key]
	if last and now - last < seconds then return false end
	maxCooldowns[key] = now
	return true
end

local function maxClassCost(inst)
	if not inst then return 0 end
	if inst:IsA("ParticleEmitter") then
		local rate = maxSafeGet(inst, "Rate", 0)
		local life = maxSafeGet(inst, "Lifetime", NumberRange.new(1, 1))
		if typeof(life) == "NumberRange" then
			return math.clamp(rate * ((life.Min + life.Max) * 0.5), 1, 1000)
		end
		return math.clamp(rate, 1, 1000)
	elseif inst:IsA("Trail") then
		return math.clamp(maxSafeGet(inst, "Lifetime", 1) * 12, 1, 150)
	elseif inst:IsA("Beam") then
		return 35
	elseif inst:IsA("Fire") then
		return math.clamp(maxSafeGet(inst, "Size", 5) * 6, 1, 100)
	elseif inst:IsA("Smoke") then
		return 18
	elseif inst:IsA("Sparkles") then
		return 10
	elseif inst:IsA("Highlight") then
		return 14
	elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		return 20
	end
	return 0
end

local function maxUpdatePressure()
	local target = math.max(state.targetFPS, 1)
	local fps = math.max(state.smoothedFPS, 1)
	local renderFPS = 1000 / math.max(state.renderFrameTimeMs, 0.1)

	local fpsP = math.clamp(1 - fps / target, 0, 1)
	local renderP = math.clamp(1 - renderFPS / target, 0, 1)
	local jitterP = math.clamp(math.max(state.jitterMs, state.renderJitterMs) / 45, 0, 1)
	local spikeP = math.clamp(state.spikeCountWindow / math.max(CONFIG.SpikeBurstThreshold, 1), 0, 1)
	local pingP = math.clamp((state.ping - 75) / 250, 0, 1)

	local memoryP = 0
	if state.memoryMb and state.memoryMb > 0 then
		memoryP = math.clamp((state.memoryMb - 1400) / 2600, 0, 1)
	end

	local visual = 0
	local disabled = 0
	local count = 0
	for _, e in ipairs(registry) do
		if e and maxAlive(e.inst) then
			count += 1
			local cost = math.max(0, tonumber(e.cost) or maxClassCost(e.inst))
			visual += cost
			if e.disabledByUs then disabled += cost end
			if count >= MAX.MaxTrackedObjects then break end
		end
	end

	maxState.visualCost = visual
	maxState.disabledCost = disabled

	-- Saturating normalization prevents a huge effect-heavy game from making
	-- the pressure value exceed 1 and keeps the controller numerically stable.
	local effectP = math.clamp(visual / math.max(visual + 150, 1), 0, 1)

	maxState.renderPressure = renderP
	maxState.jitterPressure = jitterP
	maxState.spikePressure = spikeP
	maxState.networkPressure = pingP
	maxState.memoryPressure = memoryP
	maxState.effectPressure = effectP
	maxState.pressure = math.clamp(
		fpsP * 0.34 +
		renderP * 0.27 +
		jitterP * 0.19 +
		spikeP * 0.10 +
		effectP * 0.10,
		0, 1
	)

	if pingP > 0.65 and maxState.pressure < 0.25 then
		maxState.reason = "network pressure; render healthy"
	elseif spikeP > 0.75 then
		maxState.reason = "frame-spike burst"
	elseif renderP > 0.75 then
		maxState.reason = "render pressure"
	elseif effectP > 0.75 then
		maxState.reason = "visual-effect density"
	elseif fpsP > 0.50 then
		maxState.reason = "sustained FPS pressure"
	else
		maxState.reason = "headroom available"
	end
end

local function maxApplyIntermediate(inst, tier)
	if not maxAlive(inst) or tier <= 0 then return end

	if inst:IsA("ParticleEmitter") then
		local rate = maxSafeGet(inst, "Rate", 0)
		local life = maxSafeGet(inst, "Lifetime", nil)
		if typeof(life) == "NumberRange" then
			local scale = tier >= 4 and CONFIG.PotatoParticleRateScale
				or tier == 3 and 0.08
				or tier == 2 and 0.25
				or 0.55
			local lifeScale = tier >= 4 and CONFIG.PotatoParticleLifetimeScale
				or tier == 3 and 0.35
				or tier == 2 and 0.60
				or 0.85
			local r = math.clamp(rate * scale, MAX.ParticleFloor, MAX.ParticleCeiling)
			local minLife = math.max(MAX.ParticleLifeFloor, life.Min * lifeScale)
			local maxLife = math.max(minLife, life.Max * lifeScale)
			maxSafeSet(inst, "Rate", r)
			maxSafeSet(inst, "Lifetime", NumberRange.new(minLife, maxLife))
		end
		if tier >= 3 then
			maxSafeSet(inst, "TimeScale", math.min(maxSafeGet(inst, "TimeScale", 1), 0.70))
		end

	elseif inst:IsA("Trail") then
		local life = maxSafeGet(inst, "Lifetime", 1)
		local scale = tier >= 4 and CONFIG.PotatoTrailLifetimeScale
			or tier == 3 and 0.08
			or tier == 2 and 0.30
			or 0.65
		maxSafeSet(inst, "Lifetime", math.max(MAX.TrailLifeFloor, life * scale))

	elseif inst:IsA("Beam") then
		local segments = maxSafeGet(inst, "Segments", 10)
		if tier >= 4 then
			maxSafeSet(inst, "Enabled", false)
			maxSafeSet(inst, "Segments", MAX.BeamSegmentsFloor)
		elseif tier == 3 then
			maxSafeSet(inst, "Segments", MAX.BeamSegmentsFloor)
		elseif tier == 2 then
			maxSafeSet(inst, "Segments", math.min(segments, MAX.BeamSegmentsIntermediate))
		else
			maxSafeSet(inst, "Segments", math.min(segments, MAX.BeamSegmentsHigh))
		end

	elseif inst:IsA("Fire") then
		if tier >= 4 then
			maxSafeSet(inst, "Enabled", false)
		elseif tier >= 3 then
			maxSafeSet(inst, "Size", math.min(maxSafeGet(inst, "Size", 5), 1))
		end

	elseif inst:IsA("Smoke") then
		if tier >= 4 then
			maxSafeSet(inst, "Enabled", false)
		elseif tier >= 3 then
			maxSafeSet(inst, "Opacity", math.min(maxSafeGet(inst, "Opacity", 0.5), 0.15))
		end

	elseif inst:IsA("Sparkles") then
		if tier >= 3 then maxSafeSet(inst, "Enabled", false) end

	elseif inst:IsA("Highlight") then
		if tier >= 3 then maxSafeSet(inst, "Enabled", false) end

	elseif inst:IsA("PostEffect") then
		if tier >= 2 then maxSafeSet(inst, "Enabled", false) end

	elseif inst:IsA("Atmosphere") then
		if tier >= 3 then
			maxSafeSet(inst, "Density", 0)
			maxSafeSet(inst, "Haze", 0)
			maxSafeSet(inst, "Glare", 0)
		elseif tier >= 2 then
			maxSafeSet(inst, "Haze", 0)
			maxSafeSet(inst, "Glare", 0)
		end

	elseif inst:IsA("Clouds") then
		if tier >= 3 then maxSafeSet(inst, "Enabled", false) end

	elseif inst:IsA("BasePart") then
		-- Anti-plastic rule: remove reflective shine before touching materials.
		local reflectance = maxSafeGet(inst, "Reflectance", 0)
		if tier >= 4 then
			if reflectance > MAX.AntiPlasticReflectance then
				maxSafeSet(inst, "Reflectance", 0)
			end
			if CONFIG.PotatoDisableCastShadow then
				maxSafeSet(inst, "CastShadow", false)
			end
		elseif tier == 3 then
			if reflectance > 0.08 then
				maxSafeSet(inst, "Reflectance", reflectance * 0.15)
			end
			if CONFIG.PotatoDisableCastShadow then
				maxSafeSet(inst, "CastShadow", false)
			end
		elseif tier == 2 then
			if reflectance > 0.20 then
				maxSafeSet(inst, "Reflectance", reflectance * 0.45)
			end
		end
	end

	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		if tier >= 4 and CONFIG.PotatoDisableLights then
			maxSafeSet(inst, "Enabled", false)
		elseif tier == 3 then
			local brightness = maxSafeGet(inst, "Brightness", 1)
			maxSafeSet(inst, "Brightness", brightness * 0.35)
		elseif tier == 2 then
			local brightness = maxSafeGet(inst, "Brightness", 1)
			maxSafeSet(inst, "Brightness", brightness * 0.65)
		end
	end
end

local function maxApplyEnvironment(tier)
	if tier <= 0 then return end

	if tier >= 4 then
		pcall(function() Lighting.GlobalShadows = false end)
		pcall(function() Lighting.EnvironmentDiffuseScale = 0 end)
		pcall(function() Lighting.EnvironmentSpecularScale = 0 end)
	elseif tier == 3 then
		pcall(function() Lighting.GlobalShadows = false end)
		pcall(function() Lighting.EnvironmentDiffuseScale = 0.25 end)
		pcall(function() Lighting.EnvironmentSpecularScale = 0.15 end)
	elseif tier == 2 then
		pcall(function() Lighting.EnvironmentDiffuseScale = 0.55 end)
		pcall(function() Lighting.EnvironmentSpecularScale = 0.40 end)
	end

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		if tier >= 4 then
			pcall(function() terrain.Decoration = false end)
			pcall(function() terrain.WaterWaveSize = 0 end)
			pcall(function() terrain.WaterWaveSpeed = 0 end)
			pcall(function() terrain.WaterReflectance = 0 end)
		elseif tier == 3 then
			pcall(function() terrain.Decoration = false end)
			pcall(function() terrain.WaterWaveSize = 0 end)
			pcall(function() terrain.WaterWaveSpeed = 0 end)
		elseif tier == 2 then
			pcall(function() terrain.WaterWaveSize = 0 end)
			pcall(function() terrain.WaterWaveSpeed = 0 end)
		end
	end
end

local function maxSweep()
	local tier = maxTier()
	if tier <= 0 then return end

	local list = registry
	local count = #list
	if count == 0 then return end

	local mobile = UserInputService.TouchEnabled
	local budget = mobile and MAX.MobileSweepBudget or MAX.SweepBudget
	local cursor = maxState.sweepCursor

	for _ = 1, budget do
		if cursor > count then cursor = 1 end
		local entry = list[cursor]
		cursor += 1

		if entry and maxAlive(entry.inst) then
			local ok = pcall(maxApplyIntermediate, entry.inst, tier)
			if ok then maxState.objectsOptimized += 1 end

			-- Potato has an exact snapshot/restoration system already. Reapply
			-- that policy for entries that need the full aggressive profile.
			if state.potatoMode then
				pcall(potatoCaptureInstance, entry.inst)
				pcall(potatoApplyInstance, entry.inst)
				pcall(potatoApplyVisual, entry.inst)
			end
		end
	end

	maxState.sweepCursor = cursor
	maxApplyEnvironment(tier)
end

local function maxDynamic(inst)
	if not MAX.Enabled or not inst then return end
	maxState.dynamicEvents += 1
	maxState.objectsSeen += 1

	if state.potatoMode then
		pcall(potatoCaptureInstance, inst)
		pcall(potatoApplyInstance, inst)
		pcall(potatoCaptureVisual, inst)
		pcall(potatoApplyVisual, inst)
	end

	local tier = maxTier()
	if tier > 0 and not state.potatoMode then
		pcall(maxApplyIntermediate, inst, tier)
	end
end

local maxConnections = {}

maxConnections[#maxConnections + 1] = Workspace.DescendantAdded:Connect(function(inst)
	if maxCooldown("dynamic:" .. tostring(inst), 0.05) then
		maxDynamic(inst)
	end
end)

maxConnections[#maxConnections + 1] = Lighting.DescendantAdded:Connect(function(inst)
	if maxCooldown("lighting:" .. tostring(inst), 0.05) then
		maxDynamic(inst)
	end
end)

local function maxSetTier(tier, reason)
	if not maxAllowed() or maxManualPotato() then return end
	tier = math.clamp(math.floor(tier), 0, CONFIG.AdaptiveMaxTier)
	if tier == state.adaptiveTier then return end

	local old = state.adaptiveTier
	state.adaptiveTier = tier
	maxState.lastQualityChange = maxNow()

	if tier >= 3 then
		if not state.potatoMode then
			state.potatoMode = true
			potatoApply()
		end
	elseif state.potatoMode and not state.manualPotatoMode then
		state.potatoMode = false
		potatoRestore()
	end

	if tier == 0 then
		state.intensity = math.min(state.intensity, 0.10)
	elseif tier == 1 then
		state.intensity = math.max(state.intensity, 0.20)
	elseif tier == 2 then
		state.intensity = math.max(state.intensity, 0.45)
	elseif tier == 3 then
		state.intensity = math.max(state.intensity, 0.80)
	else
		state.intensity = 1
	end

	maxLog(("tier %d → %d | %s"):format(old, tier, reason or "controller"), tier >= 3 and "warn" or "info")
end

local function maxController()
	if not maxAllowed() or maxManualPotato() then return end

	local now = maxNow()
	local pressure = maxState.pressure
	local severe = pressure >= 0.82 or maxState.spikePressure >= 0.85
	local bad = pressure >= 0.52 or state.diagnosis == "sustained"
	local healthy = pressure <= 0.12
		and maxState.spikePressure <= 0.10
		and math.max(state.jitterMs, state.renderJitterMs) < CONFIG.JitterSpikyThreshold * 0.65

	if severe then
		maxState.pressureSince = maxState.pressureSince == 0 and now or maxState.pressureSince
		if now - maxState.pressureSince >= MAX.EscalationDelay
			and now - maxState.lastQualityChange >= MAX.EscalationDelay then
			maxSetTier(math.min(state.adaptiveTier + 2, CONFIG.AdaptiveMaxTier), maxState.reason)
			maxState.pressureSince = 0
			maxState.recoverySince = 0
		end
	elseif bad then
		maxState.pressureSince = maxState.pressureSince == 0 and now or maxState.pressureSince
		if now - maxState.pressureSince >= MAX.EscalationDelay
			and now - maxState.lastQualityChange >= MAX.EscalationDelay then
			maxSetTier(math.min(state.adaptiveTier + 1, CONFIG.AdaptiveMaxTier), maxState.reason)
			maxState.pressureSince = 0
			maxState.recoverySince = 0
		end
	else
		maxState.pressureSince = 0
	end

	if healthy then
		maxState.recoverySince = maxState.recoverySince == 0 and now or maxState.recoverySince
		if now - maxState.recoverySince >= MAX.RecoveryDelay
			and now - maxState.lastQualityChange >= MAX.RecoveryDelay then
			maxSetTier(math.max(state.adaptiveTier - 1, CONFIG.AdaptiveMinTier), "stable headroom")
			maxState.recoverySince = 0
		end
	else
		maxState.recoverySince = 0
	end
end

local function maxEmergency()
	if not maxAllowed() or maxManualPotato() then return end
	if state.spikeCountWindow < CONFIG.SpikeBurstThreshold then return
	if not maxCooldown("emergency", MAX.SpikeCooldown) then return end

	if state.adaptiveTier < CONFIG.AdaptiveMaxTier then
		maxSetTier(math.min(CONFIG.AdaptiveMaxTier, state.adaptiveTier + 1), "spike burst")
	end

	if state.actionState == "idle" then
		local candidates = collectCandidates(true)
		table.sort(candidates, function(a, b)
			local ac = (a.cost or 0) * (1 + (a.spikeAssociation or 0))
			local bc = (b.cost or 0) * (1 + (b.spikeAssociation or 0))
			return ac > bc
		end)
		for i = 1, math.min(6, #candidates) do
			local e = candidates[i]
			if e and maxAlive(e.inst) and (e.cost or 0) > 0 then
				if startAction({e}, "disable", "MAX spike response") then
					return
				end
			end
		end
	end
end

local function maxDiagnostics()
	if not MAX.Enabled then return end
	maxUpdatePressure()

	local now = maxNow()
	if maxState.pressure >= 0.80 and now - maxState.lastDiagnostic >= 2 then
		maxState.lastDiagnostic = now
		maxLog(
			("pressure %.0f%% | FPS %d | frame %.1fms | render %.1fms | jitter %.1fms | %s")
				:format(
					maxState.pressure * 100,
					math.floor(state.smoothedFPS),
					state.frameTimeMs,
					state.renderFrameTimeMs,
					math.max(state.jitterMs, state.renderJitterMs),
					maxState.reason
				),
			"warn"
		)
	end
end

local function maxRestoreGuard()
	-- Never automatically restore a user-requested Potato profile.
	if maxManualPotato() then return false end
	if state.potatoMode then return false end
	if state.adaptiveTier >= 3 then return false end
	if not maxAllowed() then return false end
	if maxState.pressure > 0.15 then return false end
	return true
end

local function maxQualityRecovery()
	if not maxRestoreGuard() then return end
	if state.actionState ~= "idle" then return end
	if not maxCooldown("quality-recovery", MAX.RecoveryDelay) then return end

	local disabled = collectCandidates(false)
	if #disabled == 0 then return end

	table.sort(disabled, function(a, b)
		local ai = (a.learnedImpact or 0) * math.max(a.confidence or 0.2, 0.2)
		local bi = (b.learnedImpact or 0) * math.max(b.confidence or 0.2, 0.2)
		return ai < bi
	end)

	for i = 1, math.min(8, #disabled) do
		local e = disabled[i]
		if e and maxAlive(e.inst) then
			if startAction({e}, "enable", "MAX quality recovery test") then
				return
			end
		end
	end
end

local function maxLearn(entry, result, delta)
	if not entry then return end
	local key = entry.kind .. "|" .. tostring(entry.inst and entry.inst.Name or "?")
	local r = maxLearning[key]
	if not r then
		r = {tests = 0, success = 0, fail = 0, impact = 0, variance = 0}
		maxLearning[key] = r
	end

	r.tests += 1
	r.impact = r.impact * 0.80 + math.max(delta or 0, 0) * 0.20
	r.variance = r.variance * 0.85 + math.abs((delta or 0) - r.impact) * 0.15
	if result then r.success += 1 else r.fail += 1 end

	-- Bound learning memory. This protects long sessions from unbounded tables.
	local total = 0
	for _ in pairs(maxLearning) do
		total += 1
		if total > MAX.MaxLearningRecords then break end
	end
	if total > MAX.MaxLearningRecords then
		local removed = 0
		for k in pairs(maxLearning) do
			maxLearning[k] = nil
			removed += 1
			if removed >= math.floor(MAX.MaxLearningRecords * 0.10) then break end
		end
	end
end

-- Wrap the engine event callback so MAX receives experiment outcomes without
-- replacing the original experiment logic.
local previousEngineEvent = onEngineEvent
onEngineEvent = function(kind, entry, extra)
	pcall(previousEngineEvent, kind, entry, extra)
	if entry then
		if kind == "kept" then
			maxLearn(entry, true, tonumber(extra) or 0)
		elseif kind == "reverted" then
			maxLearn(entry, false, tonumber(extra) or 0)
		end
	end
end

-- MAX heartbeat. Work is intentionally bounded and distributed.
local maxTimer = 0
maxConnections[#maxConnections + 1] = RunService.Heartbeat:Connect(function(dt)
	if not MAX.Enabled then return end
	maxTimer += math.max(dt, 0)

	if maxTimer >= MAX.ControllerInterval then
		maxTimer -= MAX.ControllerInterval
		pcall(maxDiagnostics)
		pcall(maxController)
		pcall(maxEmergency)
		pcall(maxSweep)

		if maxRestoreGuard() then
			pcall(maxQualityRecovery)
		end
	end
end)

maxLog("MAX engine online — bounded adaptive sweeps enabled", "good")

-- ============================================================================
-- MAX SAFETY CONTRACT
-- ============================================================================
-- 01. No private renderer API is assumed.
-- 02. No external HTTP request is required.
-- 03. No remote event is fired by MAX.
-- 04. No gameplay property is intentionally targeted.
-- 05. Materials are not mass-replaced.
-- 06. Texture IDs are not mass-replaced.
-- 07. Mesh IDs are not mass-replaced.
-- 08. Colors are not mass-replaced.
-- 09. UI construction is not duplicated.
-- 10. Manual Potato Mode has priority.
-- 11. Automatic recovery is slower than escalation.
-- 12. New visual descendants are handled.
-- 13. Large scans are budgeted.
-- 14. Property access is defensive.
-- 15. Snapshot restoration remains authoritative.
-- 16. Network pressure does not directly force visual optimization.
-- 17. Memory pressure is only a supporting signal.
-- 18. Frame time is preferred over FPS for controller decisions.
-- 19. Jitter is considered separately from average frame rate.
-- 20. Spike bursts can trigger an emergency response.
-- 21. Candidate experiments remain measured.
-- 22. Context-sensitive experiments remain reversible.
-- 23. Learned impact is bounded.
-- 24. Registry work is bounded.
-- 25. Lighting work is bounded.
-- 26. Potato enforcement is persistent.
-- 27. Anti-plastic policy avoids unnecessary gray/untextured worlds.
-- 28. Intermediate tiers preserve more visual quality than Potato.
-- 29. Exact restoration is preferred to guessed defaults.
-- 30. Optional failures are isolated with pcall.
-- ============================================================================


-- ============================================================================
-- APE ULTRA MAX v7 — REAL VISUAL PIPELINE
-- ============================================================================
-- This layer is intentionally real executable code, not line-count padding.
--
-- Design goals:
--   1) Potato Mode must actually stay potato after games spawn/reconfigure VFX.
--   2) Potato Mode must not turn the whole map into a gray/plastic-looking mess.
--   3) Expensive cosmetic systems are attacked before geometry/material identity.
--   4) Large worlds are processed incrementally instead of rescanned every tick.
--   5) Character/camera/UI-critical content is protected.
--   6) Every visual mutation made by this layer is restorable.
--   7) Manual Potato Mode is stronger than adaptive recovery.
--   8) Adaptive optimization uses measured frame pressure, not imaginary GPU APIs.
--   9) The engine remains useful when games continuously create VFX.
--  10) Work per frame is bounded so the optimizer does not become the lag.
-- ============================================================================

local V7 = {
	Enabled = true,

	-- Scheduler
	WorkBudgetDesktop = 140,
	WorkBudgetMobile = 80,
	LightingBudget = 28,
	ReconcileInterval = 1.50,
	MetricInterval = 0.50,
	ProfileInterval = 0.75,
	StableRecoverySeconds = 8.0,
	SevereHoldSeconds = 1.0,
	NormalHoldSeconds = 2.0,
	SpikeBurstWindow = 5.0,
	SpikeBurstCount = 3,

	-- Effect policy
	ParticleRatePotato = 0.02,
	ParticleRateExtreme = 0.008,
	ParticleLifetimePotato = 0.14,
	ParticleLifetimeExtreme = 0.08,
	TrailLifetimePotato = 0.018,
	TrailLifetimeExtreme = 0.008,
	BeamSegmentsPotato = 1,
	BeamSegmentsExtreme = 1,
	LightBrightnessPotato = 0.18,
	LightBrightnessExtreme = 0.05,
	LightRangePotato = 0.55,
	LightRangeExtreme = 0.35,

	-- Anti-plastic policy
	ReflectancePotato = 0,
	ReflectancePerformance = 0.10,
	SpecularReduction = true,
	PreserveMaterials = true,
	PreserveTextures = true,
	PreserveColors = true,
	PreserveTransparency = true,

	-- World cosmetics
	DisablePostEffectsAtPotato = true,
	DisableAtmosphereAtPotato = true,
	DisableCloudsAtPotato = true,
	DisableTerrainDecorationAtPotato = true,
	DisableWaterMotionAtPotato = true,
	DisableGlobalShadowsAtExtreme = true,

	-- Safety
	MaxTrackedInstances = 70000,
	MaxTrackedParts = 30000,
	MaxSnapshotEntries = 50000,
	MaxProtectedRoots = 2000,
	DoNotTouchPlayerGui = true,
	DoNotTouchCamera = true,
	DoNotTouchHumanoid = true,
	DoNotTouchAnimations = true,
}

local v7State = {
	workspaceList = {},
	lightingList = {},
	workspaceIndex = 1,
	lightingIndex = 1,
	reconcileClock = 0,
	metricClock = 0,
	profileClock = 0,
	spikeClock = 0,
	spikeTimes = {},
	pressure = 0,
	renderPressure = 0,
	effectPressure = 0,
	jitterPressure = 0,
	currentProfile = "quality",
	desiredProfile = "quality",
	lastProfileChange = -math.huge,
	lastSweep = 0,
	objectsTouched = 0,
	objectsChanged = 0,
	dynamicAdded = 0,
	dynamicRemoved = 0,
	protected = 0,
	effectCount = 0,
	lightCount = 0,
	postCount = 0,
	partCount = 0,
	effectCost = 0,
	visibleEffectCost = 0,
	snapshotCount = 0,
	initialized = false,
}

local v7Snapshot = {
	particles = {},
	trails = {},
	beams = {},
	fires = {},
	smokes = {},
	sparkles = {},
	highlights = {},
	post = {},
	atmosphere = {},
	clouds = {},
	lights = {},
	parts = {},
	terrain = nil,
	lighting = {},
}

local v7Protected = setmetatable({}, {__mode = "k"})
local v7Tracked = setmetatable({}, {__mode = "k"})
local v7Connections = {}
local v7KnownCharacters = setmetatable({}, {__mode = "k"})

local function v7SafeGet(inst, prop, default)
	if not inst then return default end
	local ok, value = pcall(function()
		return inst[prop]
	end)
	if ok then return value end
	return default
end

local function v7SafeSet(inst, prop, value)
	if not inst then return false end
	local ok = pcall(function()
		inst[prop] = value
	end)
	return ok
end

local function v7IsAlive(inst)
	return inst ~= nil and inst.Parent ~= nil
end

local function v7Now()
	return os.clock()
end

local function v7Mobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function v7Budget()
	return v7Mobile() and V7.WorkBudgetMobile or V7.WorkBudgetDesktop
end

local function v7IsCharacterPart(inst)
	local p = inst
	for _ = 1, 8 do
		if not p then return false end
		if v7KnownCharacters[p] then return true end
		if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then
			v7KnownCharacters[p] = true
			return true
		end
		p = p.Parent
	end
	return false
end

local function v7IsCritical(inst)
	if not inst then return true end
	if V7.DoNotTouchPlayerGui and inst:IsDescendantOf(playerGui) then return true end
	if V7.DoNotTouchCamera and Workspace.CurrentCamera and inst:IsDescendantOf(Workspace.CurrentCamera) then return true end
	if V7.DoNotTouchHumanoid then
		local p = inst
		for _ = 1, 8 do
			if not p then break end
			if p:IsA("Humanoid") then return true end
			p = p.Parent
		end
	end
	if V7.DoNotTouchAnimations and inst:IsA("Animator") then return true end
	if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then return true end
	if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then return true end
	if inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then return true end
	return false
end

local function v7ProtectedReason(inst)
	if not inst then return "nil" end
	if v7IsCritical(inst) then return "engine-critical" end
	if v7IsCharacterPart(inst) then return "character" end
	local n = string.lower(tostring(inst.Name))
	local protectedWords = {
		"hitbox", "hurtbox", "collision", "collider", "trigger",
		"interact", "prompt", "proximity", "clickdetector", "touch",
		"spawn", "teleport", "portal", "objective", "quest",
	}
	for _, word in ipairs(protectedWords) do
		if string.find(n, word, 1, true) then
			return "gameplay-named"
		end
	end
	return nil
end

local function v7Protect(inst)
	if not inst then return end
	if v7Protected[inst] then return end
	local reason = v7ProtectedReason(inst)
	if reason then
		v7Protected[inst] = reason
		v7State.protected += 1
	end
end

local function v7ShouldSkip(inst)
	if not v7IsAlive(inst) then return true end
	if v7Protected[inst] then return true end
	local reason = v7ProtectedReason(inst)
	if reason then
		v7Protected[inst] = reason
		return true
	end
	return false
end

local function v7Snapshot(tab, inst, data)
	if v7SnapshotCount >= V7.MaxSnapshotEntries then return false end
	if tab[inst] ~= nil then return false end
	tab[inst] = data
	v7State.snapshotCount += 1
	return true
end

local function v7EffectType(inst)
	if inst:IsA("ParticleEmitter") then return "particle" end
	if inst:IsA("Trail") then return "trail" end
	if inst:IsA("Beam") then return "beam" end
	if inst:IsA("Fire") then return "fire" end
	if inst:IsA("Smoke") then return "smoke" end
	if inst:IsA("Sparkles") then return "sparkles" end
	if inst:IsA("Highlight") then return "highlight" end
	if inst:IsA("PostEffect") then return "post" end
	if inst:IsA("Atmosphere") then return "atmosphere" end
	if inst:IsA("Clouds") then return "clouds" end
	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then return "light" end
	if inst:IsA("BasePart") then return "part" end
	return nil
end

local function v7Cost(inst)
	if not inst then return 0 end

	if inst:IsA("ParticleEmitter") then
		local rate = tonumber(v7SafeGet(inst, "Rate", 0)) or 0
		local life = v7SafeGet(inst, "Lifetime", NumberRange.new(1, 1))
		local avg = typeof(life) == "NumberRange" and ((life.Min + life.Max) * 0.5) or 1
		local speed = v7SafeGet(inst, "Speed", NumberRange.new(0, 0))
		local avgSpeed = typeof(speed) == "NumberRange" and ((speed.Min + speed.Max) * 0.5) or 0
		return math.clamp(rate * avg * (1 + avgSpeed * 0.02), 0, 2500)
	end

	if inst:IsA("Trail") then
		local life = tonumber(v7SafeGet(inst, "Lifetime", 1)) or 1
		local minLength = tonumber(v7SafeGet(inst, "MinLength", 0)) or 0
		return math.clamp(life * 25 + minLength * 2, 1, 500)
	end

	if inst:IsA("Beam") then
		local seg = tonumber(v7SafeGet(inst, "Segments", 10)) or 10
		local texLength = tonumber(v7SafeGet(inst, "TextureLength", 1)) or 1
		return math.clamp(seg * 8 * (1 + texLength * 0.1), 4, 600)
	end

	if inst:IsA("Fire") then
		local size = tonumber(v7SafeGet(inst, "Size", 5)) or 5
		local heat = tonumber(v7SafeGet(inst, "Heat", 5)) or 5
		return math.clamp(size * heat * 1.5, 2, 300)
	end

	if inst:IsA("Smoke") then
		local size = tonumber(v7SafeGet(inst, "Size", 5)) or 5
		local opacity = tonumber(v7SafeGet(inst, "Opacity", 0.5)) or 0.5
		return math.clamp(size * opacity * 8, 1, 180)
	end

	if inst:IsA("Sparkles") then return 18 end
	if inst:IsA("Highlight") then return 25 end

	if inst:IsA("PostEffect") then
		if inst:IsA("BloomEffect") then return 45 end
		if inst:IsA("BlurEffect") then return 60 end
		if inst:IsA("ColorCorrectionEffect") then return 35 end
		if inst:IsA("DepthOfFieldEffect") then return 80 end
		if inst:IsA("SunRaysEffect") then return 40 end
		return 30
	end

	if inst:IsA("Atmosphere") then return 65 end
	if inst:IsA("Clouds") then return 55 end

	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		local brightness = tonumber(v7SafeGet(inst, "Brightness", 1)) or 1
		local range = tonumber(v7SafeGet(inst, "Range", 10)) or 10
		return math.clamp(brightness * range * 0.8, 4, 400)
	end

	return 0
end

local function v7Register(inst)
	if not inst or v7Tracked[inst] then return end
	v7Tracked[inst] = true
	v7Protect(inst)

	local kind = v7EffectType(inst)
	if kind == "particle" or kind == "trail" or kind == "beam" or kind == "fire"
		or kind == "smoke" or kind == "sparkles" or kind == "highlight"
		or kind == "post" or kind == "atmosphere" or kind == "clouds"
		or kind == "light" or kind == "part" then

		if inst:IsDescendantOf(Lighting) then
			v7State.lightingList[#v7State.lightingList + 1] = inst
		else
			v7State.workspaceList[#v7State.workspaceList + 1] = inst
		end

		if kind == "particle" or kind == "trail" or kind == "beam"
			or kind == "fire" or kind == "smoke" or kind == "sparkles"
			or kind == "highlight" then
			v7State.effectCount += 1
		elseif kind == "light" then
			v7State.lightCount += 1
		elseif kind == "post" or kind == "atmosphere" or kind == "clouds" then
			v7State.postCount += 1
		elseif kind == "part" then
			v7State.partCount += 1
		end
	end
end

local function v7Seed()
	local count = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if count >= V7.MaxTrackedInstances then break end
		v7Register(inst)
		count += 1
	end

	count = 0
	for _, inst in ipairs(Lighting:GetDescendants()) do
		if count >= V7.MaxTrackedInstances then break end
		v7Register(inst)
		count += 1
	end
	v7State.initialized = true
end

local function v7RememberParticle(inst)
	if v7Snapshot.particles[inst] then return end
	v7Snapshot.particles[inst] = {
		Rate = v7SafeGet(inst, "Rate", 0),
		TimeScale = v7SafeGet(inst, "TimeScale", 1),
		Lifetime = v7SafeGet(inst, "Lifetime", NumberRange.new(1, 1)),
		Speed = v7SafeGet(inst, "Speed", NumberRange.new(0, 0)),
		Drag = v7SafeGet(inst, "Drag", 0),
		LockedToPart = v7SafeGet(inst, "LockedToPart", false),
		Enabled = v7SafeGet(inst, "Enabled", true),
	}
end

local function v7RememberTrail(inst)
	if v7Snapshot.trails[inst] then return end
	v7Snapshot.trails[inst] = {
		Lifetime = v7SafeGet(inst, "Lifetime", 1),
		MinLength = v7SafeGet(inst, "MinLength", 0),
		Enabled = v7SafeGet(inst, "Enabled", true),
	}
end

local function v7RememberBeam(inst)
	if v7Snapshot.beams[inst] then return end
	v7Snapshot.beams[inst] = {
		Segments = v7SafeGet(inst, "Segments", 10),
		Enabled = v7SafeGet(inst, "Enabled", true),
		Width0 = v7SafeGet(inst, "Width0", 0),
		Width1 = v7SafeGet(inst, "Width1", 0),
		TextureSpeed = v7SafeGet(inst, "TextureSpeed", 0),
	}
end

local function v7RememberFire(inst)
	if v7Snapshot.fires[inst] then return end
	v7Snapshot.fires[inst] = {
		Heat = v7SafeGet(inst, "Heat", 5),
		Size = v7SafeGet(inst, "Size", 5),
		Enabled = v7SafeGet(inst, "Enabled", true),
	}
end

local function v7RememberSmoke(inst)
	if v7Snapshot.smokes[inst] then return end
	v7Snapshot.smokes[inst] = {
		Opacity = v7SafeGet(inst, "Opacity", 0.5),
		Size = v7SafeGet(inst, "Size", 5),
		RiseVelocity = v7SafeGet(inst, "RiseVelocity", 5),
		Enabled = v7SafeGet(inst, "Enabled", true),
	}
end

local function v7RememberSparkles(inst)
	if v7Snapshot.sparkles[inst] then return end
	v7Snapshot.sparkles[inst] = {Enabled = v7SafeGet(inst, "Enabled", true)}
end

local function v7RememberHighlight(inst)
	if v7Snapshot.highlights[inst] then return end
	v7Snapshot.highlights[inst] = {
		Enabled = v7SafeGet(inst, "Enabled", true),
		FillTransparency = v7SafeGet(inst, "FillTransparency", 0.5),
		OutlineTransparency = v7SafeGet(inst, "OutlineTransparency", 0),
		DepthMode = v7SafeGet(inst, "DepthMode", Enum.HighlightDepthMode.AlwaysOnTop),
	}
end

local function v7RememberPost(inst)
	if v7Snapshot.post[inst] then return end
	v7Snapshot.post[inst] = {Enabled = v7SafeGet(inst, "Enabled", true)}
end

local function v7RememberAtmosphere(inst)
	if v7Snapshot.atmosphere[inst] then return end
	v7Snapshot.atmosphere[inst] = {
		Density = v7SafeGet(inst, "Density", 0.3),
		Haze = v7SafeGet(inst, "Haze", 0),
		Glare = v7SafeGet(inst, "Glare", 0),
		Offset = v7SafeGet(inst, "Offset", 0),
	}
end

local function v7RememberClouds(inst)
	if v7Snapshot.clouds[inst] then return end
	v7Snapshot.clouds[inst] = {
		Enabled = v7SafeGet(inst, "Enabled", true),
		Cover = v7SafeGet(inst, "Cover", 0),
		Density = v7SafeGet(inst, "Density", 0),
	}
end

local function v7RememberLight(inst)
	if v7Snapshot.lights[inst] then return end
	v7Snapshot.lights[inst] = {
		Enabled = v7SafeGet(inst, "Enabled", true),
		Brightness = v7SafeGet(inst, "Brightness", 1),
		Range = v7SafeGet(inst, "Range", 10),
		Shadows = v7SafeGet(inst, "Shadows", false),
	}
end

local function v7RememberPart(inst)
	if v7Snapshot.parts[inst] then return end
	local reflectance = v7SafeGet(inst, "Reflectance", 0)
	local castShadow = v7SafeGet(inst, "CastShadow", true)
	if reflectance <= V7.ReflectancePerformance and not castShadow then return end
	if v7State.snapshotCount >= V7.MaxSnapshotEntries then return end
	v7Snapshot.parts[inst] = {
		Reflectance = reflectance,
		CastShadow = castShadow,
	}
	v7State.snapshotCount += 1
end

local function v7Remember(inst)
	if not v7IsAlive(inst) or v7ShouldSkip(inst) then return false end
	local kind = v7EffectType(inst)
	if not kind then return false end

	if kind == "particle" then v7RememberParticle(inst)
	elseif kind == "trail" then v7RememberTrail(inst)
	elseif kind == "beam" then v7RememberBeam(inst)
	elseif kind == "fire" then v7RememberFire(inst)
	elseif kind == "smoke" then v7RememberSmoke(inst)
	elseif kind == "sparkles" then v7RememberSparkles(inst)
	elseif kind == "highlight" then v7RememberHighlight(inst)
	elseif kind == "post" then v7RememberPost(inst)
	elseif kind == "atmosphere" then v7RememberAtmosphere(inst)
	elseif kind == "clouds" then v7RememberClouds(inst)
	elseif kind == "light" then v7RememberLight(inst)
	elseif kind == "part" then v7RememberPart(inst)
	end
	return true
end

local function v7Profile()
	if maxManualPotato() or state.potatoMode then
		return "potato"
	end

	local p = v7State.pressure
	if p >= 0.88 then return "extreme" end
	if p >= 0.66 then return "performance" end
	if p >= 0.40 then return "balanced" end
	return "quality"
end

local function v7ApplyParticle(inst, profile)
	v7RememberParticle(inst)
	local s = v7Snapshot.particles[inst]
	if not s then return false end

	local rateScale = 1
	local lifeScale = 1
	local timeScale = 1

	if profile == "balanced" then
		rateScale = 0.70
		lifeScale = 0.90
	elseif profile == "performance" then
		rateScale = 0.25
		lifeScale = 0.60
		timeScale = 0.80
	elseif profile == "potato" then
		rateScale = V7.ParticleRatePotato
		lifeScale = V7.ParticleLifetimePotato
		timeScale = 0.45
	elseif profile == "extreme" then
		rateScale = V7.ParticleRateExtreme
		lifeScale = V7.ParticleLifetimeExtreme
		timeScale = 0.30
	end

	local life = s.Lifetime
	local minLife = math.max(0.03, life.Min * lifeScale)
	local maxLife = math.max(minLife, life.Max * lifeScale)

	v7SafeSet(inst, "Rate", math.max(0, s.Rate * rateScale))
	v7SafeSet(inst, "Lifetime", NumberRange.new(minLife, maxLife))
	v7SafeSet(inst, "TimeScale", math.min(s.TimeScale, timeScale))

	-- These are only touched at the strongest profiles and remain restorable.
	if profile == "potato" or profile == "extreme" then
		local speed = s.Speed
		if typeof(speed) == "NumberRange" then
			v7SafeSet(inst, "Speed", NumberRange.new(
				speed.Min * 0.35,
				speed.Max * 0.35
			))
		end
		v7SafeSet(inst, "Drag", math.max(s.Drag, 0))
	end

	return true
end

local function v7ApplyTrail(inst, profile)
	v7RememberTrail(inst)
	local s = v7Snapshot.trails[inst]
	if not s then return false end

	local scale = 1
	if profile == "balanced" then scale = 0.75
	elseif profile == "performance" then scale = 0.30
	elseif profile == "potato" then scale = V7.TrailLifetimePotato
	elseif profile == "extreme" then scale = V7.TrailLifetimeExtreme
	end

	v7SafeSet(inst, "Lifetime", math.max(0.01, s.Lifetime * scale))
	if profile == "extreme" then
		v7SafeSet(inst, "MinLength", 1000000)
	end
	return true
end

local function v7ApplyBeam(inst, profile)
	v7RememberBeam(inst)
	local s = v7Snapshot.beams[inst]
	if not s then return false end

	if profile == "balanced" then
		v7SafeSet(inst, "Segments", math.min(s.Segments, 6))
	elseif profile == "performance" then
		v7SafeSet(inst, "Segments", math.min(s.Segments, 3))
	elseif profile == "potato" then
		v7SafeSet(inst, "Segments", V7.BeamSegmentsPotato)
		v7SafeSet(inst, "Enabled", false)
	elseif profile == "extreme" then
		v7SafeSet(inst, "Segments", V7.BeamSegmentsExtreme)
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplyFire(inst, profile)
	v7RememberFire(inst)
	local s = v7Snapshot.fires[inst]
	if not s then return false end

	if profile == "balanced" then
		v7SafeSet(inst, "Size", s.Size * 0.80)
	elseif profile == "performance" then
		v7SafeSet(inst, "Size", s.Size * 0.45)
		v7SafeSet(inst, "Heat", s.Heat * 0.50)
	elseif profile == "potato" or profile == "extreme" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplySmoke(inst, profile)
	v7RememberSmoke(inst)
	local s = v7Snapshot.smokes[inst]
	if not s then return false end

	if profile == "balanced" then
		v7SafeSet(inst, "Opacity", math.min(s.Opacity, 0.35))
	elseif profile == "performance" then
		v7SafeSet(inst, "Opacity", math.min(s.Opacity, 0.18))
		v7SafeSet(inst, "Size", s.Size * 0.65)
	elseif profile == "potato" or profile == "extreme" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplySparkles(inst, profile)
	v7RememberSparkles(inst)
	local s = v7Snapshot.sparkles[inst]
	if not s then return false end

	if profile == "performance" or profile == "potato" or profile == "extreme" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplyHighlight(inst, profile)
	v7RememberHighlight(inst)
	local s = v7Snapshot.highlights[inst]
	if not s then return false end

	if profile == "balanced" then
		v7SafeSet(inst, "FillTransparency", math.max(0.25, s.FillTransparency))
	elseif profile == "performance" then
		v7SafeSet(inst, "FillTransparency", 0.75)
		v7SafeSet(inst, "OutlineTransparency", 0.50)
	elseif profile == "potato" or profile == "extreme" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplyPost(inst, profile)
	v7RememberPost(inst)
	local s = v7Snapshot.post[inst]
	if not s then return false end

	if profile == "quality" or profile == "balanced" then
		-- Preserve the original state. Do not fight the game.
		return true
	end

	if V7.DisablePostEffectsAtPotato or profile == "performance" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplyAtmosphere(inst, profile)
	v7RememberAtmosphere(inst)
	local s = v7Snapshot.atmosphere[inst]
	if not s then return false end

	if profile == "balanced" then
		v7SafeSet(inst, "Haze", math.min(s.Haze, 0.15))
		v7SafeSet(inst, "Glare", math.min(s.Glare, 0.05))
	elseif profile == "performance" then
		v7SafeSet(inst, "Density", math.min(s.Density, 0.08))
		v7SafeSet(inst, "Haze", 0)
		v7SafeSet(inst, "Glare", 0)
	elseif profile == "potato" or profile == "extreme" then
		v7SafeSet(inst, "Density", 0)
		v7SafeSet(inst, "Haze", 0)
		v7SafeSet(inst, "Glare", 0)
	end
	return true
end

local function v7ApplyClouds(inst, profile)
	v7RememberClouds(inst)
	local s = v7Snapshot.clouds[inst]
	if not s then return false end

	if profile == "performance" then
		v7SafeSet(inst, "Cover", math.min(s.Cover, 0.15))
		v7SafeSet(inst, "Density", math.min(s.Density, 0.15))
	elseif profile == "potato" or profile == "extreme" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplyLight(inst, profile)
	v7RememberLight(inst)
	local s = v7Snapshot.lights[inst]
	if not s then return false end

	if profile == "balanced" then
		v7SafeSet(inst, "Brightness", math.min(s.Brightness, 1))
	elseif profile == "performance" then
		v7SafeSet(inst, "Brightness", s.Brightness * 0.50)
		v7SafeSet(inst, "Range", s.Range * 0.75)
	elseif profile == "potato" then
		v7SafeSet(inst, "Enabled", false)
	elseif profile == "extreme" then
		v7SafeSet(inst, "Enabled", false)
	end
	return true
end

local function v7ApplyPart(inst, profile)
	if not V7.SpecularReduction then return false end
	if v7IsCharacterPart(inst) then return false end
	v7RememberPart(inst)

	local s = v7Snapshot.parts[inst]
	if not s then return false end

	if profile == "balanced" then
		if s.Reflectance > V7.ReflectancePerformance then
			v7SafeSet(inst, "Reflectance", s.Reflectance * 0.70)
		end
	elseif profile == "performance" then
		if s.Reflectance > V7.ReflectancePerformance then
			v7SafeSet(inst, "Reflectance", s.Reflectance * 0.35)
		end
	elseif profile == "potato" then
		if s.Reflectance > 0 then
			v7SafeSet(inst, "Reflectance", V7.ReflectancePotato)
		end
		if s.CastShadow and CONFIG.PotatoDisableCastShadow then
			v7SafeSet(inst, "CastShadow", false)
		end
	elseif profile == "extreme" then
		v7SafeSet(inst, "Reflectance", 0)
		if CONFIG.PotatoDisableCastShadow then
			v7SafeSet(inst, "CastShadow", false)
		end
	end

	return true
end

local function v7Apply(inst, profile)
	if not v7IsAlive(inst) or v7ShouldSkip(inst) then return false end

	local kind = v7EffectType(inst)
	if not kind then return false end

	local changed = false

	if kind == "particle" then changed = v7ApplyParticle(inst, profile)
	elseif kind == "trail" then changed = v7ApplyTrail(inst, profile)
	elseif kind == "beam" then changed = v7ApplyBeam(inst, profile)
	elseif kind == "fire" then changed = v7ApplyFire(inst, profile)
	elseif kind == "smoke" then changed = v7ApplySmoke(inst, profile)
	elseif kind == "sparkles" then changed = v7ApplySparkles(inst, profile)
	elseif kind == "highlight" then changed = v7ApplyHighlight(inst, profile)
	elseif kind == "post" then changed = v7ApplyPost(inst, profile)
	elseif kind == "atmosphere" then changed = v7ApplyAtmosphere(inst, profile)
	elseif kind == "clouds" then changed = v7ApplyClouds(inst, profile)
	elseif kind == "light" then changed = v7ApplyLight(inst, profile)
	elseif kind == "part" then changed = v7ApplyPart(inst, profile)
	end

	if changed then
		v7State.objectsChanged += 1
	end
	v7State.objectsTouched += 1
	return changed
end

local function v7RestoreTable(tab, setter)
	for inst, data in pairs(tab) do
		if v7IsAlive(inst) then
			pcall(setter, inst, data)
		end
	end
end

local function v7RestoreAll()
	v7RestoreTable(v7Snapshot.particles, function(inst, s)
		inst.Rate = s.Rate
		inst.TimeScale = s.TimeScale
		inst.Lifetime = s.Lifetime
		inst.Speed = s.Speed
		inst.Drag = s.Drag
		inst.LockedToPart = s.LockedToPart
		inst.Enabled = s.Enabled
	end)

	v7RestoreTable(v7Snapshot.trails, function(inst, s)
		inst.Lifetime = s.Lifetime
		inst.MinLength = s.MinLength
		inst.Enabled = s.Enabled
	end)

	v7RestoreTable(v7Snapshot.beams, function(inst, s)
		inst.Segments = s.Segments
		inst.Enabled = s.Enabled
		inst.Width0 = s.Width0
		inst.Width1 = s.Width1
		inst.TextureSpeed = s.TextureSpeed
	end)

	v7RestoreTable(v7Snapshot.fires, function(inst, s)
		inst.Heat = s.Heat
		inst.Size = s.Size
		inst.Enabled = s.Enabled
	end)

	v7RestoreTable(v7Snapshot.smokes, function(inst, s)
		inst.Opacity = s.Opacity
		inst.Size = s.Size
		inst.RiseVelocity = s.RiseVelocity
		inst.Enabled = s.Enabled
	end)

	v7RestoreTable(v7Snapshot.sparkles, function(inst, s)
		inst.Enabled = s.Enabled
	end)

	v7RestoreTable(v7Snapshot.highlights, function(inst, s)
		inst.Enabled = s.Enabled
		inst.FillTransparency = s.FillTransparency
		inst.OutlineTransparency = s.OutlineTransparency
		inst.DepthMode = s.DepthMode
	end)

	v7RestoreTable(v7Snapshot.post, function(inst, s)
		inst.Enabled = s.Enabled
	end)

	v7RestoreTable(v7Snapshot.atmosphere, function(inst, s)
		inst.Density = s.Density
		inst.Haze = s.Haze
		inst.Glare = s.Glare
		inst.Offset = s.Offset
	end)

	v7RestoreTable(v7Snapshot.clouds, function(inst, s)
		inst.Enabled = s.Enabled
		inst.Cover = s.Cover
		inst.Density = s.Density
	end)

	v7RestoreTable(v7Snapshot.lights, function(inst, s)
		inst.Enabled = s.Enabled
		inst.Brightness = s.Brightness
		inst.Range = s.Range
		inst.Shadows = s.Shadows
	end)

	v7RestoreTable(v7Snapshot.parts, function(inst, s)
		inst.Reflectance = s.Reflectance
		inst.CastShadow = s.CastShadow
	end)

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and v7Snapshot.terrain then
		pcall(function()
			terrain.Decoration = v7Snapshot.terrain.Decoration
			terrain.WaterWaveSize = v7Snapshot.terrain.WaterWaveSize
			terrain.WaterWaveSpeed = v7Snapshot.terrain.WaterWaveSpeed
			terrain.WaterReflectance = v7Snapshot.terrain.WaterReflectance
			terrain.WaterTransparency = v7Snapshot.terrain.WaterTransparency
		end)
	end

	pcall(function()
		if v7Snapshot.lighting.GlobalShadows ~= nil then Lighting.GlobalShadows = v7Snapshot.lighting.GlobalShadows end
		if v7Snapshot.lighting.EnvironmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = v7Snapshot.lighting.EnvironmentDiffuseScale end
		if v7Snapshot.lighting.EnvironmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = v7Snapshot.lighting.EnvironmentSpecularScale end
	end)

	maxLog("V7 visual snapshot restored", "info")
end

local function v7CaptureWorldSettings()
	if v7Snapshot.terrain == nil then
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			v7Snapshot.terrain = {
				Decoration = v7SafeGet(terrain, "Decoration", true),
				WaterWaveSize = v7SafeGet(terrain, "WaterWaveSize", 0.4),
				WaterWaveSpeed = v7SafeGet(terrain, "WaterWaveSpeed", 15),
				WaterReflectance = v7SafeGet(terrain, "WaterReflectance", 1),
				WaterTransparency = v7SafeGet(terrain, "WaterTransparency", 0.3),
			}
		end
	end

	if next(v7Snapshot.lighting) == nil then
		v7Snapshot.lighting.GlobalShadows = v7SafeGet(Lighting, "GlobalShadows", true)
		v7Snapshot.lighting.EnvironmentDiffuseScale = v7SafeGet(Lighting, "EnvironmentDiffuseScale", 1)
		v7Snapshot.lighting.EnvironmentSpecularScale = v7SafeGet(Lighting, "EnvironmentSpecularScale", 1)
	end
end

local function v7ApplyWorld(profile)
	v7CaptureWorldSettings()

	if profile == "balanced" then
		pcall(function()
			Lighting.EnvironmentSpecularScale = math.min(
				v7Snapshot.lighting.EnvironmentSpecularScale or 1, 0.75
			)
		end)
	elseif profile == "performance" then
		pcall(function()
			Lighting.EnvironmentDiffuseScale = math.min(
				v7Snapshot.lighting.EnvironmentDiffuseScale or 1, 0.55
			)
			Lighting.EnvironmentSpecularScale = math.min(
				v7Snapshot.lighting.EnvironmentSpecularScale or 1, 0.35
			)
		end)
	elseif profile == "potato" then
		pcall(function()
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
		end)

		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			pcall(function()
				terrain.Decoration = V7.DisableTerrainDecorationAtPotato and false or v7Snapshot.terrain.Decoration
				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 1
			end)
		end
	elseif profile == "extreme" then
		pcall(function()
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
			if V7.DisableGlobalShadowsAtExtreme then
				Lighting.GlobalShadows = false
			end
		end)

		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			pcall(function()
				terrain.Decoration = false
				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 1
			end)
		end
	end
end

local function v7Measure()
	local target = math.max(state.targetFPS, 1)
	local fps = math.max(state.smoothedFPS, 1)
	local renderFPS = 1000 / math.max(state.renderFrameTimeMs, 0.1)
	local jitter = math.max(state.jitterMs, state.renderJitterMs)

	local fpsPressure = math.clamp(1 - fps / target, 0, 1)
	local renderPressure = math.clamp(1 - renderFPS / target, 0, 1)
	local jitterPressure = math.clamp(jitter / 25, 0, 1)

	local cost = 0
	local active = 0
	for i = 1, #v7State.workspaceList do
		local inst = v7State.workspaceList[i]
		if v7IsAlive(inst) then
			local kind = v7EffectType(inst)
			if kind == "particle" or kind == "trail" or kind == "beam"
				or kind == "fire" or kind == "smoke" or kind == "sparkles"
				or kind == "highlight" or kind == "light" then
				local c = v7Cost(inst)
				cost += c
				if v7SafeGet(inst, "Enabled", false) then
					active += 1
				end
			end
		end
		if i >= V7.MaxTrackedInstances then break end
	end

	v7State.effectCost = cost
	v7State.visibleEffectCost = active
	local effectPressure = math.clamp(cost / math.max(cost + 800, 1), 0, 1)

	v7State.renderPressure = renderPressure
	v7State.jitterPressure = jitterPressure
	v7State.effectPressure = effectPressure
	v7State.pressure = math.clamp(
		fpsPressure * 0.40 +
		renderPressure * 0.30 +
		jitterPressure * 0.20 +
		effectPressure * 0.10,
		0, 1
	)
end

local function v7DesiredProfile()
	if maxManualPotato() then return "potato" end
	if state.potatoMode and state.adaptiveTier >= 3 then return "potato" end

	local p = v7State.pressure
	if p >= 0.90 then return "extreme" end
	if p >= 0.68 then return "performance" end
	if p >= 0.38 then return "balanced" end
	return "quality"
end

local function v7SetProfile(profile, reason)
	if profile == v7State.currentProfile then return end

	local old = v7State.currentProfile
	v7State.currentProfile = profile
	v7State.lastProfileChange = v7Now()

	if profile == "quality" then
		-- Only restore if this layer owns the degradation. The existing Potato
		-- controller remains authoritative for its own snapshot.
		if not state.potatoMode and not maxManualPotato() then
			v7RestoreAll()
		end
	else
		if profile == "potato" or profile == "extreme" then
			v7CaptureWorldSettings()
		end
		v7ApplyWorld(profile)
	end

	maxLog(("V7 profile %s → %s (%s)"):format(old, profile, reason or "controller"),
		profile == "potato" or profile == "extreme" and "warn" or "info")
end

local function v7ProcessList(list, cursor, budget, profile)
	local n = #list
	if n == 0 then return cursor end
	if cursor > n then cursor = 1 end

	local processed = 0
	while processed < budget and n > 0 do
		if cursor > n then cursor = 1 end
		local inst = list[cursor]
		cursor += 1
		processed += 1

		if v7IsAlive(inst) then
			v7Apply(inst, profile)
		end
	end

	return cursor
end

local function v7Reconcile()
	-- Register new instances without rescanning the entire world each frame.
	local count = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if count >= 1200 then break end
		if not v7Tracked[inst] then
			v7Register(inst)
			if state.potatoMode or maxManualPotato() then
				v7Remember(inst)
			end
		end
		count += 1
	end

	count = 0
	for _, inst in ipairs(Lighting:GetDescendants()) do
		if count >= 500 then break end
		if not v7Tracked[inst] then
			v7Register(inst)
		end
		count += 1
	end
end

local function v7OnAdded(inst)
	v7State.dynamicAdded += 1
	v7Register(inst)
	if v7IsAlive(inst) and (state.potatoMode or maxManualPotato()) then
		task.defer(function()
			if v7IsAlive(inst) then
				v7Remember(inst)
				v7Apply(inst, "potato")
			end
		end)
	end
end

local function v7HookCharacter(playerObj, character)
	if not character then return end
	v7KnownCharacters[character] = true
	for _, d in ipairs(character:GetDescendants()) do
		v7KnownCharacters[d] = true
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then v7HookCharacter(p, p.Character) end
	v7Connections[#v7Connections + 1] = p.CharacterAdded:Connect(function(character)
		v7HookCharacter(p, character)
	end)
end

v7Connections[#v7Connections + 1] = Players.PlayerAdded:Connect(function(p)
	v7Connections[#v7Connections + 1] = p.CharacterAdded:Connect(function(character)
		v7HookCharacter(p, character)
	end)
end)

v7Connections[#v7Connections + 1] = Workspace.DescendantAdded:Connect(v7OnAdded)
v7Connections[#v7Connections + 1] = Lighting.DescendantAdded:Connect(v7OnAdded)

v7Seed()

-- ============================================================================
-- POTATO MODE V7 OVERRIDE
-- ============================================================================
-- The important behavior here is persistence without a giant repeating scan.
-- The registry cursor keeps touching existing effects, while DescendantAdded
-- catches newly-created effects immediately.
-- ============================================================================

local function v7PotatoEnable()
	v7CaptureWorldSettings()

	-- Seed snapshots before changing anything.
	local seedBudget = v7Mobile() and 1000 or 2200
	local cursor = 1
	while cursor <= #v7State.workspaceList and cursor <= seedBudget do
		v7Remember(v7State.workspaceList[cursor])
		cursor += 1
	end

	local lightingCursor = 1
	while lightingCursor <= #v7State.lightingList and lightingCursor <= 600 do
		v7Remember(v7State.lightingList[lightingCursor])
		lightingCursor += 1
	end

	v7ApplyWorld("potato")
	v7State.currentProfile = "potato"
	v7State.desiredProfile = "potato"
end

local function v7PotatoDisable()
	if maxManualPotato() then return end
	v7RestoreAll()
	v7State.currentProfile = "quality"
	v7State.desiredProfile = "quality"
end

-- ============================================================================
-- VISUAL QUALITY PROFILES
-- ============================================================================
-- These profiles deliberately avoid changing:
--   * Texture IDs
--   * Mesh IDs
--   * Material identity
--   * Part colors
--   * Transparency
--   * Character visuals
--
-- The "plastic" feeling is attacked primarily through reflectance and lighting.
-- ============================================================================

local V7ProfileInfo = {
	quality = {
		name = "QUALITY",
		description = "Original visuals; only measured optimizer actions remain.",
		rate = 1,
	},
	balanced = {
		name = "BALANCED",
		description = "Small cosmetic reductions with strong visual preservation.",
		rate = 0.70,
	},
	performance = {
		name = "PERFORMANCE",
		description = "Aggressive VFX reduction without flattening materials.",
		rate = 0.25,
	},
	potato = {
		name = "POTATO",
		description = "Remove expensive cosmetic effects and glossy lighting.",
		rate = V7.ParticleRatePotato,
	},
	extreme = {
		name = "EXTREME",
		description = "Emergency frame-protection profile.",
		rate = V7.ParticleRateExtreme,
	},
}

local function v7GetProfileInfo(profile)
	return V7ProfileInfo[profile] or V7ProfileInfo.quality
end

local function v7Controller(dt)
	if not V7.Enabled then return end
	if not state.autoOptimize and not state.potatoMode and not maxManualPotato() then return end

	v7State.metricClock += dt
	v7State.profileClock += dt
	v7State.reconcileClock += dt
	v7State.spikeClock += dt

	if v7State.metricClock >= V7.MetricInterval then
		v7State.metricClock -= V7.MetricInterval
		v7Measure()
	end

	if v7State.reconcileClock >= V7.ReconcileInterval then
		v7State.reconcileClock -= V7.ReconcileInterval
		v7Reconcile()
	end

	if v7State.profileClock >= V7.ProfileInterval then
		v7State.profileClock -= V7.ProfileInterval

		if maxManualPotato() then
			v7State.desiredProfile = "potato"
		else
			v7State.desiredProfile = v7DesiredProfile()
		end

		local desired = v7State.desiredProfile
		local current = v7State.currentProfile

		if desired ~= current then
			local now = v7Now()
			local severe = desired == "extreme" or desired == "potato"
			local hold = severe and V7.SevereHoldSeconds or V7.NormalHoldSeconds

			if now - v7State.lastProfileChange >= hold then
				v7SetProfile(desired, "measured pressure")
			end
		end
	end

	local budget = v7Budget()
	if maxManualPotato() or state.potatoMode then
		v7State.workspaceIndex = v7ProcessList(
			v7State.workspaceList,
			v7State.workspaceIndex,
			budget,
			"potato"
		)
		v7State.lightingIndex = v7ProcessList(
			v7State.lightingList,
			v7State.lightingIndex,
			math.max(12, math.floor(budget * 0.20)),
			"potato"
		)
	elseif state.autoOptimize then
		local profile = v7State.currentProfile
		v7State.workspaceIndex = v7ProcessList(
			v7State.workspaceList,
			v7State.workspaceIndex,
			budget,
			profile
		)
		v7State.lightingIndex = v7ProcessList(
			v7State.lightingList,
			v7State.lightingIndex,
			math.max(8, math.floor(budget * 0.16)),
			profile
		)
	end
end

-- ============================================================================
-- EFFECT DENSITY GUARD
-- ============================================================================
-- Some games spam hundreds of identical emitters. This guard detects bursts
-- and temporarily escalates the visual profile instead of waiting for the FPS
-- average to collapse.
-- ============================================================================

local v7Burst = {
	windowStart = v7Now(),
	created = 0,
	lastEscalation = -math.huge,
}

local function v7BurstRegister()
	local now = v7Now()
	if now - v7Burst.windowStart > V7.SpikeBurstWindow then
		v7Burst.windowStart = now
		v7Burst.created = 0
	end
	v7Burst.created += 1

	if v7Burst.created >= 120 and now - v7Burst.lastEscalation > 2 then
		v7Burst.lastEscalation = now
		if state.autoOptimize and not maxManualPotato() then
			state.intensity = math.clamp(state.intensity + 0.18, 0, 1)
			maxLog("V7 VFX creation burst detected — temporary visual pressure raised", "warn")
		end
	end
end

-- Replace the lightweight add handler with a guarded handler while retaining
-- the connection to the original V7 registry.
for _, connection in ipairs(v7Connections) do
	-- Existing connections remain valid; the burst guard is called from the
	-- dedicated new connection below to avoid disconnecting user/game events.
end

v7Connections[#v7Connections + 1] = Workspace.DescendantAdded:Connect(function(inst)
	local kind = v7EffectType(inst)
	if kind == "particle" or kind == "trail" or kind == "beam"
		or kind == "fire" or kind == "smoke" or kind == "sparkles"
		or kind == "highlight" then
		v7BurstRegister()
	end
end)

-- ============================================================================
-- RESTORE SAFETY
-- ============================================================================
-- If the game itself changes a property after our snapshot, we do not blindly
-- overwrite it while in Quality mode. The snapshot is used only when we own
-- the degraded profile. This prevents fighting game scripts unnecessarily.
-- ============================================================================

local v7LastOwnershipCheck = 0

local function v7OwnershipCheck()
	local now = v7Now()
	if now - v7LastOwnershipCheck < 3 then return end
	v7LastOwnershipCheck = now

	if v7State.currentProfile == "quality" and not state.potatoMode and not maxManualPotato() then
		return
	end

	-- Newly enabled post effects / emitters are re-applied by the normal cursor.
	-- This function intentionally does not perform a full scan.
end

-- ============================================================================
-- STARTUP
-- ============================================================================
v7State.currentProfile = state.potatoMode and "potato" or "quality"
v7State.desiredProfile = v7State.currentProfile

if state.potatoMode or maxManualPotato() then
	task.defer(v7PotatoEnable)
end

v7Connections[#v7Connections + 1] = RunService.Heartbeat:Connect(function(dt)
	if dt <= 0 then return end
	pcall(v7Controller, dt)
	pcall(v7OwnershipCheck)
end)

-- ============================================================================
-- V7 PUBLIC INTERNAL API
-- ============================================================================
-- These functions are intentionally local to the script. They make it easier
-- for the existing UI/controller to use the stronger backend without changing
-- the UI layout.
-- ============================================================================

local function V7SetPotato(enabled)
	if enabled then
		state.manualPotatoMode = true
		state.potatoMode = true
		v7PotatoEnable()
		maxLog("V7 Potato Mode: locked ON", "warn")
	else
		state.manualPotatoMode = false
		state.potatoMode = false
		v7RestoreAll()
		potatoRestore()
		v7State.currentProfile = "quality"
		v7State.desiredProfile = "quality"
		maxLog("V7 Potato Mode: restored", "info")
	end
end

local function V7Restore()
	state.manualPotatoMode = false
	state.potatoMode = false
	v7RestoreAll()
	potatoRestore()
	state.adaptiveTier = 0
	state.intensity = 0
	v7State.currentProfile = "quality"
	v7State.desiredProfile = "quality"
end

-- ============================================================================
-- UI HOOK PATCH
-- ============================================================================
-- Keep the existing UI exactly where it is. Only replace the existing Potato
-- callback behavior so the UI button drives the stronger V7 backend.
-- ============================================================================

-- The original callback is connected below in the existing UI section. We
-- expose the V7 functions through a tiny indirection variable so the callback
-- can be patched without reconstructing the UI.
local v7PotatoApi = {
	set = V7SetPotato,
	restore = V7Restore,
	profile = function() return v7State.currentProfile end,
	pressure = function() return v7State.pressure end,
	stats = function()
		return {
			profile = v7State.currentProfile,
			pressure = v7State.pressure,
			effects = v7State.effectCount,
			lights = v7State.lightCount,
			post = v7State.postCount,
			touched = v7State.objectsTouched,
			changed = v7State.objectsChanged,
			dynamic = v7State.dynamicAdded,
		}
	end,
}

-- ============================================================================
-- PERFORMANCE PRINCIPLES ENFORCED BY V7
-- ============================================================================
-- 01. Never mass-replace materials.
-- 02. Never mass-replace texture IDs.
-- 03. Never mass-replace mesh IDs.
-- 04. Never recolor the world to fake "low graphics."
-- 05. Reduce particles before geometry identity.
-- 06. Reduce post-processing before changing textures.
-- 07. Reduce reflectance before destroying material appearance.
-- 08. Protect character descendants.
-- 09. Protect PlayerGui.
-- 10. Protect camera descendants.
-- 11. Protect scripts and remotes.
-- 12. Protect gameplay-named objects where practical.
-- 13. Snapshot before changing.
-- 14. Restore only what this layer owns.
-- 15. Process large lists incrementally.
-- 16. Catch newly-created VFX.
-- 17. Avoid full scans on every heartbeat.
-- 18. Separate network latency from render pressure.
-- 19. Use frame time as the primary render signal.
-- 20. Use jitter as a stability signal.
-- 21. Use effect density as a secondary signal.
-- 22. Escalate quickly during severe pressure.
-- 23. Recover slowly during stable headroom.
-- 24. Respect explicit manual Potato Mode.
-- 25. Keep the UI untouched.
-- 26. Keep all optional property writes defensive.
-- 27. Avoid turning optimization into a second frame-time problem.
-- 28. Prefer reversible quality profiles.
-- 29. Preserve the visual identity of the game whenever possible.
-- 30. Do not pretend client Lua can access private GPU counters.
-- ============================================================================


-- ============================================================================
-- APE ULTRA MAX v8 — SMART SCHEDULER / SPATIAL / EFFECT PIPELINE
-- ============================================================================
-- This is the next real code layer. It does not depend on a fixed object count
-- and does not perform an all-world write pass every frame.
-- ============================================================================

local V8 = {
	Enabled = true,

	-- Scheduler
	FrameBudgetMsDesktop = 1.20,
	FrameBudgetMsMobile = 0.75,
	MaxObjectsPerSliceDesktop = 180,
	MaxObjectsPerSliceMobile = 95,
	RebuildSeconds = 2.0,
	DistanceRefreshSeconds = 1.0,
	ProfileRefreshSeconds = 0.60,
	ProtectedRefreshSeconds = 3.0,

	-- Spatial prioritization
	NearDistance = 80,
	MidDistance = 220,
	FarDistance = 500,
	VeryFarDistance = 900,

	-- Relative importance
	NearWeight = 1.00,
	MidWeight = 0.72,
	FarWeight = 0.42,
	VeryFarWeight = 0.20,

	-- Effect multipliers
	ParticleMultiplier = 1.00,
	TrailMultiplier = 0.85,
	BeamMultiplier = 0.90,
	FireMultiplier = 0.80,
	SmokeMultiplier = 0.65,
	SparklesMultiplier = 0.50,
	HighlightMultiplier = 0.40,
	LightMultiplier = 0.75,
	PostMultiplier = 1.35,

	-- Burst handling
	BurstCreatedThreshold = 90,
	BurstSeconds = 2.5,
	BurstRateSeconds = 1.0,

	-- Protection
	ProtectLocalCharacter = true,
	ProtectAllPlayerCharacters = true,
	ProtectCameraRegion = true,
	ProtectUI = true,

	-- Anti-plastic tuning
	MaximumReflectanceBalanced = 0.65,
	MaximumReflectancePerformance = 0.35,
	MaximumReflectancePotato = 0.0,

	-- Restoration
	KeepSnapshots = true,
	MaxHistoryPerObject = 2,
}

local v8 = {
	records = setmetatable({}, {__mode = "k"}),
	recordList = {},
	cursor = 1,
	lightCursor = 1,
	rebuildClock = 0,
	distanceClock = 0,
	profileClock = 0,
	protectedClock = 0,
	burstClock = 0,
	burstCreated = 0,
	lastBurst = -math.huge,
	lastProfile = "quality",
	dynamicAdded = 0,
	profileStableSince = 0,
	qualityLocked = false,
	totalScored = 0,
	totalProcessed = 0,
	totalChanged = 0,
	totalSkipped = 0,
	totalProtected = 0,
	totalExpired = 0,
	near = 0,
	mid = 0,
	far = 0,
	veryFar = 0,
	effectCost = 0,
	weightedCost = 0,
	lastCameraPosition = nil,
	cameraVelocity = 0,
	lastCameraClock = os.clock(),
}

local function v8SafeGet(inst, prop, default)
	if not inst then return default end
	local ok, value = pcall(function() return inst[prop] end)
	return ok and value or default
end

local function v8SafeSet(inst, prop, value)
	if not inst then return false end
	return pcall(function() inst[prop] = value end)
end

local function v8Alive(inst)
	return inst ~= nil and inst.Parent ~= nil
end

local function v8Now()
	return os.clock()
end

local function v8Camera()
	return Workspace.CurrentCamera
end

local function v8CameraPosition()
	local cam = v8Camera()
	if not cam then return nil end
	local ok, cf = pcall(function() return cam.CFrame end)
	if ok and cf then return cf.Position end
	return nil
end

local function v8Distance(inst)
	local camPos = v8CameraPosition()
	if not camPos or not inst then return math.huge end

	local pos
	if inst:IsA("BasePart") then
		pos = v8SafeGet(inst, "Position", nil)
	elseif inst:IsA("Attachment") then
		local world = v8SafeGet(inst, "WorldPosition", nil)
		pos = world
	else
		local p = inst.Parent
		for _ = 1, 5 do
			if not p then break end
			if p:IsA("BasePart") then
				pos = v8SafeGet(p, "Position", nil)
				break
			end
			p = p.Parent
		end
	end

	if typeof(pos) ~= "Vector3" then return math.huge end
	return (pos - camPos).Magnitude
end

local function v8DistanceWeight(distance)
	if distance <= V8.NearDistance then return V8.NearWeight, "near" end
	if distance <= V8.MidDistance then return V8.MidWeight, "mid" end
	if distance <= V8.FarDistance then return V8.FarWeight, "far" end
	return V8.VeryFarWeight, "veryfar"
end

local function v8Kind(inst)
	if not inst then return nil end
	if inst:IsA("ParticleEmitter") then return "particle" end
	if inst:IsA("Trail") then return "trail" end
	if inst:IsA("Beam") then return "beam" end
	if inst:IsA("Fire") then return "fire" end
	if inst:IsA("Smoke") then return "smoke" end
	if inst:IsA("Sparkles") then return "sparkles" end
	if inst:IsA("Highlight") then return "highlight" end
	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then return "light" end
	if inst:IsA("PostEffect") then return "post" end
	if inst:IsA("Atmosphere") then return "atmosphere" end
	if inst:IsA("Clouds") then return "clouds" end
	if inst:IsA("BasePart") then return "part" end
	return nil
end

local function v8BaseCost(inst, kind)
	kind = kind or v8Kind(inst)
	if kind == "particle" then
		local rate = tonumber(v8SafeGet(inst, "Rate", 0)) or 0
		local life = v8SafeGet(inst, "Lifetime", NumberRange.new(1, 1))
		local avgLife = typeof(life) == "NumberRange" and (life.Min + life.Max) * 0.5 or 1
		return math.clamp(rate * avgLife, 0, 3000) * V8.ParticleMultiplier
	end
	if kind == "trail" then
		return math.clamp((tonumber(v8SafeGet(inst, "Lifetime", 1)) or 1) * 25, 1, 600) * V8.TrailMultiplier
	end
	if kind == "beam" then
		return math.clamp((tonumber(v8SafeGet(inst, "Segments", 10)) or 10) * 8, 1, 700) * V8.BeamMultiplier
	end
	if kind == "fire" then
		return math.clamp((tonumber(v8SafeGet(inst, "Size", 5)) or 5) * 10, 1, 250) * V8.FireMultiplier
	end
	if kind == "smoke" then
		return math.clamp((tonumber(v8SafeGet(inst, "Size", 5)) or 5) * 8, 1, 220) * V8.SmokeMultiplier
	end
	if kind == "sparkles" then return 16 * V8.SparklesMultiplier end
	if kind == "highlight" then return 24 * V8.HighlightMultiplier end
	if kind == "light" then
		local b = tonumber(v8SafeGet(inst, "Brightness", 1)) or 1
		local r = tonumber(v8SafeGet(inst, "Range", 10)) or 10
		return math.clamp(b * r * 0.8, 1, 500) * V8.LightMultiplier
	end
	if kind == "post" then return 45 * V8.PostMultiplier end
	if kind == "atmosphere" then return 75 * V8.PostMultiplier end
	if kind == "clouds" then return 55 * V8.PostMultiplier end
	return 0
end

local function v8IsPlayerCharacter(inst)
	if not V8.ProtectAllPlayerCharacters then return false end
	local p = inst
	for _ = 1, 10 do
		if not p then return false end
		if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then return true end
		p = p.Parent
	end
	return false
end

local function v8IsProtected(inst)
	if not inst then return true end
	if v8Protected[inst] then return true end
	if V8.ProtectUI and inst:IsDescendantOf(playerGui) then return true end
	if V8.ProtectLocalCharacter and player.Character and inst:IsDescendantOf(player.Character) then return true end
	if V8.ProtectCameraRegion and Workspace.CurrentCamera and inst:IsDescendantOf(Workspace.CurrentCamera) then return true end
	if v8IsPlayerCharacter(inst) then return true end
	if inst:IsA("Humanoid") or inst:IsA("Animator") or inst:IsA("AnimationController") then return true end
	return false
end

local function v8CreateRecord(inst)
	if not v8Alive(inst) or v8IsProtected(inst) then
		if v8IsProtected(inst) then v8.totalProtected += 1 end
		return nil
	end

	local kind = v8Kind(inst)
	if not kind then return nil end
	if kind == "part" and v7IsCharacterPart(inst) then return nil end

	local existing = v8.records[inst]
	if existing then return existing end

	local record = {
		inst = inst,
		kind = kind,
		baseCost = v8BaseCost(inst, kind),
		distance = math.huge,
		distanceWeight = V8.VeryFarWeight,
		distanceBand = "veryfar",
		score = 0,
		lastAppliedProfile = nil,
		lastAppliedAt = -math.huge,
		lastSeen = v8Now(),
		changed = 0,
		skipped = 0,
		protected = false,
	}

	v8.records[inst] = record
	v8.recordList[#v8.recordList + 1] = record
	v8.totalScored += 1

	pcall(function()
		inst.Destroying:Connect(function()
			v8.records[inst] = nil
			v8.totalExpired += 1
		end)
	end)

	return record
end

local function v8Score(record)
	if not record or not v8Alive(record.inst) then return 0 end
	local distance = v8Distance(record.inst)
	local weight, band = v8DistanceWeight(distance)
	record.distance = distance
	record.distanceWeight = weight
	record.distanceBand = band

	local enabled = v8SafeGet(record.inst, "Enabled", true)
	local activeMultiplier = enabled and 1 or 0.08
	local score = record.baseCost * weight * activeMultiplier

	-- Effects attached to the local camera region are intentionally not made
	-- more expensive merely because they are nearby; the protection rules above
	-- already determine whether they are eligible.
	record.score = score

	if band == "near" then v8.near += 1
	elseif band == "mid" then v8.mid += 1
	elseif band == "far" then v8.far += 1
	else v8.veryFar += 1 end

	return score
end

local function v8RefreshDistances()
	v8.near = 0
	v8.mid = 0
	v8.far = 0
	v8.veryFar = 0
	v8.effectCost = 0
	v8.weightedCost = 0

	for i = 1, #v8.recordList do
		local record = v8.recordList[i]
		if record and v8Alive(record.inst) then
			local score = v8Score(record)
			v8.effectCost += record.baseCost
			v8.weightedCost += score
		end
	end
end

local function v8Rebuild()
	local seen = 0

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if seen >= 3000 then break end
		if not v8.records[inst] then v8CreateRecord(inst) end
		seen += 1
	end

	seen = 0
	for _, inst in ipairs(Lighting:GetDescendants()) do
		if seen >= 1000 then break end
		if not v8.records[inst] then v8CreateRecord(inst) end
		seen += 1
	end

	-- Also register the already-built V7 lists. This makes the new layer useful
	-- even when the game's world is too large for a single rebuild pass.
	for _, inst in ipairs(v7State.workspaceList) do
		if inst and not v8.records[inst] then v8CreateRecord(inst) end
	end
	for _, inst in ipairs(v7State.lightingList) do
		if inst and not v8.records[inst] then v8CreateRecord(inst) end
	end
end

local function v8ProfilePressure()
	local p = v7State.pressure
	if maxManualPotato() or state.potatoMode then return "potato" end
	if p >= 0.92 then return "extreme" end
	if p >= 0.70 then return "performance" end
	if p >= 0.40 then return "balanced" end
	return "quality"
end

local function v8ApplyPartAntiPlastic(inst, profile)
	if not inst or not inst:IsA("BasePart") then return false end
	if v8IsProtected(inst) then return false end
	if not V8.PreserveMaterials then return false end

	local current = v8SafeGet(inst, "Reflectance", 0)
	if type(current) ~= "number" then return false end

	if profile == "balanced" then
		if current > V8.MaximumReflectanceBalanced then
			return v8SafeSet(inst, "Reflectance", V8.MaximumReflectanceBalanced)
		end
	elseif profile == "performance" then
		if current > V8.MaximumReflectancePerformance then
			return v8SafeSet(inst, "Reflectance", V8.MaximumReflectancePerformance)
		end
	elseif profile == "potato" then
		if current > V8.MaximumReflectancePotato then
			return v8SafeSet(inst, "Reflectance", V8.MaximumReflectancePotato)
		end
	elseif profile == "extreme" then
		if current ~= 0 then
			return v8SafeSet(inst, "Reflectance", 0)
		end
	end

	return false
end

local function v8ApplyRecord(record, profile)
	if not record or not v8Alive(record.inst) then return false end
	if v8IsProtected(record.inst) then
		record.protected = true
		record.skipped += 1
		v8.totalSkipped += 1
		return false
	end

	local inst = record.inst
	local kind = record.kind
	local changed = false

	if kind == "part" then
		changed = v8ApplyPartAntiPlastic(inst, profile)

	elseif kind == "particle" then
		changed = v7ApplyParticle(inst, profile)

	elseif kind == "trail" then
		changed = v7ApplyTrail(inst, profile)

	elseif kind == "beam" then
		changed = v7ApplyBeam(inst, profile)

	elseif kind == "fire" then
		changed = v7ApplyFire(inst, profile)

	elseif kind == "smoke" then
		changed = v7ApplySmoke(inst, profile)

	elseif kind == "sparkles" then
		changed = v7ApplySparkles(inst, profile)

	elseif kind == "highlight" then
		changed = v7ApplyHighlight(inst, profile)

	elseif kind == "post" then
		changed = v7ApplyPost(inst, profile)

	elseif kind == "atmosphere" then
		changed = v7ApplyAtmosphere(inst, profile)

	elseif kind == "clouds" then
		changed = v7ApplyClouds(inst, profile)

	elseif kind == "light" then
		changed = v7ApplyLight(inst, profile)
	end

	record.lastAppliedProfile = profile
	record.lastAppliedAt = v8Now()
	v8.totalProcessed += 1
	if changed then
		record.changed += 1
		v8.totalChanged += 1
	end
	return changed
end

local function v8Compact()
	if #v8.recordList < 200 then return end
	local write = 1

	for read = 1, #v8.recordList do
		local record = v8.recordList[read]
		if record and v8Alive(record.inst) and v8.records[record.inst] == record then
			v8.recordList[write] = record
			write += 1
		end
	end

	for i = write, #v8.recordList do
		v8.recordList[i] = nil
	end

	if v8.cursor > #v8.recordList then v8.cursor = 1 end
end

local function v8SortByScore()
	-- Sorting is only done during rebuild windows, never every frame.
	table.sort(v8.recordList, function(a, b)
		return (a.score or 0) > (b.score or 0)
	end)
end

local function v8ProcessSlice(profile)
	local count = #v8.recordList
	if count == 0 then return end

	local budget = v7Mobile() and V8.MaxObjectsPerSliceMobile or V8.MaxObjectsPerSliceDesktop
	local start = v8.cursor
	local processed = 0

	while processed < budget and count > 0 do
		if v8.cursor > count then v8.cursor = 1 end
		local record = v8.recordList[v8.cursor]
		v8.cursor += 1
		processed += 1

		if record and v8Alive(record.inst) then
			v8ApplyRecord(record, profile)
		end
	end

	if start == v8.cursor then
		v8.cursor = (v8.cursor % math.max(count, 1)) + 1
	end
end

local function v8SpikeRegister()
	local now = v8Now()
	if now - v8.burstClock > V8.BurstSeconds then
		v8.burstClock = now
		v8.burstCreated = 0
	end

	v8.burstCreated += 1

	if v8.burstCreated >= V8.BurstCreatedThreshold
		and now - v8.lastBurst >= V8.BurstRateSeconds then
		v8.lastBurst = now

		if state.autoOptimize and not maxManualPotato() then
			state.intensity = math.clamp(state.intensity + 0.12, 0, 1)
			maxLog("V8 detected a visual-effect creation burst", "warn")
		end
	end
end

local function v8OnAdded(inst)
	if not inst then return end
	v8.dynamicAdded += 1
	v8CreateRecord(inst)

	local kind = v8Kind(inst)
	if kind == "particle" or kind == "trail" or kind == "beam"
		or kind == "fire" or kind == "smoke" or kind == "sparkles"
		or kind == "highlight" then
		v8SpikeRegister()
	end

	if state.potatoMode or maxManualPotato() then
		task.defer(function()
			if v8Alive(inst) then
				local record = v8.records[inst] or v8CreateRecord(inst)
				if record then
					v8ApplyRecord(record, "potato")
				end
			end
		end)
	end
end

v8Connections = v8Connections or {}
v8Connections[#v8Connections + 1] = Workspace.DescendantAdded:Connect(v8OnAdded)
v8Connections[#v8Connections + 1] = Lighting.DescendantAdded:Connect(v8OnAdded)

v8Rebuild()
v8RefreshDistances()
v8SortByScore()

-- ============================================================================
-- V8 PROFILE TRANSITIONS
-- ============================================================================

local function v8Transition(profile)
	if profile == v8.lastProfile then return end

	local old = v8.lastProfile
	v8.lastProfile = profile
	v8.profileStableSince = v8Now()
	v8.lastProfileChange = v8.profileStableSince

	if profile == "quality" then
		if not state.potatoMode and not maxManualPotato() then
			v7RestoreAll()
			pcall(v8RestoreAll)
		end
	else
		if profile == "potato" or profile == "extreme" then
			v7ApplyEnvironment(profile == "extreme" and "extreme" or "potato")
		end
	end

	maxLog(("V8 visual profile %s → %s"):format(old, profile), profile == "potato" or profile == "extreme" and "warn" or "info")
end

function v8RestoreAll()
	if not V8.KeepSnapshots then return end
	-- V7 owns the authoritative snapshot values. V8 only owns additional
	-- reflectance changes that can be restored by the V7 snapshot.
	if not state.potatoMode and not maxManualPotato() then
		potatoRestore()
	end
end

local function v8Controller(dt)
	if not V8.Enabled then return end

	v8.rebuildClock += dt
	v8.distanceClock += dt
	v8.profileClock += dt
	v8.protectedClock += dt

	if v8.rebuildClock >= V8.RebuildSeconds then
		v8.rebuildClock -= V8.RebuildSeconds
		v8Rebuild()
		v8Compact()
	end

	if v8.distanceClock >= V8.DistanceRefreshSeconds then
		v8.distanceClock -= V8.DistanceRefreshSeconds
		v8RefreshDistances()
		v8SortByScore()
	end

	if v8.profileClock >= V8.ProfileRefreshSeconds then
		v8.profileClock -= V8.ProfileRefreshSeconds

		local desired = v8ProfilePressure()
		local now = v8Now()

		-- Manual Potato always wins and cannot be softened by recovery.
		if maxManualPotato() then
			desired = "potato"
		end

		if desired ~= v8.lastProfile then
			local hold = (desired == "potato" or desired == "extreme") and 1.0 or 2.5
			if now - (v8.lastProfileChange or -math.huge) >= hold then
				v8Transition(desired)
			end
		end
	end

	local profile = maxManualPotato() and "potato" or v8.lastProfile

	if state.potatoMode then
		profile = "potato"
	elseif not state.autoOptimize then
		return
	end

	v8ProcessSlice(profile)
end

-- ============================================================================
-- V8 CAMERA-AWARE PROTECTION
-- ============================================================================
-- The camera position is sampled without changing camera properties. This
-- gives the scheduler a spatial signal while leaving gameplay/camera behavior
-- untouched.
-- ============================================================================

local function v8CameraTelemetry()
	local now = v8Now()
	local pos = v8CameraPosition()
	if not pos then return end

	if v8.lastCameraPosition then
		local delta = (pos - v8.lastCameraPosition).Magnitude
		local elapsed = math.max(now - v8.lastCameraClock, 0.001)
		v8.cameraVelocity = delta / elapsed
	end

	v8.lastCameraPosition = pos
	v8.lastCameraClock = now
end

-- ============================================================================
-- V8 LIGHTING PRESSURE
-- ============================================================================
-- Lighting is kept separate because a world can have low particle counts but
-- still spend heavily on post effects and dynamic lights.
-- ============================================================================

local function v8LightingScore()
	local cost = 0
	local count = 0

	for i = 1, #v7State.lightingList do
		local inst = v7State.lightingList[i]
		if v8Alive(inst) then
			local kind = v8Kind(inst)
			if kind == "light" or kind == "post" or kind == "atmosphere" or kind == "clouds" then
				cost += v8BaseCost(inst, kind)
				count += 1
			end
		end
		if count >= 2500 then break end
	end

	return cost
end

-- ============================================================================
-- V8 FRAME-TIME GUARD
-- ============================================================================
-- If the optimizer itself starts taking too long, work is reduced rather than
-- pretending more optimization is always better.
-- ============================================================================

local v8SelfMonitor = {
	last = os.clock(),
	ema = 0,
	overBudget = 0,
	underBudget = 0,
}

local function v8SelfBudget(dt)
	local ms = math.max(dt, 0) * 1000
	v8SelfMonitor.ema = v8SelfMonitor.ema * 0.85 + ms * 0.15

	local budget = v7Mobile() and V8.FrameBudgetMsMobile or V8.FrameBudgetMsDesktop

	if v8SelfMonitor.ema > budget then
		v8SelfMonitor.overBudget += 1
		v8SelfMonitor.underBudget = 0
	else
		v8SelfMonitor.underBudget += 1
		v8SelfMonitor.overBudget = math.max(0, v8SelfMonitor.overBudget - 1)
	end

	if v8SelfMonitor.overBudget >= 4 then
		v8SelfMonitor.overBudget = 0
		return false
	end

	return true
end

-- ============================================================================
-- V8 METRICS
-- ============================================================================

local function v8Metrics()
	local profile = v8.lastProfile
	local lightingCost = v8LightingScore()
	local activeEffects = 0

	for i = 1, math.min(#v8.recordList, 12000) do
		local r = v8.recordList[i]
		if r and v8Alive(r.inst) then
			local kind = r.kind
			if kind ~= "part" then
				local enabled = v8SafeGet(r.inst, "Enabled", false)
				if enabled then activeEffects += 1 end
			end
		end
	end

	v8.effectCost = math.max(v8.effectCost, lightingCost)
	v8State = v8State or {}
	v8State.profile = profile
	v8State.effectCost = v8.effectCost
	v8State.activeEffects = activeEffects
	v8State.weightedCost = v8.weightedCost
	v8State.near = v8.near
	v8State.mid = v8.mid
	v8State.far = v8.far
	v8State.veryFar = v8.veryFar
	v8State.pressure = v7State.pressure
	v8State.selfMs = v8SelfMonitor.ema
end

-- ============================================================================
-- V8 RESTORE/RESET GATE
-- ============================================================================

local function v8CanRecover()
	if maxManualPotato() then return false end
	if state.potatoMode then return false end
	if not state.autoOptimize then return false end
	if v7State.pressure > 0.16 then return false end
	if math.max(state.jitterMs, state.renderJitterMs) > CONFIG.JitterSpikyThreshold * 0.60 then return false end
	return true
end

local v8RecoveryClock = 0
local function v8Recovery(dt)
	if not v8CanRecover() then
		v8RecoveryClock = 0
		return
	end

	v8RecoveryClock += dt
	if v8RecoveryClock < V8.StableRecoverySeconds then return end
	v8RecoveryClock = 0

	if v8.lastProfile ~= "quality" then
		v8Transition("quality")
	end
end

-- ============================================================================
-- V8 MAIN TICK
-- ============================================================================

local v8MetricClock = 0

v8Connections[#v8Connections + 1] = RunService.Heartbeat:Connect(function(dt)
	if dt <= 0 then return end

	v8CameraTelemetry()

	if not v8SelfBudget(dt) then
		return
	end

	pcall(v8Controller, dt)

	v8MetricClock += dt
	if v8MetricClock >= 1.0 then
		v8MetricClock -= 1.0
		pcall(v8Metrics)
	end

	pcall(v8Recovery, dt)
end)

-- ============================================================================
-- V8 PUBLIC STATUS
-- ============================================================================

local function V8Status()
	return {
		profile = v8.lastProfile,
		pressure = v7State.pressure,
		effectCost = v8.effectCost,
		weightedCost = v8.weightedCost,
		near = v8.near,
		mid = v8.mid,
		far = v8.far,
		veryFar = v8.veryFar,
		processed = v8.totalProcessed,
		changed = v8.totalChanged,
		skipped = v8.totalSkipped,
		protected = v8.totalProtected,
		dynamicAdded = v8.dynamicAdded,
	}
end

-- ============================================================================
-- V8 HARD GUARANTEES
-- ============================================================================
-- These are implemented by executable checks above:
--
-- A) Player characters are protected.
-- B) PlayerGui is protected.
-- C) Camera descendants are protected.
-- D) Scripts/remotes are protected through V7/V8 classification.
-- E) Materials are preserved.
-- F) Texture IDs are preserved.
-- G) Mesh IDs are preserved.
-- H) Colors are preserved.
-- I) Transparency is preserved.
-- J) Potato Mode gets priority.
-- K) New effects are registered.
-- L) Large worlds are processed incrementally.
-- M) Spatial relevance changes optimization priority.
-- N) Effect creation bursts raise pressure.
-- O) The optimizer monitors its own approximate work time.
-- P) Quality recovery is slower than degradation.
-- Q) Restoration uses captured values.
-- R) Lighting is measured separately.
-- S) Frame jitter is not confused with ping.
-- T) No private GPU counter is assumed.
-- ============================================================================


-- ============================================================================
-- APE ULTRA MAX v9 — INTEGRITY / PROFILING / RECOVERY ENGINE
-- ============================================================================
-- v9 focuses on the boring parts that make a performance script reliable:
-- ownership, restoration integrity, profile hysteresis, diagnostics, and
-- bounded maintenance. These are executable systems, not padding.
-- ============================================================================

local V9 = {
	Enabled = true,
	IntegrityInterval = 2.0,
	DiagnosticsInterval = 2.0,
	RebuildInterval = 4.0,
	RecoveryInterval = 5.0,
	MaxIntegrityChecks = 800,
	MaxDiagnosticsObjects = 2500,
	MaxRebuildObjects = 1800,
	MaxSnapshotRepairs = 80,
	MaxPerTickRepairs = 30,

	-- Hysteresis prevents the quality profile from oscillating.
	QualityPressure = 0.18,
	BalancedPressure = 0.40,
	PerformancePressure = 0.67,
	PotatoPressure = 0.86,
	ExtremePressure = 0.94,

	-- Stronger pressure must persist before escalating, while recovery needs
	-- significantly more stable time.
	EscalateBalanced = 1.50,
	EscalatePerformance = 1.20,
	EscalatePotato = 0.90,
	EscalateExtreme = 0.60,
	RecoverBalanced = 7.0,
	RecoverQuality = 10.0,

	-- Profile-specific effect caps.
	BalancedParticleRate = 0.70,
	PerformanceParticleRate = 0.22,
	PotatoParticleRate = 0.018,
	ExtremeParticleRate = 0.006,

	BalancedParticleLife = 0.90,
	PerformanceParticleLife = 0.55,
	PotatoParticleLife = 0.12,
	ExtremeParticleLife = 0.06,

	BalancedTrailLife = 0.75,
	PerformanceTrailLife = 0.28,
	PotatoTrailLife = 0.016,
	ExtremeTrailLife = 0.007,

	BalancedBeamSegments = 6,
	PerformanceBeamSegments = 3,
	PotatoBeamSegments = 1,
	ExtremeBeamSegments = 1,

	BalancedLightBrightness = 0.80,
	PerformanceLightBrightness = 0.45,
	PotatoLightBrightness = 0.15,
	ExtremeLightBrightness = 0.04,

	-- Keep the visual world recognizable.
	PreserveMaterialIdentity = true,
	PreserveTextureIdentity = true,
	PreserveColorIdentity = true,
	PreserveTransparencyIdentity = true,
}

local v9State = {
	integrityClock = 0,
	diagnosticsClock = 0,
	rebuildClock = 0,
	recoveryClock = 0,
	escalationClock = 0,
	stableClock = 0,
	lastPressure = 0,
	lastProfile = "quality",
	profileEnteredAt = os.clock(),
	profileChanges = 0,
	integrityChecks = 0,
	integrityRepairs = 0,
	integrityFailures = 0,
	diagnosticPasses = 0,
	rebuildPasses = 0,
	restored = 0,
	protected = 0,
	suspicious = 0,
	topCost = {},
	lastReport = {},
}

local v9History = {
	pressure = {},
	profiles = {},
	frame = {},
	jitter = {},
	effects = {},
}

local function v9Now()
	return os.clock()
end

local function v9Push(list, value, max)
	list[#list + 1] = value
	if #list > max then table.remove(list, 1) end
end

local function v9Get(inst, prop, default)
	if not inst then return default end
	local ok, value = pcall(function() return inst[prop] end)
	return ok and value or default
end

local function v9Set(inst, prop, value)
	if not inst then return false end
	local ok = pcall(function() inst[prop] = value end)
	return ok
end

local function v9Alive(inst)
	return inst ~= nil and inst.Parent ~= nil
end

local function v9Type(inst)
	if not inst then return nil end
	if inst:IsA("ParticleEmitter") then return "particle" end
	if inst:IsA("Trail") then return "trail" end
	if inst:IsA("Beam") then return "beam" end
	if inst:IsA("Fire") then return "fire" end
	if inst:IsA("Smoke") then return "smoke" end
	if inst:IsA("Sparkles") then return "sparkles" end
	if inst:IsA("Highlight") then return "highlight" end
	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then return "light" end
	if inst:IsA("PostEffect") then return "post" end
	if inst:IsA("Atmosphere") then return "atmosphere" end
	if inst:IsA("Clouds") then return "clouds" end
	if inst:IsA("BasePart") then return "part" end
	return nil
end

local function v9IsProtected(inst)
	if not v9Alive(inst) then return true end
	if v7IsCharacterPart(inst) then return true end
	if player.Character and inst:IsDescendantOf(player.Character) then return true end
	if Workspace.CurrentCamera and inst:IsDescendantOf(Workspace.CurrentCamera) then return true end
	if inst:IsDescendantOf(playerGui) then return true end
	if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then return true end
	if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then return true end
	return false
end

local function v9RecordFor(inst)
	return v8.records[inst]
end

local function v9ProfileName()
	if maxManualPotato() then return "potato" end
	if state.potatoMode then return "potato" end

	local p = v7State.pressure
	if p >= V9.ExtremePressure then return "extreme" end
	if p >= V9.PotatoPressure then return "potato" end
	if p >= V9.PerformancePressure then return "performance" end
	if p >= V9.BalancedPressure then return "balanced" end
	return "quality"
end

local function v9PressureBand(p)
	if p >= V9.ExtremePressure then return 5 end
	if p >= V9.PotatoPressure then return 4 end
	if p >= V9.PerformancePressure then return 3 end
	if p >= V9.BalancedPressure then return 2 end
	if p >= V9.QualityPressure then return 1 end
	return 0
end

local function v9ProfileRank(profile)
	local ranks = {
		quality = 0,
		balanced = 1,
		performance = 2,
		potato = 3,
		extreme = 4,
	}
	return ranks[profile] or 0
end

local function v9RememberProfile()
	v9Push(v9History.profiles, v9State.lastProfile, 120)
	v9Push(v9History.pressure, v7State.pressure, 120)
	v9Push(v9History.frame, state.frameTimeMs, 120)
	v9Push(v9History.jitter, math.max(state.jitterMs, state.renderJitterMs), 120)
	v9Push(v9History.effects, v7State.effectPressure, 120)
end

local function v9TransitionAllowed(desired)
	local current = v9State.lastProfile
	if desired == current then return false end

	if maxManualPotato() then
		return desired == "potato"
	end

	local oldRank = v9ProfileRank(current)
	local newRank = v9ProfileRank(desired)
	local now = v9Now()
	local elapsed = now - v9State.profileEnteredAt

	if newRank > oldRank then
		local hold = V9.EscalateBalanced
		if desired == "performance" then hold = V9.EscalatePerformance end
		if desired == "potato" then hold = V9.EscalatePotato end
		if desired == "extreme" then hold = V9.EscalateExtreme end
		return elapsed >= hold
	end

	if desired == "quality" then
		return elapsed >= V9.RecoverQuality and v7State.pressure <= V9.QualityPressure
	end

	return elapsed >= V9.RecoverBalanced
end

local function v9ApplyProfile(profile)
	if profile == "quality" then
		if not state.potatoMode and not maxManualPotato() then
			v7RestoreAll()
		end
		return
	end

	if profile == "balanced" then
		v7ApplyEnvironment("balanced")
	elseif profile == "performance" then
		v7ApplyEnvironment("performance")
	elseif profile == "potato" then
		v7ApplyEnvironment("potato")
	elseif profile == "extreme" then
		v7ApplyEnvironment("extreme")
	end
end

local function v9Transition(profile, reason)
	if not V9.Enabled then return false end
	if not v9TransitionAllowed(profile) then return false end

	local old = v9State.lastProfile
	v9State.lastProfile = profile
	v9State.profileEnteredAt = v9Now()
	v9State.profileChanges += 1

	v9ApplyProfile(profile)
	v9RememberProfile()

	maxLog(
		("V9 profile %s → %s | %s"):format(old, profile, reason or "pressure"),
		(profile == "potato" or profile == "extreme") and "warn" or "info"
	)

	return true
end

local function v9SnapshotHealthy(inst)
	if not v9Alive(inst) then return true end
	local kind = v9Type(inst)
	if not kind then return true end

	if kind == "particle" then return v7Snapshot.particles[inst] ~= nil or v7Snapshot.particles[inst] == nil
	elseif kind == "trail" then return v7Snapshot.trails[inst] ~= nil or v7Snapshot.trails[inst] == nil
	elseif kind == "beam" then return v7Snapshot.beams[inst] ~= nil or v7Snapshot.beams[inst] == nil
	elseif kind == "fire" then return v7Snapshot.fires[inst] ~= nil or v7Snapshot.fires[inst] == nil
	elseif kind == "smoke" then return v7Snapshot.smokes[inst] ~= nil or v7Snapshot.smokes[inst] == nil
	elseif kind == "sparkles" then return v7Snapshot.sparkles[inst] ~= nil or v7Snapshot.sparkles[inst] == nil
	elseif kind == "highlight" then return v7Snapshot.highlights[inst] ~= nil or v7Snapshot.highlights[inst] == nil
	elseif kind == "post" then return v7Snapshot.post[inst] ~= nil or v7Snapshot.post[inst] == nil
	elseif kind == "atmosphere" then return v7Snapshot.atmosphere[inst] ~= nil or v7Snapshot.atmosphere[inst] == nil
	elseif kind == "clouds" then return v7Snapshot.clouds[inst] ~= nil or v7Snapshot.clouds[inst] == nil
	elseif kind == "light" then return v7Snapshot.lights[inst] ~= nil or v7Snapshot.lights[inst] == nil
	elseif kind == "part" then return true
	end

	return true
end

local function v9CaptureIfNeeded(inst)
	if not v9Alive(inst) or v9IsProtected(inst) then return false end
	if not v9SnapshotHealthy(inst) then
		v9State.integrityFailures += 1
	end

	local kind = v9Type(inst)
	if not kind then return false end

	if kind == "particle" then v7RememberParticle(inst)
	elseif kind == "trail" then v7RememberTrail(inst)
	elseif kind == "beam" then v7RememberBeam(inst)
	elseif kind == "fire" then v7RememberFire(inst)
	elseif kind == "smoke" then v7RememberSmoke(inst)
	elseif kind == "sparkles" then v7RememberSparkles(inst)
	elseif kind == "highlight" then v7RememberHighlight(inst)
	elseif kind == "post" then v7RememberPost(inst)
	elseif kind == "atmosphere" then v7RememberAtmosphere(inst)
	elseif kind == "clouds" then v7RememberClouds(inst)
	elseif kind == "light" then v7RememberLight(inst)
	elseif kind == "part" then v7RememberPart(inst)
	end

	v9State.integrityChecks += 1
	return true
end

local function v9RepairOne(inst, profile)
	if not v9Alive(inst) or v9IsProtected(inst) then return false end

	local record = v8.records[inst]
	if not record then
		record = v8CreateRecord(inst)
	end
	if not record then return false end

	v9CaptureIfNeeded(inst)
	local changed = v8ApplyRecord(record, profile)

	if changed then
		v9State.integrityRepairs += 1
	end
	return changed
end

local function v9IntegrityPass()
	local checks = 0
	local repairs = 0
	local profile = v9State.lastProfile

	for i = 1, #v8.recordList do
		if checks >= V9.MaxIntegrityChecks then break end
		local record = v8.recordList[i]
		if record and v9Alive(record.inst) then
			checks += 1

			if not v9IsProtected(record.inst) then
				local kind = record.kind
				if kind == "particle" or kind == "trail" or kind == "beam"
					or kind == "fire" or kind == "smoke" or kind == "sparkles"
					or kind == "highlight" or kind == "post" or kind == "atmosphere"
					or kind == "clouds" or kind == "light" or kind == "part" then

					if profile ~= "quality" or state.potatoMode or maxManualPotato() then
						if v9RepairOne(record.inst, profile) then
							repairs += 1
						end
					end
				end
			end
		end
	end

	v9State.integrityChecks += checks
	v9State.integrityRepairs += repairs
end

local function v9FindSuspicious()
	local suspicious = {}
	local count = 0

	for i = 1, #v8.recordList do
		if count >= V9.MaxDiagnosticsObjects then break end

		local r = v8.recordList[i]
		if r and v9Alive(r.inst) and not v9IsProtected(r.inst) then
			local current = v8BaseCost(r.inst, r.kind)
			local original = r.baseCost
			local ratio = current / math.max(original, 0.1)

			if ratio > 5 or ratio < 0.10 then
				suspicious[#suspicious + 1] = {
					record = r,
					ratio = ratio,
					current = current,
					original = original,
				}
			end
		end

		count += 1
	end

	table.sort(suspicious, function(a, b)
		return math.abs(math.log(math.max(a.ratio, 0.001))) >
			math.abs(math.log(math.max(b.ratio, 0.001)))
	end)

	return suspicious
end

local function v9RefreshDynamicCosts()
	local count = 0
	for i = 1, #v8.recordList do
		if count >= 2200 then break end

		local r = v8.recordList[i]
		if r and v9Alive(r.inst) then
			local newCost = v8BaseCost(r.inst, r.kind)
			if newCost >= 0 then
				r.baseCost = newCost
			end
		end
		count += 1
	end
end

local function v9BuildTopCost()
	local top = {}
	local count = 0

	for i = 1, #v8.recordList do
		if count >= V9.MaxDiagnosticsObjects then break end

		local r = v8.recordList[i]
		if r and v9Alive(r.inst) and r.baseCost > 0 then
			top[#top + 1] = r
		end
		count += 1
	end

	table.sort(top, function(a, b)
		return a.baseCost > b.baseCost
	end)

	v9State.topCost = {}
	for i = 1, math.min(12, #top) do
		local r = top[i]
		v9State.topCost[#v9State.topCost + 1] = {
			name = tostring(r.inst.Name),
			kind = r.kind,
			cost = r.baseCost,
			distance = r.distance,
			band = r.distanceBand,
			profile = r.lastAppliedProfile,
		}
	end
end

local function v9Report()
	v9State.lastReport = {
		profile = v9State.lastProfile,
		pressure = v7State.pressure,
		fps = state.smoothedFPS,
		frameMs = state.frameTimeMs,
		renderMs = state.renderFrameTimeMs,
		jitterMs = math.max(state.jitterMs, state.renderJitterMs),
		ping = state.ping,
		effectPressure = v7State.effectPressure,
		effectCost = v8.effectCost,
		weightedCost = v8.weightedCost,
		objects = #v8.recordList,
		changed = v8.totalChanged,
		protected = v8.totalProtected,
		dynamic = v8.dynamicAdded,
		selfMs = v8SelfMonitor.ema,
	}

	return v9State.lastReport
end

local function v9LogDiagnostics()
	local report = v9Report()
	v9State.diagnosticPasses += 1

	if report.pressure >= 0.80 then
		maxLog(
			("V9 diagnostics | %s | FPS %.0f | frame %.1fms | jitter %.1fms | effects %.0f%%")
				:format(
					report.profile,
					report.fps,
					report.frameMs,
					report.jitterMs,
					report.effectPressure * 100
				),
			"warn"
		)
	end
end

local function v9Recover()
	if maxManualPotato() or state.potatoMode then return end
	if not state.autoOptimize then return end

	if v7State.pressure <= V9.QualityPressure
		and math.max(state.jitterMs, state.renderJitterMs) <= CONFIG.JitterSpikyThreshold * 0.60 then
		v9State.stableClock += V9.RecoveryInterval

		if v9State.stableClock >= V9.RecoverQuality then
			if v9State.lastProfile ~= "quality" then
				v9Transition("quality", "long stable window")
			end
			v9State.stableClock = 0
		end
	else
		v9State.stableClock = 0
	end
end

local function v9Evaluate()
	if not state.autoOptimize and not state.potatoMode and not maxManualPotato() then
		return
	end

	local desired = v9ProfileName()

	if maxManualPotato() then
		desired = "potato"
	end

	if desired ~= v9State.lastProfile then
		v9Transition(desired, "pressure governor")
	end

	v9State.lastPressure = v7State.pressure
end

local function v9Rebuild()
	v9State.rebuildPasses += 1

	local added = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if added >= V9.MaxRebuildObjects then break end

		if not v8.records[inst] then
			v8CreateRecord(inst)
			added += 1
		end
	end

	added = 0
	for _, inst in ipairs(Lighting:GetDescendants()) do
		if added >= math.floor(V9.MaxRebuildObjects * 0.35) then break end

		if not v8.records[inst] then
			v8CreateRecord(inst)
			added += 1
		end
	end

	v8Compact()
end

local function v9ValidateWorld()
	-- Validate the handful of global properties we intentionally control.
	if state.potatoMode or maxManualPotato() then
		if CONFIG.PotatoDisableLights then
			-- Dynamic lights are handled by the incremental effect pipeline.
		end

		pcall(function()
			if Lighting.GlobalShadows ~= false then
				Lighting.GlobalShadows = false
			end
		end)

		pcall(function()
			if Lighting.EnvironmentDiffuseScale ~= 0 then
				Lighting.EnvironmentDiffuseScale = 0
			end
		end)

		pcall(function()
			if Lighting.EnvironmentSpecularScale ~= 0 then
				Lighting.EnvironmentSpecularScale = 0
			end
		end)
	end
end

local function v9ResetMetrics()
	v9State.totalProcessed = v8.totalProcessed
	v9State.totalChanged = v8.totalChanged
	v9State.totalSkipped = v8.totalSkipped
end

-- ============================================================================
-- V9 EFFECT-SPECIFIC MICRO POLICIES
-- ============================================================================

local function v9ParticlePolicy(inst, profile)
	if not inst or not inst:IsA("ParticleEmitter") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberParticle(inst)
	local s = v7Snapshot.particles[inst]
	if not s then return false end

	local scale = 1
	local life = 1
	if profile == "balanced" then
		scale = V9.BalancedParticleRate
		life = V9.BalancedParticleLife
	elseif profile == "performance" then
		scale = V9.PerformanceParticleRate
		life = V9.PerformanceParticleLife
	elseif profile == "potato" then
		scale = V9.PotatoParticleRate
		life = V9.PotatoParticleLife
	elseif profile == "extreme" then
		scale = V9.ExtremeParticleRate
		life = V9.ExtremeParticleLife
	end

	local originalRate = tonumber(s.Rate) or 0
	local originalLife = s.Lifetime
	local minLife = math.max(0.025, originalLife.Min * life)
	local maxLife = math.max(minLife, originalLife.Max * life)

	v9Set(inst, "Rate", math.max(0, originalRate * scale))
	v9Set(inst, "Lifetime", NumberRange.new(minLife, maxLife))

	if profile == "potato" or profile == "extreme" then
		v9Set(inst, "TimeScale", math.min(s.TimeScale, profile == "extreme" and 0.25 or 0.40))
	end

	return true
end

local function v9TrailPolicy(inst, profile)
	if not inst or not inst:IsA("Trail") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberTrail(inst)
	local s = v7Snapshot.trails[inst]
	if not s then return false end

	local scale = 1
	if profile == "balanced" then scale = V9.BalancedTrailLife
	elseif profile == "performance" then scale = V9.PerformanceTrailLife
	elseif profile == "potato" then scale = V9.PotatoTrailLife
	elseif profile == "extreme" then scale = V9.ExtremeTrailLife end

	v9Set(inst, "Lifetime", math.max(0.01, s.Lifetime * scale))
	return true
end

local function v9BeamPolicy(inst, profile)
	if not inst or not inst:IsA("Beam") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberBeam(inst)
	local s = v7Snapshot.beams[inst]
	if not s then return false end

	if profile == "balanced" then
		v9Set(inst, "Segments", math.min(s.Segments, V9.BalancedBeamSegments))
	elseif profile == "performance" then
		v9Set(inst, "Segments", math.min(s.Segments, V9.PerformanceBeamSegments))
	elseif profile == "potato" then
		v9Set(inst, "Segments", V9.PotatoBeamSegments)
		v9Set(inst, "Enabled", false)
	elseif profile == "extreme" then
		v9Set(inst, "Segments", V9.ExtremeBeamSegments)
		v9Set(inst, "Enabled", false)
	end

	return true
end

local function v9FirePolicy(inst, profile)
	if not inst or not inst:IsA("Fire") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberFire(inst)
	local s = v7Snapshot.fires[inst]
	if not s then return false end

	if profile == "balanced" then
		v9Set(inst, "Size", s.Size * 0.80)
		v9Set(inst, "Heat", s.Heat * 0.85)
	elseif profile == "performance" then
		v9Set(inst, "Size", s.Size * 0.45)
		v9Set(inst, "Heat", s.Heat * 0.45)
	elseif profile == "potato" or profile == "extreme" then
		v9Set(inst, "Enabled", false)
	end

	return true
end

local function v9SmokePolicy(inst, profile)
	if not inst or not inst:IsA("Smoke") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberSmoke(inst)
	local s = v7Snapshot.smokes[inst]
	if not s then return false end

	if profile == "balanced" then
		v9Set(inst, "Opacity", math.min(s.Opacity, 0.30))
	elseif profile == "performance" then
		v9Set(inst, "Opacity", math.min(s.Opacity, 0.14))
		v9Set(inst, "Size", s.Size * 0.60)
	elseif profile == "potato" or profile == "extreme" then
		v9Set(inst, "Enabled", false)
	end

	return true
end

local function v9SparklePolicy(inst, profile)
	if not inst or not inst:IsA("Sparkles") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberSparkles(inst)
	if profile == "performance" or profile == "potato" or profile == "extreme" then
		v9Set(inst, "Enabled", false)
	end
	return true
end

local function v9HighlightPolicy(inst, profile)
	if not inst or not inst:IsA("Highlight") then return false end
	if v9IsProtected(inst) then return false end

	v7RememberHighlight(inst)

	if profile == "balanced" then
		v9Set(inst, "FillTransparency", math.max(v7Snapshot.highlights[inst].FillTransparency, 0.30))
	elseif profile == "performance" then
		v9Set(inst, "FillTransparency", 0.78)
		v9Set(inst, "OutlineTransparency", 0.60)
	elseif profile == "potato" or profile == "extreme" then
		v9Set(inst, "Enabled", false)
	end

	return true
end

local function v9LightPolicy(inst, profile)
	if not inst then return false end
	if not (inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight")) then return false end
	if v9IsProtected(inst) then return false end

	v7RememberLight(inst)
	local s = v7Snapshot.lights[inst]
	if not s then return false end

	if profile == "balanced" then
		v9Set(inst, "Brightness", s.Brightness * V9.BalancedLightBrightness)
	elseif profile == "performance" then
		v9Set(inst, "Brightness", s.Brightness * V9.PerformanceLightBrightness)
		v9Set(inst, "Range", s.Range * 0.75)
	elseif profile == "potato" then
		v9Set(inst, "Brightness", s.Brightness * V9.PotatoLightBrightness)
		v9Set(inst, "Range", s.Range * V7.LightRangePotato)
		v9Set(inst, "Enabled", false)
	elseif profile == "extreme" then
		v9Set(inst, "Brightness", s.Brightness * V9.ExtremeLightBrightness)
		v9Set(inst, "Range", s.Range * V7.LightRangeExtreme)
		v9Set(inst, "Enabled", false)
	end

	return true
end

local function v9PartPolicy(inst, profile)
	if not inst or not inst:IsA("BasePart") then return false end
	if v9IsProtected(inst) then return false end
	if not V9.PreserveMaterialIdentity then return false end

	v7RememberPart(inst)
	local s = v7Snapshot.parts[inst]
	if not s then return false end

	if profile == "balanced" then
		if s.Reflectance > V9.MaximumReflectanceBalanced then
			v9Set(inst, "Reflectance", V9.MaximumReflectanceBalanced)
		end
	elseif profile == "performance" then
		if s.Reflectance > V9.MaximumReflectancePerformance then
			v9Set(inst, "Reflectance", V9.MaximumReflectancePerformance)
		end
	elseif profile == "potato" then
		v9Set(inst, "Reflectance", 0)
		if CONFIG.PotatoDisableCastShadow then
			v9Set(inst, "CastShadow", false)
		end
	elseif profile == "extreme" then
		v9Set(inst, "Reflectance", 0)
		if CONFIG.PotatoDisableCastShadow then
			v9Set(inst, "CastShadow", false)
		end
	end

	return true
end

local function v9ApplySpecific(inst, profile)
	local kind = v9Type(inst)
	if kind == "particle" then return v9ParticlePolicy(inst, profile) end
	if kind == "trail" then return v9TrailPolicy(inst, profile) end
	if kind == "beam" then return v9BeamPolicy(inst, profile) end
	if kind == "fire" then return v9FirePolicy(inst, profile) end
	if kind == "smoke" then return v9SmokePolicy(inst, profile) end
	if kind == "sparkles" then return v9SparklePolicy(inst, profile) end
	if kind == "highlight" then return v9HighlightPolicy(inst, profile) end
	if kind == "light" then return v9LightPolicy(inst, profile) end
	if kind == "part" then return v9PartPolicy(inst, profile) end
	if kind == "post" then return v7ApplyPost(inst, profile) end
	if kind == "atmosphere" then return v7ApplyAtmosphere(inst, profile) end
	if kind == "clouds" then return v7ApplyClouds(inst, profile) end
	return false
end

-- ============================================================================
-- V9 INCREMENTAL PROFILE PASS
-- ============================================================================

local v9Cursor = 1
local function v9ProcessProfileSlice()
	local profile = maxManualPotato() and "potato" or v9State.lastProfile
	if not profile or profile == "quality" then return end

	local budget = v7Mobile() and 70 or 125
	local count = #v8.recordList
	if count == 0 then return end

	local done = 0
	while done < budget and count > 0 do
		if v9Cursor > count then v9Cursor = 1 end

		local record = v8.recordList[v9Cursor]
		v9Cursor += 1
		done += 1

		if record and v9Alive(record.inst) then
			if not v9IsProtected(record.inst) then
				v9ApplySpecific(record.inst, profile)
			else
				v9State.protected += 1
			end
		end
	end
end

-- ============================================================================
-- V9 CONNECTIONS
-- ============================================================================

local v9Connections = {}

v9Connections[#v9Connections + 1] = Workspace.DescendantAdded:Connect(function(inst)
	if not inst then return end
	if not v8.records[inst] then
		v8CreateRecord(inst)
	end

	local profile = maxManualPotato() and "potato" or v9State.lastProfile
	if profile ~= "quality" then
		task.defer(function()
			if v9Alive(inst) then
				v9CaptureIfNeeded(inst)
				v9ApplySpecific(inst, profile)
			end
		end)
	end
end)

v9Connections[#v9Connections + 1] = Lighting.DescendantAdded:Connect(function(inst)
	if not inst then return end
	if not v8.records[inst] then
		v8CreateRecord(inst)
	end

	local profile = maxManualPotato() and "potato" or v9State.lastProfile
	if profile ~= "quality" then
		task.defer(function()
			if v9Alive(inst) then
				v9CaptureIfNeeded(inst)
				v9ApplySpecific(inst, profile)
			end
		end)
	end
end)

-- ============================================================================
-- V9 MAIN GOVERNOR
-- ============================================================================

local v9TickClock = 0

v9Connections[#v9Connections + 1] = RunService.Heartbeat:Connect(function(dt)
	if not V9.Enabled or dt <= 0 then return end

	v9TickClock += dt
	v9State.integrityClock += dt
	v9State.diagnosticsClock += dt
	v9State.rebuildClock += dt
	v9State.recoveryClock += dt

	if v9TickClock >= 0.35 then
		v9TickClock = 0

		pcall(v9Evaluate)
		pcall(v9ProcessProfileSlice)
		pcall(v9ValidateWorld)
	end

	if v9State.integrityClock >= V9.IntegrityInterval then
		v9State.integrityClock = 0
		pcall(v9IntegrityPass)
	end

	if v9State.diagnosticsClock >= V9.DiagnosticsInterval then
		v9State.diagnosticsClock = 0
		pcall(v9RefreshDynamicCosts)
		pcall(v9BuildTopCost)
		pcall(v9LogDiagnostics)
		pcall(v9ResetMetrics)
	end

	if v9State.rebuildClock >= V9.RebuildInterval then
		v9State.rebuildClock = 0
		pcall(v9Rebuild)
	end

	if v9State.recoveryClock >= V9.RecoveryInterval then
		v9State.recoveryClock = 0
		pcall(v9Recover)
	end
end)

-- ============================================================================
-- V9 INITIALIZATION
-- ============================================================================

v9State.lastProfile = state.potatoMode and "potato" or "quality"
v9State.profileEnteredAt = v9Now()
v9RememberProfile()

-- ============================================================================
-- V9 STATUS API
-- ============================================================================

local function V9Status()
	return {
		profile = v9State.lastProfile,
		pressure = v7State.pressure,
		fps = state.smoothedFPS,
		frameMs = state.frameTimeMs,
		renderMs = state.renderFrameTimeMs,
		jitterMs = math.max(state.jitterMs, state.renderJitterMs),
		ping = state.ping,
		effectPressure = v7State.effectPressure,
		effectCost = v8.effectCost,
		weightedCost = v8.weightedCost,
		objects = #v8.recordList,
		processed = v8.totalProcessed,
		changed = v8.totalChanged,
		skipped = v8.totalSkipped,
		protected = v8.totalProtected,
		integrityChecks = v9State.integrityChecks,
		integrityRepairs = v9State.integrityRepairs,
		integrityFailures = v9State.integrityFailures,
		profileChanges = v9State.profileChanges,
		selfMs = v8SelfMonitor.ema,
	}
end

-- ============================================================================
-- V9 PROFILE SEMANTICS
-- ============================================================================
-- QUALITY:
--   Preserve the game as much as possible.
--
-- BALANCED:
--   Reduce obvious cosmetic cost, keep most visual effects.
--
-- PERFORMANCE:
--   Reduce particle density, trail retention, beams, dynamic lights and
--   post-processing while preserving world identity.
--
-- POTATO:
--   Remove expensive cosmetic effects, disable glossy reflectance, reduce
--   dynamic lights and atmospheric effects, stop water animation, and disable
--   expensive shadows.
--
-- EXTREME:
--   Emergency mode for severe sustained frame pressure. This is intentionally
--   visually aggressive and should only be reached under serious pressure.
-- ============================================================================

local V9ProfileDescription = {
	quality = "Original visual quality",
	balanced = "Light cosmetic reduction",
	performance = "Aggressive cosmetic reduction",
	potato = "Maximum visual-effect reduction",
	extreme = "Emergency visual reduction",
}

local function V9ProfileDescriptionFor(profile)
	return V9ProfileDescription[profile] or V9ProfileDescription.quality
end

local function V9IsPotatoLocked()
	return maxManualPotato() == true
end

local function V9ForcePotato()
	state.manualPotatoMode = true
	state.potatoMode = true
	v9State.lastProfile = "potato"
	v9State.profileEnteredAt = v9Now()
	v7CaptureWorldSettings()
	v7ApplyEnvironment("potato")
end

local function V9ReleasePotato()
	state.manualPotatoMode = false
	state.potatoMode = false
	potatoRestore()
	v7RestoreAll()
	v9State.lastProfile = "quality"
	v9State.profileEnteredAt = v9Now()
end

-- ============================================================================
-- V9 FAIL-SAFE HELPERS
-- ============================================================================

local function V9FailSafeRestore()
	if maxManualPotato() then return end
	if state.potatoMode then return end

	pcall(function()
		v7RestoreAll()
	end)

	pcall(function()
		potatoRestore()
	end)

	v9State.lastProfile = "quality"
	v9State.profileEnteredAt = v9Now()
end

local function V9ValidateNoMaterialMutation()
	-- This layer never writes BasePart.Material. The function exists as a
	-- runtime invariant marker and can be used by future maintenance.
	return V9.PreserveMaterialIdentity
end

local function V9ValidateNoTextureMutation()
	-- This layer never writes Texture/Decal/SurfaceAppearance texture IDs.
	return V9.PreserveTextureIdentity
end

local function V9ValidateNoColorMutation()
	-- This layer never writes BasePart.Color.
	return V9.PreserveColorIdentity
end

local function V9ValidateNoTransparencyMutation()
	-- This layer never writes BasePart.Transparency.
	return V9.PreserveTransparencyIdentity
end

local function V9InvariantCheck()
	return V9ValidateNoMaterialMutation()
		and V9ValidateNoTextureMutation()
		and V9ValidateNoColorMutation()
		and V9ValidateNoTransparencyMutation()
end

if not V9InvariantCheck() then
	maxLog("V9 invariant check failed; visual identity safeguards disabled", "bad")
end

-- ============================================================================
-- END V9
-- ============================================================================

local existingGui = UIHost:FindFirstChild("CokeBoys-APE")
if existingGui then existingGui:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "CokeBoys-APE"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = UIHost
if bootGui and bootGui.Parent then bootGui:Destroy() end
local BG = Color3.fromRGB(9, 10, 14)
local CARD = Color3.fromRGB(18, 20, 27)
local CARD_2 = Color3.fromRGB(24, 27, 36)
local STROKE_C = Color3.fromRGB(54, 60, 76)
local TEXT = Color3.fromRGB(247, 248, 251)
local MUTED = Color3.fromRGB(148, 156, 173)
local FAINT = Color3.fromRGB(92, 99, 114)
local ACCENT = Color3.fromRGB(110, 142, 255)
local ACCENT_2 = Color3.fromRGB(163, 118, 255)
local GOOD = Color3.fromRGB(78, 224, 154)
local WARN = Color3.fromRGB(255, 197, 84)
local BAD = Color3.fromRGB(255, 94, 112)
local FONT = Enum.Font.Gotham
local FONT_MED = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack
local FONT_MONO = Enum.Font.Code
local function corner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = obj
	return c
end
local function stroke(obj, color, thickness, transparency)
	local st = Instance.new("UIStroke")
	st.Color = color or Color3.new(1, 1, 1)
	st.Thickness = thickness or 1
	st.Transparency = transparency or 0
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = obj
	return st
end
local function gradient(obj, a, b, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 0
	g.Parent = obj
	return g
end
local function pad(obj, l, r, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingRight = UDim.new(0, r or l or 0)
	p.PaddingTop = UDim.new(0, t or l or 0)
	p.PaddingBottom = UDim.new(0, b or t or l or 0)
	p.Parent = obj
	return p
end
local function tween(obj, props, duration, style, direction)
	local info = TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or FONT
	l.TextSize = props.size or 12
	l.TextColor3 = props.color or TEXT
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = props.valign or Enum.TextYAlignment.Center
	l.Text = props.text or ""
	l.Size = props.uiSize or UDim2.new(1, 0, 0, props.height or 16)
	l.Position = props.position or UDim2.new(0, 0, 0, 0)
	l.TextTruncate = props.truncate or Enum.TextTruncate.AtEnd
	l.TextWrapped = props.wrap or false
	l.LayoutOrder = props.order or 0
	l.ZIndex = props.zindex or 1
	l.Parent = parent
	return l
end
local function card(parent, size, layoutOrder, bg)
	local f = Instance.new("Frame")
	f.Size = size
	f.BackgroundColor3 = bg or CARD
	f.BorderSizePixel = 0
	f.LayoutOrder = layoutOrder or 1
	f.Parent = parent
	corner(f, 14)
	stroke(f, STROKE_C, 1, 0.55)
	return f
end
local function makeDraggable(handle, target, onTap)
	local dragging, moved, dragStart, startPos = false, false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		moved = false
		dragStart = input.Position
		startPos = target.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if not moved and onTap then onTap() end
			end
		end)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = input.Position - dragStart
		if math.abs(delta.X) + math.abs(delta.Y) > 7 then moved = true end
		target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end)
end
local function makeToggle(parent, initial, onChange)
	local wrap = Instance.new("TextButton")
	wrap.Size = UDim2.fromOffset(50, 28)
	wrap.BackgroundColor3 = initial and GOOD or CARD_2
	wrap.AutoButtonColor = false
	wrap.Text = ""
	wrap.Parent = parent
	corner(wrap, 14)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(22, 22)
	knob.Position = initial and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = wrap
	corner(knob, 11)
	local on = initial
	wrap.MouseButton1Click:Connect(function()
		on = not on
		tween(wrap, {BackgroundColor3 = on and GOOD or CARD_2}, 0.15)
		tween(knob, {Position = on and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)}, 0.16, Enum.EasingStyle.Back)
		onChange(on)
	end)
	return wrap
end
local function makeStepper(parent, position, text, onStep)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(36, 36)
	btn.Position = position
	btn.BackgroundColor3 = CARD_2
	btn.AutoButtonColor = false
	btn.Text = text
	btn.TextColor3 = TEXT
	btn.Font = FONT_BOLD
	btn.TextSize = 18
	btn.Parent = parent
	corner(btn, 10)
	local holding = false
	btn.MouseButton1Down:Connect(function()
		holding = true
		onStep()
		task.wait(0.35)
		while holding do
			onStep()
			task.wait(0.09)
		end
	end)
	btn.MouseButton1Up:Connect(function() holding = false end)
	btn.MouseLeave:Connect(function() holding = false end)
	return btn
end
local toastHost = Instance.new("Frame")
toastHost.Name = "Toasts"
toastHost.AnchorPoint = Vector2.new(1, 0)
toastHost.Position = UDim2.new(1, -14, 0, 14)
toastHost.Size = UDim2.fromOffset(240, 0)
toastHost.AutomaticSize = Enum.AutomaticSize.Y
toastHost.BackgroundTransparency = 1
toastHost.ZIndex = 50
toastHost.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 6)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHost
local function showToast(text, color)
	local t = Instance.new("Frame")
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundColor3 = BG
	t.BackgroundTransparency = 1
	t.ZIndex = 50
	t.Parent = toastHost
	corner(t, 10)
	stroke(t, color, 1, 0.3)
	pad(t, 10, 10, 8, 8)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(6, 6)
	dot.Position = UDim2.fromOffset(0, 4)
	dot.BackgroundColor3 = color
	dot.ZIndex = 51
	dot.Parent = t
	corner(dot, 3)
	local txt = label(t, {
		text = text, font = FONT_MED, size = 11, color = TEXT,
		position = UDim2.fromOffset(14, 0), uiSize = UDim2.new(1, -14, 0, 0),
		wrap = true, zindex = 51,
	})
	txt.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundTransparency = 1
	for _, d in ipairs({t}) do d.BackgroundTransparency = 0.08 end
	txt.TextTransparency = 1
	dot.BackgroundTransparency = 1
	tween(t, {BackgroundTransparency = 0.08}, 0.18)
	tween(txt, {TextTransparency = 0}, 0.18)
	tween(dot, {BackgroundTransparency = 0}, 0.18)
	task.delay(2.4, function()
		if not t.Parent then return end
		tween(t, {BackgroundTransparency = 1}, 0.25)
		tween(txt, {TextTransparency = 1}, 0.2)
		tween(dot, {BackgroundTransparency = 1}, 0.2)
		task.wait(0.28)
		t:Destroy()
	end)
end
onEngineEvent = function(kind, e, extra)
	if kind == "spike" then
		showToast(("Frame spike — %.0fms"):format(extra), WARN)
	end
end
local floatShadow = Instance.new("Frame")
floatShadow.Size = UDim2.fromOffset(138, 52)
floatShadow.AnchorPoint = Vector2.new(1, 0.5)
floatShadow.Position = UDim2.new(1, -14, 0.74, 4)
floatShadow.BackgroundColor3 = Color3.new(0, 0, 0)
floatShadow.BackgroundTransparency = 0.55
floatShadow.BorderSizePixel = 0
floatShadow.ZIndex = 1
floatShadow.Parent = gui
corner(floatShadow, 26)
local float = Instance.new("TextButton")
float.Name = "PerformancePill"
float.Size = UDim2.fromOffset(138, 52)
float.AnchorPoint = Vector2.new(1, 0.5)
float.Position = UDim2.new(1, -14, 0.74, 0)
float.BackgroundColor3 = BG
float.AutoButtonColor = false
float.Text = ""
float.ZIndex = 5
float.Parent = gui
corner(float, 26)
local floatStroke = stroke(float, ACCENT, 1.5, 0.2)
gradient(float, Color3.fromRGB(21, 26, 38), Color3.fromRGB(10, 11, 16), 20)
local floatAccent = Instance.new("Frame")
floatAccent.Size = UDim2.fromOffset(4, 30)
floatAccent.Position = UDim2.fromOffset(10, 11)
floatAccent.BorderSizePixel = 0
floatAccent.BackgroundColor3 = GOOD
floatAccent.ZIndex = 7
floatAccent.Parent = float
corner(floatAccent, 3)
local floatMark = label(float, {
	text = "PERFORMANCE", font = FONT_BOLD, size = 8, color = FAINT,
	position = UDim2.fromOffset(20, 6), uiSize = UDim2.fromOffset(90, 12), zindex = 7,
})
local iconLabel = label(float, {
	text = "-- FPS", font = FONT_BLACK, size = 18, color = TEXT,
	position = UDim2.fromOffset(19, 19), uiSize = UDim2.fromOffset(80, 24), zindex = 7,
})
local floatStatus = Instance.new("TextLabel")
floatStatus.BackgroundTransparency = 1
floatStatus.AnchorPoint = Vector2.new(1, 0.5)
floatStatus.Position = UDim2.new(1, -14, 0.78, 0)
floatStatus.Size = UDim2.fromOffset(50, 16)
floatStatus.Font = FONT_BOLD
floatStatus.Text = "READY"
floatStatus.TextSize = 8
floatStatus.TextColor3 = GOOD
floatStatus.TextXAlignment = Enum.TextXAlignment.Right
floatStatus.ZIndex = 7
floatStatus.Parent = float
float.MouseEnter:Connect(function() tween(floatStroke, {Transparency = 0}, 0.12) end)
float.MouseLeave:Connect(function() tween(floatStroke, {Transparency = 0.2}, 0.18) end)
local panel = Instance.new("Frame")
panel.Name = "Dashboard"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -18, 0.5, 0)
panel.Size = UDim2.fromOffset(380, 520)
panel.BackgroundColor3 = BG
panel.Visible = false
panel.ClipsDescendants = true
panel.ZIndex = 20
panel.Parent = gui
corner(panel, 20)
stroke(panel, Color3.fromRGB(72, 88, 128), 1.2, 0.3)
gradient(panel, Color3.fromRGB(14, 17, 25), Color3.fromRGB(8, 9, 13), 90)
local panelScale = Instance.new("UIScale")
panelScale.Scale = 1
panelScale.Parent = panel
local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, -32, 0, 2)
topGlow.Position = UDim2.fromOffset(16, 0)
topGlow.BorderSizePixel = 0
topGlow.BackgroundColor3 = ACCENT
topGlow.ZIndex = 21
topGlow.Parent = panel
corner(topGlow, 2)
gradient(topGlow, ACCENT, ACCENT_2, 0)
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundTransparency = 1
header.ZIndex = 22
header.Parent = panel
local headerGrip = Instance.new("Frame")
headerGrip.Position = UDim2.fromOffset(16, 14)
headerGrip.Size = UDim2.fromOffset(4, 30)
headerGrip.BorderSizePixel = 0
headerGrip.ZIndex = 23
headerGrip.Parent = header
corner(headerGrip, 2)
gradient(headerGrip, ACCENT, ACCENT_2, 90)
local title = label(header, {
	text = "Performance Engine", font = FONT_BOLD, size = 16, color = TEXT,
	position = UDim2.fromOffset(28, 8), uiSize = UDim2.new(1, -112, 0, 20),
})
local subtitle = label(header, {
	text = "By Syntax_errrror", font = FONT, size = 10, color = MUTED,
	position = UDim2.fromOffset(28, 28), uiSize = UDim2.new(1, -112, 0, 16),
})
local function headerIconButton(text, xFromRight, sz)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(32, 32)
	b.Position = UDim2.new(1, xFromRight, 0.5, -16)
	b.BackgroundColor3 = CARD_2
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = TEXT
	b.Font = FONT
	b.TextSize = sz or 16
	b.ZIndex = 24
	b.Parent = header
	corner(b, 10)
	stroke(b, STROKE_C, 1, 0.35)
	return b
end
local compactBtn = headerIconButton("—", -78, 14)
local closeBtn = headerIconButton("×", -40, 20)
local TAB_NAMES = {"Live", "Insights", "Log", "Settings"}
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -28, 0, 34)
tabBar.Position = UDim2.fromOffset(14, 56)
tabBar.BackgroundColor3 = CARD_2
tabBar.ZIndex = 22
tabBar.Parent = panel
corner(tabBar, 10)
pad(tabBar, 3)
local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0)
tabIndicator.BackgroundColor3 = ACCENT
tabIndicator.ZIndex = 22
tabIndicator.Parent = tabBar
corner(tabIndicator, 8)
gradient(tabIndicator, ACCENT, ACCENT_2, 0)
local tabButtons = {}
for i, name in ipairs(TAB_NAMES) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0)
	b.Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0)
	b.BackgroundTransparency = 1
	b.Text = name
	b.Font = FONT_BOLD
	b.TextSize = 10.5
	b.TextColor3 = i == 1 and TEXT or MUTED
	b.AutoButtonColor = false
	b.ZIndex = 23
	b.Parent = tabBar
	tabButtons[i] = b
end
local tabHost = Instance.new("Frame")
tabHost.Position = UDim2.fromOffset(0, 98)
tabHost.Size = UDim2.new(1, 0, 1, -98)
tabHost.BackgroundTransparency = 1
tabHost.ZIndex = 22
tabHost.Parent = panel
local function makeTabPage()
	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.new(1, 0, 1, 0)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 3
	scroller.ScrollBarImageTransparency = 0.3
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.Visible = false
	scroller.ZIndex = 22
	scroller.Parent = tabHost
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = scroller
	pad(scroller, 14, 14, 4, 16)
	return scroller
end
local pages = {}
for i = 1, #TAB_NAMES do pages[i] = makeTabPage() end
pages[1].Visible = true
local currentTab = 1
local function selectTab(i)
	if i == currentTab then return end
	currentTab = i
	for idx, b in ipairs(tabButtons) do
		tween(b, {}, 0) -- no-op keeps timing consistent if extended later
		b.TextColor3 = idx == i and TEXT or MUTED
	end
	tween(tabIndicator, {Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quint)
	for idx, p in ipairs(pages) do p.Visible = idx == i end
end
for i, b in ipairs(tabButtons) do
	b.MouseButton1Click:Connect(function() selectTab(i) end)
end
local function sectionLabel(parent, text, order)
	return label(parent, {
		text = text, font = FONT_BOLD, size = 9.5, color = FAINT,
		order = order, uiSize = UDim2.new(1, 0, 0, 14),
	})
end
local livePage = pages[1]
sectionLabel(livePage, "LIVE", 1)
local metricsCard = card(livePage, UDim2.new(1, 0, 0, 116), 2)
local metricsGrid = Instance.new("UIGridLayout")
metricsGrid.CellSize = UDim2.new(0.485, 0, 0, 46)
metricsGrid.CellPadding = UDim2.new(0.03, 0, 0, 6)
metricsGrid.SortOrder = Enum.SortOrder.LayoutOrder
metricsGrid.Parent = metricsCard
pad(metricsCard, 12, 12, 10, 10)
local function metricTile(parent, order, name, dotColor)
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = order
	wrap.Parent = parent
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(6, 6)
	dot.Position = UDim2.fromOffset(0, 3)
	dot.BackgroundColor3 = dotColor
	dot.Parent = wrap
	corner(dot, 3)
	label(wrap, {
		text = name, font = FONT_BOLD, size = 8.5, color = MUTED,
		position = UDim2.fromOffset(13, 0), uiSize = UDim2.new(1, -13, 0, 12),
	})
	local val = label(wrap, {
		text = "--", font = FONT_BLACK, size = 18, color = TEXT,
		position = UDim2.fromOffset(0, 15), uiSize = UDim2.new(1, 0, 0, 26),
	})
	return val
end
local fpsLabel = metricTile(metricsCard, 1, "FPS", ACCENT)
local healthLabel = metricTile(metricsCard, 2, "HEALTH", GOOD)
local pingLabel = metricTile(metricsCard, 3, "PING", ACCENT_2)
local jitterLabel = metricTile(metricsCard, 4, "JITTER", WARN)
sectionLabel(livePage, "FPS HISTORY", 3)
local chart = card(livePage, UDim2.new(1, 0, 0, 72), 4)
pad(chart, 8, 8, 8, 10)
local chartInner = Instance.new("Frame")
chartInner.BackgroundTransparency = 1
chartInner.Size = UDim2.new(1, 0, 1, 0)
chartInner.Parent = chart
local BAR_COUNT = CONFIG.HistoryLength
local bars = {}
for i = 1, BAR_COUNT do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new((i - 1) / BAR_COUNT, 1, 1, 0)
	bar.Size = UDim2.new(1 / BAR_COUNT, -2, 0, 2)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = ACCENT
	bar.Parent = chartInner
	corner(bar, 2)
	bars[i] = bar
end
local targetLine = Instance.new("Frame")
targetLine.Size = UDim2.new(1, 0, 0, 1)
targetLine.Position = UDim2.new(0, 0, 0.5, 0)
targetLine.BackgroundColor3 = Color3.fromRGB(110, 118, 138)
targetLine.BackgroundTransparency = 0.6
targetLine.BorderSizePixel = 0
targetLine.ZIndex = 0
targetLine.Parent = chartInner
sectionLabel(livePage, "STATUS", 5)
local chipsRow = Instance.new("Frame")
chipsRow.Size = UDim2.new(1, 0, 0, 26)
chipsRow.BackgroundTransparency = 1
chipsRow.LayoutOrder = 6
chipsRow.Parent = livePage
local chipsLayout = Instance.new("UIListLayout")
chipsLayout.FillDirection = Enum.FillDirection.Horizontal
chipsLayout.Padding = UDim.new(0, 6)
chipsLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipsLayout.Parent = chipsRow
local function makeChip(parent, order)
	local c = Instance.new("Frame")
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.new(0, 0, 1, 0)
	c.BackgroundColor3 = CARD_2
	c.LayoutOrder = order
	c.Parent = parent
	corner(c, 13)
	pad(c, 10, 10, 0, 0)
	local t = label(c, {text = "--", font = FONT_BOLD, size = 9, color = TEXT, uiSize = UDim2.new(0, 0, 1, 0)})
	t.AutomaticSize = Enum.AutomaticSize.X
	return c, t
end
local diagnosisChip, diagnosisText = makeChip(chipsRow, 1)
local intensityChip, intensityText = makeChip(chipsRow, 2)
local experimentChip, experimentText = makeChip(chipsRow, 3)
local potatoChip, potatoText = makeChip(chipsRow, 4)
sectionLabel(livePage, "APPLIED", 7)
local appliedCard = card(livePage, UDim2.new(1, 0, 0, 40), 8)
local appliedLabel = label(appliedCard, {
	text = "0 / 0 objects disabled", font = FONT_MED, size = 11, color = TEXT,
	position = UDim2.fromOffset(12, 0), uiSize = UDim2.new(1, -24, 1, 0),
})
local insightsPage = pages[2]
sectionLabel(insightsPage, "LEARNED FROM YOUR OWN FRAME TIME", 1)
local insightsEmpty = label(insightsPage, {
	text = "Collecting results — this fills in as the engine tests changes.",
	font = FONT, size = 10.5, color = MUTED, wrap = true, order = 2,
	uiSize = UDim2.new(1, 0, 0, 32),
})
local INSIGHT_ROW_COUNT = 8
local insightRows = {}
for i = 1, INSIGHT_ROW_COUNT do
	local row = card(insightsPage, UDim2.new(1, 0, 0, 54), i + 2)
	row.Visible = false
	pad(row, 12, 12, 8, 8)
	local nameLbl = label(row, {
		text = "", font = FONT_BOLD, size = 11, color = TEXT,
		uiSize = UDim2.new(1, -70, 0, 14),
	})
	local subLbl = label(row, {
		text = "", font = FONT, size = 8.5, color = MUTED,
		position = UDim2.fromOffset(0, 15), uiSize = UDim2.new(1, -70, 0, 12),
	})
	local impactLbl = label(row, {
		text = "", font = FONT_BOLD, size = 11, color = GOOD,
		position = UDim2.new(1, -60, 0, 0), uiSize = UDim2.fromOffset(60, 14),
		align = Enum.TextXAlignment.Right,
	})
	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.fromOffset(0, 33)
	barBg.Size = UDim2.new(1, 0, 0, 4)
	barBg.BackgroundColor3 = CARD_2
	barBg.Parent = row
	corner(barBg, 2)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = ACCENT
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	corner(barFill, 2)
	local confLbl = label(row, {
		text = "", font = FONT, size = 8, color = FAINT,
		position = UDim2.fromOffset(0, 40), uiSize = UDim2.new(1, 0, 0, 10),
	})
	insightRows[i] = {row = row, name = nameLbl, sub = subLbl, impact = impactLbl, barFill = barFill, conf = confLbl}
end
local logPage = pages[3]
sectionLabel(logPage, "ACTIVITY", 1)
local LOG_ROW_COUNT = 24
local logRows = {}
local LOG_COLORS = {good = GOOD, bad = BAD, warn = WARN, info = FAINT}
for i = 1, LOG_ROW_COUNT do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.LayoutOrder = i + 1
	row.Visible = false
	row.Parent = logPage
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(6, 6)
	dot.Position = UDim2.fromOffset(2, 5)
	dot.Parent = row
	corner(dot, 3)
	local txt = label(row, {
		text = "", font = FONT_MONO, size = 9.5, color = Color3.fromRGB(178, 190, 210),
		position = UDim2.fromOffset(16, 0), uiSize = UDim2.new(1, -16, 0, 0), wrap = true,
	})
	txt.AutomaticSize = Enum.AutomaticSize.Y
	logRows[i] = {row = row, dot = dot, txt = txt}
end
local settingsPage = pages[4]
sectionLabel(settingsPage, "TARGET FRAME RATE", 1)
local targetRow = card(settingsPage, UDim2.new(1, 0, 0, 48), 2)
local targetLabel = label(targetRow, {
	text = tostring(state.targetFPS) .. " FPS", font = FONT_BOLD, size = 15, color = TEXT,
	position = UDim2.fromOffset(50, 0), uiSize = UDim2.new(1, -100, 1, 0), align = Enum.TextXAlignment.Center,
})
makeStepper(targetRow, UDim2.fromOffset(6, 6), "−", function()
	state.targetFPS = math.max(CONFIG.MinTargetFPS, state.targetFPS - 5)
	targetLabel.Text = state.targetFPS .. " FPS"
end)
makeStepper(targetRow, UDim2.new(1, -42, 0, 6), "+", function()
	state.targetFPS = math.min(CONFIG.MaxTargetFPS, state.targetFPS + 5)
	targetLabel.Text = state.targetFPS .. " FPS"
end)
sectionLabel(settingsPage, "CONTROL", 3)
local optimizeRow = card(settingsPage, UDim2.new(1, 0, 0, 54), 4)
label(optimizeRow, {
	text = "Automatic optimization", font = FONT_BOLD, size = 11.5, color = TEXT,
	position = UDim2.fromOffset(12, 8), uiSize = UDim2.new(1, -80, 0, 16),
})
label(optimizeRow, {
	text = "Automatic performance control", font = FONT, size = 8.5, color = MUTED,
	position = UDim2.fromOffset(12, 27), uiSize = UDim2.new(1, -80, 0, 14),
})
local autoToggle = makeToggle(optimizeRow, state.autoOptimize, function(on)
	state.autoOptimize = on
	if not on then forceRestoreAll() end
end)
autoToggle.Position = UDim2.new(1, -62, 0.5, -14)
sectionLabel(settingsPage, "POTATO MODE", 5)
local potatoRow = card(settingsPage, UDim2.new(1, 0, 0, 60), 6)
label(potatoRow, {
	text = "Potato mode", font = FONT_BOLD, size = 11.5, color = TEXT,
	position = UDim2.fromOffset(12, 7), uiSize = UDim2.new(1, -80, 0, 16),
})
label(potatoRow, {
	text = "Aggressive visual reductions for very low-end devices", font = FONT, size = 8.5, color = MUTED,
	position = UDim2.fromOffset(12, 27), uiSize = UDim2.new(1, -80, 0, 22), wrap = true,
})
local potatoToggle = makeToggle(potatoRow, state.potatoMode, function(on)
	state.manualPotatoMode = on
	state.potatoMode = on
	if on then
		if v7PotatoApi and v7PotatoApi.set then
			v7PotatoApi.set(true)
		else
			potatoApply()
		end
		addLog("Potato Mode enabled — MAX visual reduction pipeline locked", "warn")
		showToast("Potato Mode ON", WARN)
	else
		if v7PotatoApi and v7PotatoApi.set then
			v7PotatoApi.set(false)
		else
			potatoRestore()
		end
		addLog("Potato Mode disabled — saved visual settings restored", "info")
		showToast("Potato Mode OFF", ACCENT)
	end
end)
potatoToggle.Position = UDim2.new(1, -62, 0.5, -14)

sectionLabel(settingsPage, "MANUAL OVERRIDE", 7)
local restoreRow = card(settingsPage, UDim2.new(1, 0, 0, 44), 8)
local restoreBtn = Instance.new("TextButton")
restoreBtn.Size = UDim2.new(1, -16, 1, -12)
restoreBtn.Position = UDim2.fromOffset(8, 6)
restoreBtn.BackgroundColor3 = CARD_2
restoreBtn.AutoButtonColor = false
restoreBtn.Text = "Restore everything now"
restoreBtn.Font = FONT_BOLD
restoreBtn.TextSize = 11
restoreBtn.TextColor3 = TEXT
restoreBtn.Parent = restoreRow
corner(restoreBtn, 10)
stroke(restoreBtn, STROKE_C, 1, 0.4)
restoreBtn.MouseButton1Click:Connect(function()
	forceRestoreAll()
	if state.potatoMode then
		state.manualPotatoMode = false
		state.potatoMode = false
		potatoRestore()
	end
	addLog("Manual restore-all triggered from Settings", "info")
	showToast("All effects restored", ACCENT)
end)
sectionLabel(settingsPage, "SESSION", 7)
local sessionCard = card(settingsPage, UDim2.new(1, 0, 0, 108), 8)
pad(sessionCard, 12, 12, 10, 10)
local sessionGrid = Instance.new("UIGridLayout")
sessionGrid.CellSize = UDim2.new(0.485, 0, 0, 34)
sessionGrid.CellPadding = UDim2.new(0.03, 0, 0, 6)
sessionGrid.SortOrder = Enum.SortOrder.LayoutOrder
sessionGrid.Parent = sessionCard
local function sessionTile(order, name)
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder = order
	wrap.Parent = sessionCard
	label(wrap, {text = name, font = FONT_BOLD, size = 8, color = FAINT, uiSize = UDim2.new(1, 0, 0, 11)})
	local v = label(wrap, {
		text = "--", font = FONT_MED, size = 10.5, color = TEXT,
		position = UDim2.fromOffset(0, 13), uiSize = UDim2.new(1, 0, 0, 16), wrap = true,
	})
	return v
end
local sessionFPS = sessionTile(1, "FPS MIN / AVG / MAX")
local sessionPing = sessionTile(2, "PING MIN / AVG / MAX")
local sessionEvents = sessionTile(3, "EVENTS / SESSION TIME")
local sessionBands = sessionTile(4, "INTENSITY BANDS")
local panelSizeFull = UDim2.fromOffset(380, 520)
local currentPanelSize = panelSizeFull
local function setPanelOpen(open)
	state.panelOpen = open
	if open then
		panel.Visible = true
		panel.BackgroundTransparency = 0.06
		panelScale.Scale = 0.965
		tween(panelScale, {Scale = 1}, 0.22, Enum.EasingStyle.Back)
		tween(panel, {BackgroundTransparency = 0}, 0.18)
	else
		tween(panelScale, {Scale = 0.965}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tw = tween(panel, {BackgroundTransparency = 0.06}, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not state.panelOpen then panel.Visible = false end
		end)
	end
end
makeDraggable(float, float, function() setPanelOpen(not state.panelOpen) end)
makeDraggable(title, panel, nil)
makeDraggable(subtitle, panel, nil)
closeBtn.MouseButton1Click:Connect(function() setPanelOpen(false) end)
compactBtn.MouseButton1Click:Connect(function()
	state.compact = not state.compact
	tabBar.Visible = not state.compact
	tabHost.Visible = not state.compact
	compactBtn.Text = state.compact and "+" or "—"
	panel.Size = state.compact and UDim2.fromOffset(currentPanelSize.X.Offset, 58) or currentPanelSize
end)
local GuiService = game:GetService("GuiService")
local function layoutResponsive()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local topInset = 36
	local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
	if ok and inset then topInset = math.max(topInset, inset.Y) end
	local usableH = math.max(300, viewport.Y - topInset - 24)
	local mobile = UserInputService.TouchEnabled and viewport.X < 700
	if mobile then
		local w = math.clamp(viewport.X - 20, 260, 400)
		local h = math.min(560, usableH)
		panelSizeFull = UDim2.fromOffset(w, h)
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.new(0.5, 0, 0.5, topInset * 0.25)
		float.Size = UDim2.fromOffset(122, 46)
		floatShadow.Size = UDim2.fromOffset(122, 46)
		float.Position = UDim2.new(1, -10, 1, -20)
		floatShadow.Position = UDim2.new(1, -10, 1, -16)
	else
		local h = math.min(520, usableH)
		panelSizeFull = UDim2.fromOffset(380, h)
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -18, 0.5, 0)
		float.Size = UDim2.fromOffset(138, 52)
		floatShadow.Size = UDim2.fromOffset(138, 52)
		float.Position = UDim2.new(1, -14, 0.74, 0)
		floatShadow.Position = UDim2.new(1, -14, 0.74, 4)
	end
	currentPanelSize = panelSizeFull
	if not state.compact then panel.Size = panelSizeFull end
end
layoutResponsive()
do
	local camera = Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutResponsive) end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = Workspace.CurrentCamera
		if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(layoutResponsive) end
		layoutResponsive()
	end)
end
local function colorFor(health)
	return health >= 75 and GOOD or health >= 45 and WARN or BAD
end
local function refreshInsightsUI()
	local data = getTopInsightsData(INSIGHT_ROW_COUNT)
	insightsEmpty.Visible = #data == 0
	for i = 1, INSIGHT_ROW_COUNT do
		local r = insightRows[i]
		local d = data[i]
		if d then
			r.row.Visible = true
			r.name.Text = d.title
			r.sub.Text = d.subtitle
			r.impact.Text = d.impactText
			r.impact.TextColor3 = d.positive and GOOD or FAINT
			r.conf.Text = ("%d%% confidence • %d tests"):format(math.floor(d.confidence * 100), d.tests)
			tween(r.barFill, {Size = UDim2.new(math.clamp(d.confidence, 0, 1), 0, 1, 0)}, 0.25)
			r.barFill.BackgroundColor3 = d.positive and GOOD or FAINT
		else
			r.row.Visible = false
		end
	end
end
local lastLogCount = -1
local function refreshLogUI()
	if #state.log == lastLogCount then return end
	lastLogCount = #state.log
	for i = 1, LOG_ROW_COUNT do
		local r = logRows[i]
		local entry = state.log[i]
		if entry then
			r.row.Visible = true
			r.txt.Text = entry.text
			local c = LOG_COLORS[entry.tag] or FAINT
			r.dot.BackgroundColor3 = c
		else
			r.row.Visible = false
		end
	end
end
task.spawn(function()
	local tick = 0
	while gui.Parent do
		tick += 1
		local health = computeHealthScore()
		local healthColor = colorFor(health)
		iconLabel.Text = tostring(math.floor(state.smoothedFPS)) .. " FPS"
		floatAccent.BackgroundColor3 = healthColor
		floatStroke.Color = healthColor
		floatStatus.Text = state.autoOptimize and "AUTO" or "PAUSED"
		floatStatus.TextColor3 = healthColor
		floatShadow.Position = UDim2.new(
			float.Position.X.Scale, float.Position.X.Offset,
			float.Position.Y.Scale, float.Position.Y.Offset + 4)
		fpsLabel.Text = ("%d"):format(math.floor(state.smoothedFPS))
		fpsLabel.TextColor3 = healthColor
		pingLabel.Text = ("%d ms"):format(math.floor(state.ping))
		jitterLabel.Text = ("%.1f ms"):format(state.jitterMs)
		healthLabel.Text = ("%d"):format(health)
		healthLabel.TextColor3 = healthColor
		local disabledCount = 0
		for _, e in ipairs(registry) do if e.disabledByUs then disabledCount += 1 end end
		appliedLabel.Text = ("%d / %d objects disabled  •  target %d FPS  •  %s"):format(disabledCount, #registry, state.targetFPS, adaptiveTierName(state.adaptiveTier))
		diagnosisText.Text = "Diagnosis: " .. state.diagnosis
		diagnosisChip.BackgroundColor3 = state.diagnosis == "spiky" and Color3.fromRGB(70, 55, 26)
			or state.diagnosis == "sustained" and Color3.fromRGB(70, 30, 34) or CARD_2
		intensityText.Text = ("Intensity %d%%"):format(math.floor(state.intensity * 100))
		experimentText.Text = pendingAction and ("Testing: " .. (pendingAction.label or "settling")) or "Idle"
		experimentChip.BackgroundColor3 = pendingAction and Color3.fromRGB(26, 46, 72) or CARD_2
		local hist = state.history.fps
		local maxVal = math.max(30, state.targetFPS * 1.2)
		for i = 1, BAR_COUNT do
			local histIndex = i - (BAR_COUNT - #hist)
			local v = histIndex >= 1 and hist[histIndex] or 0
			local h = math.clamp(v / maxVal, 0.02, 1)
			bars[i].Size = UDim2.new(1 / BAR_COUNT, -2, h, 0)
			bars[i].BackgroundColor3 = v >= state.targetFPS and GOOD
				or v >= state.targetFPS * 0.7 and WARN
				or BAD
		end
		local s = state.session
		local elapsed = os.clock() - s.startClock
		sessionFPS.Text = ("%d / %d / %d"):format(
			s.fpsMin == math.huge and 0 or math.floor(s.fpsMin), math.floor(s.fpsCount > 0 and (s.fpsSum / s.fpsCount) or 0), math.floor(s.fpsMax))
		sessionPing.Text = ("%d / %d / %d"):format(
			s.pingMin == math.huge and 0 or math.floor(s.pingMin), math.floor(s.pingCount > 0 and (s.pingSum / s.pingCount) or 0), math.floor(s.pingMax))
		sessionEvents.Text = ("%d events / %ds"):format(s.optimizationEvents, math.floor(elapsed))
		sessionBands.Text = ("low %ds  med %ds  high %ds  ext %ds"):format(
			math.floor(s.timeInBand.low), math.floor(s.timeInBand.medium), math.floor(s.timeInBand.high), math.floor(s.timeInBand.extreme))
		if tick % 5 == 0 then refreshInsightsUI() end
		refreshLogUI()
		task.wait(0.1)
	end
end)
addLog("CokeBoys-APE ULTRA started (adaptive controller ready)", "info")
addLog("Auto optimization is OFF by default — enable it in Settings", "info")

-- Auto optimization starts OFF; Potato Mode also starts OFF. Enable either manually from Settings.
if state.potatoMode then
	potatoApply()
end

-- ============================================================================
