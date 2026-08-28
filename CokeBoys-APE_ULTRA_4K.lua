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
	DefaultAutoOptimize = true,
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
	CostRefreshInterval = 12,
	UIUpdateInterval = 0.25,
	PingSampleInterval = 2,
	MaxSpikeAssociationsPerEvent = 24,
	EmergencyFPSRatio = 0.45,
	CriticalFPSRatio = 0.30,
	EmergencyIntensity = 0.82,
	CriticalIntensity = 1.0,
	AutoPotatoMode = true,
	AutoPotatoEnterRatio = 0.38,
	AutoPotatoExitRatio = 0.78,
	AutoPotatoRecoveryTime = 7,
	ControllerDeadband = 0.025,
	StableRecoveryTime = 2.5,
	MaxDecisionCandidates = 20,
	MaxMaintenancePerPass = 400,
	SpikeCooldown = 1,
	PotatoModeDefault = false,
	PotatoParticleRateScale = 0.15,
	PotatoTrailLifetimeScale = 0.20,
	PotatoBeamSegments = 1,
	PotatoStreamingRadius = 128,
	PotatoWaterWaveSize = 0,
	PotatoWaterWaveSpeed = 0,
	PotatoWaterReflectance = 0,
	PotatoWaterTransparency = 1,
	PotatoTerrainDecoration = false,
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
	panelOpen = false,
	compact = false,
	lastSpikeAt = -math.huge,
	sampleTimer = 0,
	decisionTimer = 0,
	resortTimer = 0,
	spikeDecayTimer = 0,
	warmupTimer = 0,
	maintenanceTimer = 0,
	costTimer = 0,
	uiTimer = 0,
	pingTimer = 0,
	recoveryTimer = 0,
	autoPotatoApplied = false,
	qualityLevel = 0,
	lastActionClock = -math.huge,
	disabledCount = 0,
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

-- Fast-path bookkeeping. These avoid repeatedly walking the whole registry in hot UI/decision paths.
local disabledCountCache = 0
local totalEligibleCostCache = 0
local costCacheDirty = true
local registryGeneration = 0

local function markRegistryDirty(costDirty)
	candidateCacheDirty = true
	if costDirty then costCacheDirty = true end
	registryGeneration += 1
end

local function safeGet(inst, prop, fallback)
	local ok, value = pcall(function() return inst[prop] end)
	return ok and value ~= nil and value or fallback
end

local function safeSet(inst, prop, value)
	local ok = pcall(function()
		if inst[prop] ~= value then inst[prop] = value end
	end)
	return ok
end
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
	costCacheDirty = true
	registryGeneration += 1
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
	disabledCountCache = math.max(0, disabledCountCache - (entry.disabledByUs and 1 or 0))
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
	-- Property listeners keep cost estimates fresh without a full-scene scan on every frame.
	if kind == "ParticleEmitter" then
		for _, prop in ipairs({"Rate", "Lifetime"}) do
			pcall(function() inst:GetPropertyChangedSignal(prop):Connect(function() costCacheDirty = true end) end)
		end
	elseif kind == "Trail" then
		pcall(function() inst:GetPropertyChangedSignal("Lifetime"):Connect(function() costCacheDirty = true end) end)
	elseif kind == "Fire" then
		pcall(function() inst:GetPropertyChangedSignal("Size"):Connect(function() costCacheDirty = true end) end)
	end
	inst.Destroying:Connect(function() removeRegistryEntry(entry) end)
end

for _, inst in ipairs(Workspace:GetDescendants()) do registerInstance(inst) end
Workspace.DescendantAdded:Connect(function(inst)
	registerInstance(inst)
	if state.potatoMode then
		if inst:IsA("ParticleEmitter") then pcall(function() inst.Rate *= CONFIG.PotatoParticleRateScale; inst.TimeScale = math.min(inst.TimeScale, 0.65) end)
		elseif inst:IsA("Trail") then pcall(function() inst.Lifetime *= CONFIG.PotatoTrailLifetimeScale end)
		elseif inst:IsA("Beam") then pcall(function() inst.Segments = CONFIG.PotatoBeamSegments end)
		elseif inst:IsA("Fire") then pcall(function() inst.Heat = 0; inst.Size = math.min(inst.Size, 1) end)
		elseif inst:IsA("Smoke") then pcall(function() inst.Opacity = math.min(inst.Opacity, 0.15); inst.Size = math.min(inst.Size, 2) end)
		elseif inst:IsA("Sparkles") then pcall(function() inst.Enabled = false end)
		end
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
Lighting.ChildAdded:Connect(cachePostEffect)

local originalGlobalShadows = Lighting.GlobalShadows
local originalStreamingRadius = 1000
pcall(function() originalStreamingRadius = Workspace.StreamingTargetRadius end)
local shadowsDisabledByUs, streamingReducedByUs = false, false
local lastStreamingTarget = originalStreamingRadius

-- Potato Mode is intentionally separate from the normal optimizer and
-- keeps its own snapshot so every change can be reversed cleanly.
local potatoSnapshot = {
	captured = false,
	particles = {},
	trails = {},
	beams = {},
	fires = {},
	smokes = {},
	sparkles = {},
	postEffects = {},
	globalShadows = nil,
	streamingRadius = nil,
	terrainDecoration = nil,
	waterWaveSize = nil,
	waterWaveSpeed = nil,
	waterReflectance = nil,
	waterTransparency = nil,
}

local function potatoCapture()
	if potatoSnapshot.captured then return end
	potatoSnapshot.captured = true
	pcall(function() potatoSnapshot.globalShadows = Lighting.GlobalShadows end)
	pcall(function() potatoSnapshot.streamingRadius = Workspace.StreamingTargetRadius end)

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function() potatoSnapshot.terrainDecoration = terrain.Decoration end)
		pcall(function() potatoSnapshot.waterWaveSize = terrain.WaterWaveSize end)
		pcall(function() potatoSnapshot.waterWaveSpeed = terrain.WaterWaveSpeed end)
		pcall(function() potatoSnapshot.waterReflectance = terrain.WaterReflectance end)
		pcall(function() potatoSnapshot.waterTransparency = terrain.WaterTransparency end)
	end

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ParticleEmitter") then
			potatoSnapshot.particles[inst] = {rate = inst.Rate, timeScale = inst.TimeScale, lifetime = inst.Lifetime}
		elseif inst:IsA("Trail") then
			potatoSnapshot.trails[inst] = {lifetime = inst.Lifetime}
		elseif inst:IsA("Beam") then
			potatoSnapshot.beams[inst] = {segments = inst.Segments}
		elseif inst:IsA("Fire") then
			potatoSnapshot.fires[inst] = {heat = inst.Heat, size = inst.Size}
		elseif inst:IsA("Smoke") then
			potatoSnapshot.smokes[inst] = {opacity = inst.Opacity, size = inst.Size}
		elseif inst:IsA("Sparkles") then
			potatoSnapshot.sparkles[inst] = {enabled = inst.Enabled}
		end
	end

	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst:IsA("PostEffect") then potatoSnapshot.postEffects[inst] = inst.Enabled end
	end
end

local function potatoApply()
	potatoCapture()

	for inst, info in pairs(potatoSnapshot.particles) do
		if inst.Parent then
			pcall(function()
				inst.Rate = math.max(0, info.rate * CONFIG.PotatoParticleRateScale)
				inst.TimeScale = math.min(info.timeScale, 0.65)
				inst.Lifetime = NumberRange.new(
					math.max(0.05, info.lifetime.Min * CONFIG.PotatoParticleRateScale),
					math.max(0.05, info.lifetime.Max * CONFIG.PotatoParticleRateScale)
				)
			end)
		end
	end
	for inst, info in pairs(potatoSnapshot.trails) do
		if inst.Parent then pcall(function() inst.Lifetime = math.max(0.03, info.lifetime * CONFIG.PotatoTrailLifetimeScale) end) end
	end
	for inst, _ in pairs(potatoSnapshot.beams) do
		if inst.Parent then pcall(function() inst.Segments = CONFIG.PotatoBeamSegments end) end
	end
	for inst, info in pairs(potatoSnapshot.fires) do
		if inst.Parent then pcall(function() inst.Heat = 0; inst.Size = math.min(info.size, 1) end) end
	end
	for inst, info in pairs(potatoSnapshot.smokes) do
		if inst.Parent then pcall(function() inst.Opacity = math.min(info.opacity, 0.15); inst.Size = math.min(info.size, 2) end) end
	end
	for inst, _ in pairs(potatoSnapshot.sparkles) do
		if inst.Parent then pcall(function() inst.Enabled = false end) end
	end
	for inst, _ in pairs(potatoSnapshot.postEffects) do
		if inst.Parent then pcall(function() inst.Enabled = false end) end
	end

	pcall(function() Lighting.GlobalShadows = false end)
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
		if inst.Parent then pcall(function() inst.Rate = info.rate; inst.TimeScale = info.timeScale; inst.Lifetime = info.lifetime end) end
	end
	for inst, info in pairs(potatoSnapshot.trails) do
		if inst.Parent then pcall(function() inst.Lifetime = info.lifetime end) end
	end
	for inst, info in pairs(potatoSnapshot.beams) do
		if inst.Parent then pcall(function() inst.Segments = info.segments end) end
	end
	for inst, info in pairs(potatoSnapshot.fires) do
		if inst.Parent then pcall(function() inst.Heat = info.heat; inst.Size = info.size end) end
	end
	for inst, info in pairs(potatoSnapshot.smokes) do
		if inst.Parent then pcall(function() inst.Opacity = info.opacity; inst.Size = info.size end) end
	end
	for inst, info in pairs(potatoSnapshot.sparkles) do
		if inst.Parent then pcall(function() inst.Enabled = info.enabled end) end
	end
	for inst, enabled in pairs(potatoSnapshot.postEffects) do
		if inst.Parent then pcall(function() inst.Enabled = enabled end) end
	end
	if potatoSnapshot.globalShadows ~= nil then pcall(function() Lighting.GlobalShadows = potatoSnapshot.globalShadows end) end
	if potatoSnapshot.streamingRadius ~= nil then pcall(function() Workspace.StreamingTargetRadius = potatoSnapshot.streamingRadius end) end

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		if potatoSnapshot.terrainDecoration ~= nil then pcall(function() terrain.Decoration = potatoSnapshot.terrainDecoration end) end
		if potatoSnapshot.waterWaveSize ~= nil then pcall(function() terrain.WaterWaveSize = potatoSnapshot.waterWaveSize end) end
		if potatoSnapshot.waterWaveSpeed ~= nil then pcall(function() terrain.WaterWaveSpeed = potatoSnapshot.waterWaveSpeed end) end
		if potatoSnapshot.waterReflectance ~= nil then pcall(function() terrain.WaterReflectance = potatoSnapshot.waterReflectance end) end
		if potatoSnapshot.waterTransparency ~= nil then pcall(function() terrain.WaterTransparency = potatoSnapshot.waterTransparency end) end
	end
	potatoSnapshot.captured = false
end

local onEngineEvent = function(_kind, _e, _extra) end
local showToast -- forward declaration; GUI is constructed later

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
	disabledCountCache = 0
	local totalCost = 0
	for _, e in ipairs(registry) do
		if e.inst.Parent and e.originalValue == true then
			totalCost += e.cost
			local ok, enabled = pcall(function() return e.inst.Enabled end)
			if ok then
				if enabled and not e.disabledByUs then enabledCache[#enabledCache + 1] = e
				elseif e.disabledByUs and not enabled then
					disabledCache[#disabledCache + 1] = e
					disabledCountCache += 1
				end
			end
		end
	end
	totalEligibleCostCache = totalCost
	costCacheDirty = false
	candidateCacheDirty = false
end

local function collectCandidates(wantEnabledOnes)
	rebuildCandidateCaches()
	return wantEnabledOnes and enabledCache or disabledCache
end

local lastDiagnosis = "stable"
local function updateDiagnosis()
	local old = state.diagnosis
	if state.jitterMs > CONFIG.JitterSpikyThreshold and state.smoothedFPS >= state.targetFPS * 0.85 then
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
	if not e or not e.inst.Parent then return false end
	local current = safeGet(e.inst, "Enabled", nil)
	if current == enabled then
		local wasDisabled = e.disabledByUs
		e.disabledByUs = not enabled
		if wasDisabled ~= e.disabledByUs then
			disabledCountCache += e.disabledByUs and 1 or -1
		end
		e.lastObservedEnabled = enabled
		return true
	end
	local ok = safeSet(e.inst, "Enabled", enabled)
	if ok then
		local wasDisabled = e.disabledByUs
		e.disabledByUs = not enabled
		e.lastObservedEnabled = enabled
		if wasDisabled ~= e.disabledByUs then
			disabledCountCache += e.disabledByUs and 1 or -1
		end
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
	collectCandidates(false)
	local total = 0
	for _, e in ipairs(disabledCache) do total += e.cost end
	return total
end

local function totalEligibleCost()
	collectCandidates(true)
	if not costCacheDirty then return totalEligibleCostCache end
	local total = 0
	for _, e in ipairs(registry) do
		if e.inst.Parent and e.originalValue == true then total += e.cost end
	end
	totalEligibleCostCache = total
	costCacheDirty = false
	return total
end

local function runDecisionCycle()
	updateDiagnosis()
	if state.warmupTimer < CONFIG.WarmupTime then return end
	local enabled = collectCandidates(true)
	local disabled = collectCandidates(false)
	local budget = totalEligibleCost() * math.clamp(state.intensity, 0, 1) * 0.35
	if state.qualityLevel >= 3 then budget = math.max(budget, totalEligibleCost() * 0.65) end
	local current = 0
	for _, e in ipairs(disabled) do current += e.cost end
	if budget > current and #enabled > 0 then
		table.sort(enabled, function(a, b) return computeFinalRank(a) > computeFinalRank(b) end)
		local tested = 0
		for _, candidate in ipairs(enabled) do
			tested += 1
			if startAction({candidate}, "disable", "performance test") then break end
			if tested >= CONFIG.MaxDecisionCandidates then break end
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

local function updateQualityLadder()
	local ratio = state.smoothedFPS / math.max(state.targetFPS, 1)
	local old = state.qualityLevel
	if ratio <= CONFIG.CriticalFPSRatio then
		state.qualityLevel = 4
	elseif ratio <= CONFIG.EmergencyFPSRatio then
		state.qualityLevel = 3
	elseif ratio < 0.70 then
		state.qualityLevel = 2
	elseif ratio < 0.90 then
		state.qualityLevel = 1
	else
		state.qualityLevel = 0
	end
	if state.qualityLevel ~= old then
		local names = {[0]="full", [1]="light", [2]="heavy", [3]="emergency", [4]="critical"}
		addLog("Quality level → " .. names[state.qualityLevel], state.qualityLevel >= 3 and "warn" or "info")
	end
end

local function updateAutoPotato(dt)
	if not CONFIG.AutoPotatoMode or not state.autoOptimize then return end
	local ratio = state.smoothedFPS / math.max(state.targetFPS, 1)
	if not state.autoPotatoApplied and ratio <= CONFIG.AutoPotatoEnterRatio then
		if not state.potatoMode then
			state.autoPotatoApplied = true
			state.potatoMode = true
			potatoApply()
			addLog("Automatic Potato Mode engaged — critical performance", "warn")
			showToast("Emergency Potato Mode", WARN)
		end
	elseif state.autoPotatoApplied and ratio >= CONFIG.AutoPotatoExitRatio then
		state.recoveryTimer += dt
		if state.recoveryTimer >= CONFIG.AutoPotatoRecoveryTime then
			state.autoPotatoApplied = false
			state.potatoMode = false
			potatoRestore()
			state.recoveryTimer = 0
			addLog("Automatic Potato Mode disengaged — performance recovered", "good")
			showToast("Potato Mode recovered", GOOD)
		end
	else
		state.recoveryTimer = 0
	end
end

local function stepController(dt)
	if not state.autoOptimize or state.warmupTimer < CONFIG.WarmupTime then return end
	local target, fps = state.targetFPS, state.smoothedFPS
	local ratio = fps / math.max(target, 1)
	if ratio < 1 - CONFIG.ControllerDeadband then
		local err = math.clamp((target - fps) / target, 0, 1)
		local severity = state.diagnosis == "sustained" and 1.15 or 0.8
		state.intensity = math.clamp(state.intensity + CONFIG.AttackRate * err * severity * dt, 0, 1)
	elseif ratio > CONFIG.RecoveryMargin + CONFIG.ControllerDeadband and state.jitterMs < CONFIG.JitterSpikyThreshold then
		local headroom = math.clamp((fps / target) - CONFIG.RecoveryMargin, 0, 1)
		state.intensity = math.clamp(state.intensity - CONFIG.DecayRate * (0.5 + headroom) * dt, 0, 1)
	end
end

local function detectSpike(dt, mean)
	if state.warmupTimer < CONFIG.WarmupTime or frameSampleCount < 12 then return false end
	local threshold = math.max(mean * CONFIG.SpikeMultiplier, mean + math.max(state.jitterMs / 1000, 0.001) * 2.0)
	return dt > threshold and dt > CONFIG.SpikeMinDelta
end


-- ============================================================================
-- APE MAX CORE: adaptive client-side render scaler
-- This layer is deliberately independent from the learned effect toggler.
-- It scales expensive visual properties only when the quality ladder requires
-- it, keeps one snapshot per instance, avoids redundant writes, and restores
-- values when the pressure disappears.
-- ============================================================================
local MAX = {
    enabled = true,
    scanInterval = 3.0,
    maxScanPerPass = 350,
    applyBudgetPerPass = 80,
    restoreBudgetPerPass = 100,
    severeLevel = 3,
    criticalLevel = 4,
    baseParticleRate = {1, 0.85, 0.55, 0.30, 0.12},
    baseParticleTime = {1, 0.95, 0.82, 0.68, 0.55},
    trailLifetime = {1, 0.9, 0.70, 0.45, 0.22},
    beamSegments = {nil, nil, 3, 2, 1},
    fireSize = {1, 1, 0.8, 0.55, 0.30},
    fireHeat = {1, 1, 0.75, 0.35, 0},
    smokeOpacity = {1, 0.9, 0.65, 0.35, 0.12},
    smokeSize = {1, 0.9, 0.75, 0.5, 0.3},
    sparkleEnabled = {true, true, true, false, false},
    lightRange = {1, 1, 0.9, 0.65, 0.45},
    lightBrightness = {1, 0.95, 0.8, 0.55, 0.35},
    partCastShadow = {true, true, true, false, false},
    textureTransparency = {0, 0, 0.05, 0.18, 0.35},
    decalTransparency = {0, 0, 0.05, 0.18, 0.35},
    materialLevel = {0, 0, 0, 1, 2},
    fireHeat = {1, 1, 0.82, 0.58, 0.30},
    smokeOpacity = {1, 0.92, 0.70, 0.48, 0.25},
    smokeSize = {1, 0.98, 0.82, 0.62, 0.42},
    sparkleEnabled = {true, true, true, false, false},
    lightRange = {1, 1, 0.82, 0.58, 0.35},
    lightBrightness = {1, 1, 0.86, 0.62, 0.38},
    partCastShadow = {true, true, true, false, false},
    textureTransparency = {0, 0, 0, 0.08, 0.22},
    maxDistance = 650,
    distanceNear = 80,
    distanceFar = 320,
    distanceExponent = 1.65,
}
local maxSnapshots = setmetatable({}, {__mode = 'k'})
local maxKnown = setmetatable({}, {__mode = 'k'})
local maxScanQueue = {}
local maxScanHead = 1
local maxScanTimer = 0
local maxAppliedThisPass = 0
local maxRestoredThisPass = 0
local maxGeneration = 0
local maxStats = {touched=0, writes=0, restores=0, scans=0, skipped=0}

local function maxRemember(inst, key, value)
    local snap = maxSnapshots[inst]
    if not snap then snap = {}; maxSnapshots[inst] = snap end
    if snap[key] == nil then snap[key] = value end
end

local function maxRead(inst, prop)
    local ok, v = pcall(function() return inst[prop] end)
    if ok then return v end
    return nil
end

local function maxWrite(inst, prop, value)
    local ok, old = pcall(function() return inst[prop] end)
    if not ok or old == value then return false end
    local setOK = pcall(function() inst[prop] = value end)
    if setOK then maxStats.writes += 1; return true end
    return false
end

local function maxTrack(inst)
    if not inst or maxKnown[inst] then return end
    maxKnown[inst] = true
    maxScanQueue[#maxScanQueue + 1] = inst
    if #maxScanQueue > 5000 then
        local newQueue = {}
        for i = maxScanHead, #maxScanQueue do
            local x = maxScanQueue[i]
            if x and x.Parent then newQueue[#newQueue+1] = x end
        end
        maxScanQueue, maxScanHead = newQueue, 1
    end
end

local function maxQueueDescendants(root)
    for _, inst in ipairs(root:GetDescendants()) do maxTrack(inst) end
end

maxQueueDescendants(Workspace)
Workspace.DescendantAdded:Connect(function(inst)
    maxTrack(inst)
    for _, child in ipairs(inst:GetDescendants()) do maxTrack(child) end
end)

local function maxRestoreInstance(inst, budget)
    local snap = maxSnapshots[inst]
    if not snap or not inst.Parent then return false end
    if budget <= 0 then return false end
    local changed = false
    for prop, value in pairs(snap) do
        if prop ~= '__level' and prop ~= '__kind' then
            if maxWrite(inst, prop, value) then changed = true end
        end
    end
    if changed then maxStats.restores += 1 end
    maxSnapshots[inst] = nil
    return changed
end

local function maxScaleParticle(inst, level)
    local rate = maxRead(inst, 'Rate')
    local lifetime = maxRead(inst, 'Lifetime')
    local timeScale = maxRead(inst, 'TimeScale')
    if type(rate) == 'number' then maxRemember(inst, 'Rate', rate); maxWrite(inst, 'Rate', rate * MAX.baseParticleRate[level+1]) end
    if timeScale ~= nil then maxRemember(inst, 'TimeScale', timeScale); maxWrite(inst, 'TimeScale', math.min(timeScale, MAX.baseParticleTime[level+1])) end
    if lifetime and level >= 3 then
        maxRemember(inst, 'Lifetime', lifetime)
        local scale = MAX.baseParticleTime[level+1]
        local mn = math.max(0.03, lifetime.Min * scale)
        local mx = math.max(mn, lifetime.Max * scale)
        pcall(function() inst.Lifetime = NumberRange.new(mn, mx) end)
    end
end

local function maxScaleTrail(inst, level)
    local life = maxRead(inst, 'Lifetime')
    if type(life) == 'number' then maxRemember(inst, 'Lifetime', life); maxWrite(inst, 'Lifetime', math.max(0.03, life * MAX.trailLifetime[level+1])) end
end

local function maxScaleBeam(inst, level)
    local seg = MAX.beamSegments[level+1]
    if seg then
        local old = maxRead(inst, 'Segments')
        if old ~= nil then maxRemember(inst, 'Segments', old); maxWrite(inst, 'Segments', math.max(1, seg)) end
    end
end

local function maxScaleFire(inst, level)
    local size, heat = maxRead(inst, 'Size'), maxRead(inst, 'Heat')
    if type(size) == 'number' then maxRemember(inst, 'Size', size); maxWrite(inst, 'Size', math.max(0, size * MAX.fireSize[level+1])) end
    if type(heat) == 'number' then maxRemember(inst, 'Heat', heat); maxWrite(inst, 'Heat', heat * MAX.fireHeat[level+1]) end
end

local function maxScaleSmoke(inst, level)
    local opacity, size = maxRead(inst, 'Opacity'), maxRead(inst, 'Size')
    if type(opacity) == 'number' then maxRemember(inst, 'Opacity', opacity); maxWrite(inst, 'Opacity', opacity * MAX.smokeOpacity[level+1]) end
    if type(size) == 'number' then maxRemember(inst, 'Size', size); maxWrite(inst, 'Size', math.max(0, size * MAX.smokeSize[level+1])) end
end

local function maxScaleSparkles(inst, level)
    if level >= 3 then
        local enabled = maxRead(inst, 'Enabled')
        if enabled ~= nil then maxRemember(inst, 'Enabled', enabled); maxWrite(inst, 'Enabled', MAX.sparkleEnabled[level+1]) end
    end
end

local function maxScaleLight(inst, level)
    local range, brightness = maxRead(inst, 'Range'), maxRead(inst, 'Brightness')
    if type(range) == 'number' then maxRemember(inst, 'Range', range); maxWrite(inst, 'Range', math.max(0, range * MAX.lightRange[level+1])) end
    if type(brightness) == 'number' then maxRemember(inst, 'Brightness', brightness); maxWrite(inst, 'Brightness', math.max(0, brightness * MAX.lightBrightness[level+1])) end
end

local function maxScaleBasePart(inst, level)
    if level < 3 then return end
    local cast = maxRead(inst, 'CastShadow')
    if cast ~= nil then maxRemember(inst, 'CastShadow', cast); maxWrite(inst, 'CastShadow', MAX.partCastShadow[level+1]) end
end

local function maxScaleTexture(inst, level)
    if level < 2 then return end
    local tr = maxRead(inst, 'Transparency')
    if type(tr) == 'number' then
        maxRemember(inst, 'Transparency', tr)
        maxWrite(inst, 'Transparency', math.max(tr, MAX.textureTransparency[level+1]))
    end
end

local function maxApplyInstance(inst, level)
    if not inst or not inst.Parent or level <= 0 then return false end
    maxStats.touched += 1
    local c = inst.ClassName
    if c == 'ParticleEmitter' then maxScaleParticle(inst, level)
    elseif c == 'Trail' then maxScaleTrail(inst, level)
    elseif c == 'Beam' then maxScaleBeam(inst, level)
    elseif c == 'Fire' then maxScaleFire(inst, level)
    elseif c == 'Smoke' then maxScaleSmoke(inst, level)
    elseif c == 'Sparkles' then maxScaleSparkles(inst, level)
    elseif c == 'PointLight' or c == 'SpotLight' or c == 'SurfaceLight' then maxScaleLight(inst, level)
    elseif c == 'Part' or c == 'MeshPart' or c == 'UnionOperation' then maxScaleBasePart(inst, level)
    elseif c == 'Decal' or c == 'Texture' then maxScaleTexture(inst, level)
    else return false end
    local snap = maxSnapshots[inst]
    if snap then snap.__level = level; snap.__kind = c end
    return snap ~= nil
end

local function maxRestoreBelowLevel(level)
    local restored = 0
    for inst, snap in pairs(maxSnapshots) do
        if restored >= MAX.restoreBudgetPerPass then break end
        if not inst.Parent then maxSnapshots[inst] = nil
        elseif (snap.__level or 0) > level then
            if maxRestoreInstance(inst, 1) then restored += 1 end
        end
    end
    return restored
end

local function maxProcess(level)
    if not MAX.enabled then return end
    maxAppliedThisPass, maxRestoredThisPass = 0, 0
    local applyLevel = math.clamp(level, 0, 4)
    if applyLevel == 0 then
        maxRestoredThisPass = maxRestoreBelowLevel(0)
        return
    end
    local processed = 0
    while processed < MAX.maxScanPerPass and maxAppliedThisPass < MAX.applyBudgetPerPass and maxScanHead <= #maxScanQueue do
        local inst = maxScanQueue[maxScanHead]
        maxScanQueue[maxScanHead] = nil
        maxScanHead += 1
        processed += 1
        if inst and inst.Parent then
            if maxApplyInstance(inst, applyLevel) then maxAppliedThisPass += 1 end
        end
    end
    maxStats.scans += processed
    if maxScanHead > 1000 and maxScanHead > #maxScanQueue * 0.5 then
        local compact = {}
        for i = maxScanHead, #maxScanQueue do compact[#compact+1] = maxScanQueue[i] end
        maxScanQueue, maxScanHead = compact, 1
    end
    if applyLevel < 4 then maxRestoredThisPass = maxRestoreBelowLevel(applyLevel) end
end

local function maxUpdate(dt)
    if not MAX.enabled then return end
    maxScanTimer += dt
    local urgent = state.qualityLevel >= MAX.severeLevel
    if urgent or maxScanTimer >= MAX.scanInterval then
        maxScanTimer = 0
        maxProcess(state.qualityLevel)
    end
end

-- Keep newly-created instances inside the adaptive scaler immediately when the
-- engine is already under severe pressure. This avoids waiting for a full pass.
Workspace.DescendantAdded:Connect(function(inst)
    if MAX.enabled and state.qualityLevel >= MAX.severeLevel then
        task.defer(function()
            if inst.Parent then maxApplyInstance(inst, state.qualityLevel) end
        end)
    end
end)


-- ============================================================================
-- APE ULTRA LAYER
-- ============================================================================
-- This layer adds a second adaptive scheduler around the existing engine.
-- It intentionally works in small budgets so the optimizer does not become
-- the workload it is trying to reduce.  It also prefers reversible, visual
-- property scaling over destructive changes.
-- ============================================================================
local ULTRA = {
    enabled = true,
    frameBudgetMs = 0.35,
    emergencyBudgetMs = 0.90,
    criticalBudgetMs = 1.50,
    normalSlice = 24,
    emergencySlice = 80,
    criticalSlice = 140,
    scanSlice = 120,
    distanceRefresh = 1.25,
    profileRefresh = 2.5,
    cleanupRefresh = 4,
    cameraRefresh = 1,
    lastDistanceRefresh = 0,
    lastProfileRefresh = 0,
    lastCleanup = 0,
    lastCameraRefresh = 0,
    cursor = 1,
    generation = 0,
    quality = 0,
    previousQuality = 0,
    pressure = 0,
    stable = 0,
    objectCount = 0,
    visualCount = 0,
    hiddenCount = 0,
    distantCount = 0,
    writes = 0,
    restores = 0,
    scans = 0,
    skipped = 0,
}

local ultraRecords = setmetatable({}, {__mode = "k"})
local ultraList = {}
local ultraHead = 1
local ultraCamera = nil
local ultraCameraPosition = nil
local ultraDirty = true

local function ultraSafeGet(inst, prop)
    local ok, value = pcall(function() return inst[prop] end)
    return ok and value or nil
end

local function ultraSafeSet(inst, prop, value)
    local ok, old = pcall(function() return inst[prop] end)
    if not ok or old == value then return false end
    local success = pcall(function() inst[prop] = value end)
    if success then ULTRA.writes += 1 end
    return success
end

local function ultraRecord(inst, prop, value)
    local r = ultraRecords[inst]
    if not r then
        r = {props = {}, level = 0, lastDistance = math.huge, kind = inst.ClassName}
        ultraRecords[inst] = r
        ultraList[#ultraList + 1] = inst
    end
    if r.props[prop] == nil then r.props[prop] = value end
    return r
end

local function ultraRememberAndSet(inst, prop, value)
    local old = ultraSafeGet(inst, prop)
    if old == nil or old == value then return false end
    ultraRecord(inst, prop, old)
    return ultraSafeSet(inst, prop, value)
end

local function ultraRestore(inst)
    local r = ultraRecords[inst]
    if not r then return false end
    if not inst.Parent then
        ultraRecords[inst] = nil
        return false
    end
    local changed = false
    for prop, value in pairs(r.props) do
        if ultraSafeSet(inst, prop, value) then changed = true end
    end
    if changed then ULTRA.restores += 1 end
    ultraRecords[inst] = nil
    return changed
end

local function ultraIsVisual(inst)
    local c = inst.ClassName
    return c == "ParticleEmitter" or c == "Trail" or c == "Beam"
        or c == "Fire" or c == "Smoke" or c == "Sparkles"
        or c == "PointLight" or c == "SpotLight" or c == "SurfaceLight"
        or c == "Decal" or c == "Texture"
        or c == "BasePart" or c == "Part" or c == "MeshPart"
        or c == "UnionOperation"
end

local function ultraTrack(inst)
    if not inst or not inst.Parent or not ultraIsVisual(inst) then return end
    if ultraRecords[inst] then return end
    local r = ultraRecord(inst, "__tracked", true)
    r.props.__tracked = nil
    ultraDirty = true
end

local function ultraQueueRoot(root)
    if not root then return end
    for _, inst in ipairs(root:GetDescendants()) do
        ultraTrack(inst)
    end
end

ultraQueueRoot(Workspace)
Workspace.DescendantAdded:Connect(function(inst)
    ultraTrack(inst)
    for _, child in ipairs(inst:GetDescendants()) do ultraTrack(child) end
end)
Workspace.DescendantRemoving:Connect(function(inst)
    ultraRecords[inst] = nil
    ultraDirty = true
end)

local function ultraRefreshCamera(force)
    local now = os.clock()
    if not force and now - ULTRA.lastCameraRefresh < ULTRA.cameraRefresh then return end
    ULTRA.lastCameraRefresh = now
    local cam = Workspace.CurrentCamera
    if cam ~= ultraCamera then
        ultraCamera = cam
        ultraCameraPosition = nil
    end
    if cam then
        local ok, pos = pcall(function() return cam.CFrame.Position end)
        if ok then ultraCameraPosition = pos end
    end
end

local function ultraDistance(inst)
    if not ultraCameraPosition then return 0 end
    local ok, pos
    if inst:IsA("BasePart") then
        ok, pos = pcall(function() return inst.Position end)
    else
        local parent = inst.Parent
        while parent and not parent:IsA("BasePart") and parent ~= Workspace do parent = parent.Parent end
        if parent and parent:IsA("BasePart") then
            ok, pos = pcall(function() return parent.Position end)
        end
    end
    if ok and pos then return (pos - ultraCameraPosition).Magnitude end
    return 0
end

local function ultraDistanceFactor(distance)
    if distance <= ULTRA.distanceNear then return 0 end
    if distance >= ULTRA.distanceFar then return 1 end
    local t = (distance - ULTRA.distanceNear) / (ULTRA.distanceFar - ULTRA.distanceNear)
    return math.clamp(t ^ ULTRA.distanceExponent, 0, 1)
end

local function ultraProfile(inst, level)
    local c = inst.ClassName
    local distance = ultraDistance(inst)
    local far = ultraDistanceFactor(distance)
    local pressure = math.clamp(ULTRA.pressure, 0, 1)
    local effective = math.clamp(math.max(level / 4, pressure) + far * 0.32, 0, 1)
    local r = ultraRecords[inst] or ultraRecord(inst, "__x", true)
    r.props.__x = nil
    r.lastDistance = distance
    r.level = math.max(r.level or 0, math.floor(effective * 4 + 0.5))
    return effective, r
end

local function ultraScaleParticle(inst, q, r)
    local rate = ultraSafeGet(inst, "Rate")
    if type(rate) == "number" then
        ultraRememberAndSet(inst, "Rate", rate * (1 - 0.92 * q))
    end
    if q >= 0.35 then
        local life = ultraSafeGet(inst, "Lifetime")
        if typeof(life) == "NumberRange" then
            local s = 1 - 0.48 * q
            ultraRecord(inst, "Lifetime", life)
            local mn = math.max(0.03, life.Min * s)
            local mx = math.max(mn, life.Max * s)
            pcall(function() inst.Lifetime = NumberRange.new(mn, mx) end)
        end
    end
end

local function ultraScaleTrail(inst, q)
    local life = ultraSafeGet(inst, "Lifetime")
    if type(life) == "number" then
        ultraRememberAndSet(inst, "Lifetime", math.max(0.03, life * (1 - 0.82 * q)))
    end
end

local function ultraScaleBeam(inst, q)
    if q < 0.30 then return end
    local seg = ultraSafeGet(inst, "Segments")
    if type(seg) == "number" then
        ultraRememberAndSet(inst, "Segments", math.max(1, math.floor(seg * (1 - 0.80 * q))))
    end
end

local function ultraScaleLight(inst, q)
    local range = ultraSafeGet(inst, "Range")
    local brightness = ultraSafeGet(inst, "Brightness")
    if type(range) == "number" then ultraRememberAndSet(inst, "Range", math.max(0, range * (1 - 0.70 * q))) end
    if type(brightness) == "number" then ultraRememberAndSet(inst, "Brightness", math.max(0, brightness * (1 - 0.55 * q))) end
end

local function ultraScaleFire(inst, q)
    local size = ultraSafeGet(inst, "Size")
    local heat = ultraSafeGet(inst, "Heat")
    if type(size) == "number" then ultraRememberAndSet(inst, "Size", math.max(0, size * (1 - 0.72 * q))) end
    if type(heat) == "number" then ultraRememberAndSet(inst, "Heat", math.max(0, heat * (1 - 0.72 * q))) end
end

local function ultraScaleSmoke(inst, q)
    local opacity = ultraSafeGet(inst, "Opacity")
    local size = ultraSafeGet(inst, "Size")
    if type(opacity) == "number" then ultraRememberAndSet(inst, "Opacity", math.max(0, opacity * (1 - 0.72 * q))) end
    if type(size) == "number" then ultraRememberAndSet(inst, "Size", math.max(0, size * (1 - 0.42 * q))) end
end

local function ultraScaleTexture(inst, q)
    if q < 0.70 then return end
    local tr = ultraSafeGet(inst, "Transparency")
    if type(tr) == "number" then
        ultraRememberAndSet(inst, "Transparency", math.clamp(tr + 0.35 * q, 0, 1))
    end
end

local function ultraScalePart(inst, q)
    if q < 0.72 then return end
    local cast = ultraSafeGet(inst, "CastShadow")
    if cast == true then ultraRememberAndSet(inst, "CastShadow", false) end
end

local function ultraApply(inst, level)
    if not inst or not inst.Parent or level <= 0 then return false end
    local q, r = ultraProfile(inst, level)
    if q <= 0.02 then return false end
    local c = inst.ClassName
    if c == "ParticleEmitter" then ultraScaleParticle(inst, q, r)
    elseif c == "Trail" then ultraScaleTrail(inst, q)
    elseif c == "Beam" then ultraScaleBeam(inst, q)
    elseif c == "Fire" then ultraScaleFire(inst, q)
    elseif c == "Smoke" then ultraScaleSmoke(inst, q)
    elseif c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" then ultraScaleLight(inst, q)
    elseif c == "Decal" or c == "Texture" then ultraScaleTexture(inst, q)
    elseif c == "Part" or c == "MeshPart" or c == "UnionOperation" then ultraScalePart(inst, q)
    else return false end
    return true
end

local function ultraRestorePressure(level)
    if level >= 2 then return end
    local restored = 0
    for i = #ultraList, 1, -1 do
        local inst = ultraList[i]
        if not inst or not inst.Parent then
            table.remove(ultraList, i)
            ultraRecords[inst] = nil
        else
            local r = ultraRecords[inst]
            if r and (r.level or 0) > level then
                if ultraRestore(inst) then restored += 1 end
            end
        end
        if restored >= 50 then break end
    end
end

local function ultraComputePressure()
    local target = math.max(1, state.targetFPS)
    local fpsRatio = state.smoothedFPS / target
    local jitter = math.clamp(state.jitterMs / 30, 0, 1)
    local intensity = math.clamp(state.intensity, 0, 1)
    local quality = math.clamp(state.qualityLevel / 4, 0, 1)
    local p = math.max(intensity, quality)
    if fpsRatio < 1 then p = math.max(p, math.clamp(1 - fpsRatio, 0, 1)) end
    p = math.clamp(p * 0.78 + jitter * 0.12 + (state.diagnosis == "spiky" and 0.10 or 0), 0, 1)
    return p
end

local function ultraUpdateQuality()
    local old = ULTRA.quality
    ULTRA.pressure = ultraComputePressure()
    if state.qualityLevel >= 4 or ULTRA.pressure >= 0.92 then ULTRA.quality = 4
    elseif state.qualityLevel >= 3 or ULTRA.pressure >= 0.72 then ULTRA.quality = 3
    elseif state.qualityLevel >= 2 or ULTRA.pressure >= 0.50 then ULTRA.quality = 2
    elseif state.qualityLevel >= 1 or ULTRA.pressure >= 0.25 then ULTRA.quality = 1
    else ULTRA.quality = 0 end
    if old ~= ULTRA.quality then
        ULTRA.generation += 1
        ultraDirty = true
    end
end

local function ultraCompact()
    local new = {}
    for i = 1, #ultraList do
        local inst = ultraList[i]
        if inst and inst.Parent and ultraIsVisual(inst) then new[#new + 1] = inst end
    end
    ultraList = new
    if ULTRA.cursor > #ultraList then ULTRA.cursor = 1 end
end

local function ultraProcessBudget(dt)
    if not ULTRA.enabled then return end
    local level = ULTRA.quality
    if level <= 0 then
        ultraRestorePressure(0)
        return
    end
    local budget = level >= 4 and ULTRA.criticalSlice or level >= 3 and ULTRA.emergencySlice or ULTRA.normalSlice
    local start = os.clock()
    local processed = 0
    while processed < budget and #ultraList > 0 do
        if ULTRA.cursor > #ultraList then ULTRA.cursor = 1 end
        local inst = ultraList[ULTRA.cursor]
        ULTRA.cursor += 1
        processed += 1
        ULTRA.scans += 1
        if inst and inst.Parent then
            ultraApply(inst, level)
        end
        local elapsedMs = (os.clock() - start) * 1000
        local limit = level >= 4 and ULTRA.criticalBudgetMs or level >= 3 and ULTRA.emergencyBudgetMs or ULTRA.frameBudgetMs
        if elapsedMs >= limit then break end
    end
    if level < 3 then ultraRestorePressure(level) end
end

local function ultraUpdate(dt)
    if not ULTRA.enabled then return end
    ultraRefreshCamera(false)
    ultraUpdateQuality()
    ultraProcessBudget(dt)
    local now = os.clock()
    if now - ULTRA.lastCleanup >= ULTRA.cleanupRefresh then
        ULTRA.lastCleanup = now
        ultraCompact()
    end
end

-- ============================================================================
-- FRAME-TIME GOVERNOR
-- Keeps all auxiliary work under a tiny measured budget.  When the client is
-- healthy it backs off; when pressure rises it gives the visual scaler more
-- time without making the engine itself spin continuously.
-- ============================================================================
local GOVERNOR = {
    enabled = true,
    budget = 0.20,
    emergencyBudget = 0.55,
    criticalBudget = 1.0,
    accumulator = 0,
    pressure = 0,
    skipped = 0,
    runs = 0,
}

local function governorBudget()
    if state.qualityLevel >= 4 then return GOVERNOR.criticalBudget end
    if state.qualityLevel >= 3 then return GOVERNOR.emergencyBudget end
    return GOVERNOR.budget
end

local function governorRun(fn)
    if not GOVERNOR.enabled then return end
    local start = os.clock()
    local ok = pcall(fn)
    GOVERNOR.runs += 1
    local elapsed = (os.clock() - start) * 1000
    if elapsed > governorBudget() then GOVERNOR.skipped += 1 end
    return ok
end

-- ============================================================================
-- SAFE RESTORATION / PLAYER-RESET HANDLING
-- ============================================================================
local function ultraRestoreAll()
    for i = #ultraList, 1, -1 do
        local inst = ultraList[i]
        if inst and inst.Parent then ultraRestore(inst) end
    end
    ultraList = {}
    ultraRecords = setmetatable({}, {__mode = "k"})
    ultraHead = 1
    ULTRA.cursor = 1
    ULTRA.pressure = 0
    ULTRA.quality = 0
end

Players.LocalPlayer.CharacterRemoving:Connect(function()
    -- Do not touch character objects while they are being torn down.
    task.defer(function()
        if state.qualityLevel <= 1 then ultraCompact() end
    end)
end)

-- ============================================================================
-- MICRO CACHE / DECISION HELPERS
-- ============================================================================
local MICRO = {
    lastFPS = state.smoothedFPS,
    lastJitter = state.jitterMs,
    lastIntensity = state.intensity,
    lastLevel = state.qualityLevel,
    unchanged = 0,
    stableFrames = 0,
    dirty = true,
}

local function microChanged()
    local changed = false
    if math.abs(MICRO.lastFPS - state.smoothedFPS) > 1.25 then changed = true end
    if math.abs(MICRO.lastJitter - state.jitterMs) > 2 then changed = true end
    if math.abs(MICRO.lastIntensity - state.intensity) > 0.035 then changed = true end
    if MICRO.lastLevel ~= state.qualityLevel then changed = true end
    MICRO.lastFPS = state.smoothedFPS
    MICRO.lastJitter = state.jitterMs
    MICRO.lastIntensity = state.intensity
    MICRO.lastLevel = state.qualityLevel
    MICRO.dirty = changed
    if changed then MICRO.unchanged = 0 else MICRO.unchanged += 1 end
    return changed
end

local function microIdleOptimization()
    if state.qualityLevel == 0 and state.intensity < 0.05 and MICRO.unchanged > 20 then
        -- Keep the optimizer quiet when nothing needs optimization.
        if maxScanTimer < MAX.scanInterval then maxScanTimer = MAX.scanInterval end
    end
end

-- ============================================================================
-- EXTENDED VISUAL FEATURE PROFILES
-- These profiles are conservative at low pressure and become aggressive only
-- at emergency/critical levels.
-- ============================================================================
local PROFILE = {
    ParticleEmitter = {min = 0.10, far = 0.18},
    Trail = {min = 0.18, far = 0.22},
    Beam = {min = 0.20, far = 0.25},
    Fire = {min = 0.25, far = 0.30},
    Smoke = {min = 0.22, far = 0.28},
    Sparkles = {min = 0.30, far = 0.35},
    PointLight = {min = 0.32, far = 0.38},
    SpotLight = {min = 0.32, far = 0.38},
    SurfaceLight = {min = 0.32, far = 0.38},
    Decal = {min = 0.65, far = 0.78},
    Texture = {min = 0.65, far = 0.78},
    Part = {min = 0.78, far = 0.88},
    MeshPart = {min = 0.78, far = 0.88},
    UnionOperation = {min = 0.82, far = 0.90},
}

local function ultraProfileAllows(inst, q, distance)
    local p = PROFILE[inst.ClassName]
    if not p then return true end
    if distance > ULTRA.distanceFar then return q >= p.far end
    return q >= p.min
end

-- Refine the scaler with profile gating without changing its public API.
local oldUltraApply = ultraApply
ultraApply = function(inst, level)
    if not inst or not inst.Parent or level <= 0 then return false end
    local distance = ultraDistance(inst)
    local q = math.max(level / 4, ULTRA.pressure)
    if not ultraProfileAllows(inst, q, distance) then return false end
    return oldUltraApply(inst, level)
end


RunService.Heartbeat:Connect(function(dt)
	if dt <= 0 then return end
	local mean = pushFrameTime(dt)
	state.fps = 1 / math.max(mean, 1 / 240)
	state.smoothedFPS = state.smoothedFPS * 0.9 + state.fps * 0.1
	state.warmupTimer += dt
	updateQualityLadder()
	stepController(dt)
	updateExperiment(dt)
	updateAutoPotato(dt)
	maxUpdate(dt)
	if ULTRA.enabled then ultraUpdate(dt) end
	if GOVERNOR.enabled then GOVERNOR.pressure = ULTRA.pressure; MICRO.dirty = microChanged(); microIdleOptimization() end

	local band = state.intensity < 0.25 and "low" or state.intensity < 0.5 and "medium" or state.intensity < 0.75 and "high" or "extreme"
	state.session.timeInBand[band] += dt
	state.sampleTimer += dt
	state.resortTimer += dt
	state.spikeDecayTimer += dt
	state.decisionTimer += dt
	state.maintenanceTimer += dt
	state.costTimer += dt
	state.uiTimer += dt
	state.pingTimer += dt

	if detectSpike(dt, mean) then
		local now = os.clock()
		if now - state.lastSpikeAt >= CONFIG.SpikeCooldown then
			state.lastSpikeAt = now
			state.intensity = math.clamp(state.intensity + CONFIG.SpikeJump, 0, 1)
			local spikeCandidates = collectCandidates(true)
			table.sort(spikeCandidates, function(a, b) return a.cost > b.cost end)
			for i = 1, math.min(CONFIG.MaxSpikeAssociationsPerEvent, #spikeCandidates) do
				local e = spikeCandidates[i]
				if e.cost > 15 then e.spikeAssociation += 1 end
			end
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
		if state.pingTimer >= CONFIG.PingSampleInterval then
			state.pingTimer = 0
			local ok, item = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			if ok and type(item) == "number" then state.ping = math.max(0, item) end
		end
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
	local jitterScore = math.clamp(100 - state.jitterMs * 4, 0, 100)
	local pingScore = state.ping <= 50 and 100 or state.ping <= 100 and 80 or state.ping <= 150 and 60 or state.ping <= 250 and 40 or 20
	return math.floor(fpsScore * 0.5 + jitterScore * 0.3 + pingScore * 0.2)
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
showToast = function(text, color)
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
	state.potatoMode = on
	if on then
		potatoApply()
		addLog("Potato Mode enabled — aggressive visual reductions applied", "warn")
		showToast("Potato Mode ON", WARN)
	else
		potatoRestore()
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
		appliedLabel.Text = ("%d / %d objects disabled  •  target %d FPS"):format(disabledCountCache, #registry, state.targetFPS)
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
		if tick % 10 == 0 then refreshInsightsUI() end
		refreshLogUI()
		task.wait(CONFIG.UIUpdateInterval)
	end
end)
addLog("CokeBoys-APE ULTRA started (target " .. state.targetFPS .. " FPS)", "info")

-- Potato Mode default is false; this keeps the original startup behavior unchanged.
if state.potatoMode then
	potatoApply()
end


-- ============================================================
-- APE ULTRA EXTENSION PACK — 4K ARCHITECTURE
-- ============================================================
-- Goals:
--   * minimize hot-path allocations
--   * use hysteresis instead of oscillation
--   * batch expensive registry work
--   * maintain reversible state
--   * avoid redundant property writes
--   * adapt to device capability and frame-time variance
--   * keep the existing CokeBoys-APE systems intact
-- ============================================================

local ULTRA = {
    enabled = true,
    version = "ULTRA-4K",
    frame = 0,
    heartbeat = 0,
    lastClock = os.clock(),
    emaFrame = 1/60,
    emaJitter = 0,
    variance = 0,
    quality = 1,
    requestedQuality = 1,
    stableQuality = 1,
    pressure = 0,
    recovery = 0,
    budget = 0,
    registryCursor = 1,
    registrySweep = 0,
    registryDirty = true,
    scoreDirty = true,
    lastRegistryCount = 0,
    lastDecision = 0,
    lastEmergency = 0,
    lastRecovery = 0,
    writes = 0,
    skippedWrites = 0,
    errors = 0,
    protected = setmetatable({}, {__mode = "k"}),
    original = setmetatable({}, {__mode = "k"}),
    cache = setmetatable({}, {__mode = "k"}),
    costs = setmetatable({}, {__mode = "k"}),
    recent = {},
    recentHead = 0,
    recentCount = 0,
    bands = {
        {enter = 0.00, exit = 0.08},
        {enter = 0.08, exit = 0.18},
        {enter = 0.18, exit = 0.30},
        {enter = 0.30, exit = 0.48},
        {enter = 0.48, exit = 0.68},
        {enter = 0.68, exit = 0.86},
        {enter = 0.86, exit = 1.00},
    },
    config = {
        emaAlpha = 0.075,
        jitterAlpha = 0.10,
        pressureRise = 0.075,
        pressureFall = 0.025,
        recoveryRate = 0.018,
        decisionInterval = 0.35,
        emergencyInterval = 0.18,
        registryBatch = 18,
        registryBatchEmergency = 48,
        costRefresh = 1.75,
        uiMinInterval = 0.16,
        spikeWindow = 0.70,
        severeFrame = 0.105,
        criticalFrame = 0.150,
        hysteresis = 0.055,
        cooldown = 0.75,
        restoreCooldown = 2.25,
        maxRecent = 32,
        writeGuard = true,
    }
}

local ULTRA_TYPES = {
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
    Smoke = true,
    Fire = true,
    Sparkles = true,
    PointLight = true,
    SpotLight = true,
    SurfaceLight = true,
    BloomEffect = true,
    BlurEffect = true,
    ColorCorrectionEffect = true,
    SunRaysEffect = true,
    DepthOfFieldEffect = true,
    Atmosphere = true,
}

local function ultraNow()
    return os.clock()
end

local function ultraClamp01(x)
    if x <= 0 then return 0 end
    if x >= 1 then return 1 end
    return x
end

local function ultraSafe(fn, fallback)
    local ok, value = pcall(fn)
    if ok then return value end
    ULTRA.errors += 1
    return fallback
end

local function ultraRememberRecent(value)
    ULTRA.recentHead = (ULTRA.recentHead % ULTRA.config.maxRecent) + 1
    ULTRA.recent[ULTRA.recentHead] = value
    ULTRA.recentCount = math.min(ULTRA.recentCount + 1, ULTRA.config.maxRecent)
end

local function ultraRecentAverage()
    if ULTRA.recentCount == 0 then return 0 end
    local sum = 0
    for i = 1, ULTRA.recentCount do
        sum += ULTRA.recent[i] or 0
    end
    return sum / ULTRA.recentCount
end

local function ultraFramePressure(dt)
    local target = (state and state.targetFPS) or 60
    local targetDt = 1 / math.max(1, target)
    local ratio = dt / targetDt

    -- Soft knee: healthy frames contribute almost nothing.
    local p = (ratio - 1) / 1.75
    if p < 0 then p = 0 end

    -- Variance makes unstable frame pacing count as pressure too.
    p += math.min(0.22, ULTRA.emaJitter * 3.5)

    if dt >= ULTRA.config.criticalFrame then
        p = math.max(p, 0.92)
    elseif dt >= ULTRA.config.severeFrame then
        p = math.max(p, 0.68)
    end

    return ultraClamp01(p)
end

local function ultraUpdateFrameModel(dt)
    if dt <= 0 or dt > 2 then return end

    local a = ULTRA.config.emaAlpha
    local delta = dt - ULTRA.emaFrame
    ULTRA.emaFrame += delta * a
    ULTRA.variance = ULTRA.variance * 0.92 + delta * delta * 0.08

    local absDelta = math.abs(delta)
    ULTRA.emaJitter += (absDelta - ULTRA.emaJitter) * ULTRA.config.jitterAlpha

    local p = ultraFramePressure(dt)
    if p > ULTRA.pressure then
        ULTRA.pressure += (p - ULTRA.pressure) * ULTRA.config.pressureRise
    else
        ULTRA.pressure += (p - ULTRA.pressure) * ULTRA.config.pressureFall
    end

    if p < 0.08 then
        ULTRA.recovery = math.min(1, ULTRA.recovery + ULTRA.config.recoveryRate)
    else
        ULTRA.recovery = math.max(0, ULTRA.recovery - ULTRA.config.recoveryRate * 2)
    end

    ultraRememberRecent(dt)
end

local function ultraQualityForPressure(p)
    if p >= 0.90 then return 7 end
    if p >= 0.75 then return 6 end
    if p >= 0.60 then return 5 end
    if p >= 0.44 then return 4 end
    if p >= 0.28 then return 3 end
    if p >= 0.14 then return 2 end
    return 1
end

local function ultraShouldPromote(now)
    local desired = ultraQualityForPressure(ULTRA.pressure)
    if desired > ULTRA.quality then
        return desired
    end

    if desired < ULTRA.quality then
        if ULTRA.recovery >= 0.55 and now - ULTRA.lastDecision >= ULTRA.config.restoreCooldown then
            return desired
        end
    end

    return ULTRA.quality
end

local function ultraSetCached(instance, property, value)
    if not instance then return false end
    local cache = ULTRA.cache[instance]
    if not cache then
        cache = {}
        ULTRA.cache[instance] = cache
    end

    local previous = cache[property]
    if ULTRA.config.writeGuard and previous == value then
        ULTRA.skippedWrites += 1
        return false
    end

    local ok = pcall(function()
        instance[property] = value
    end)

    if ok then
        cache[property] = value
        ULTRA.writes += 1
        return true
    end

    ULTRA.errors += 1
    return false
end

local function ultraCapture(instance, property)
    if not instance then return nil end

    local originals = ULTRA.original[instance]
    if not originals then
        originals = {}
        ULTRA.original[instance] = originals
    end

    if originals[property] == nil then
        originals[property] = ultraSafe(function()
            return instance[property]
        end, nil)
    end

    return originals[property]
end

local function ultraRestore(instance, property)
    local originals = ULTRA.original[instance]
    if not originals then return false end
    local value = originals[property]
    if value == nil then return false end
    return ultraSetCached(instance, property, value)
end

local function ultraEstimate(instance)
    if not instance then return 0 end
    local cached = ULTRA.costs[instance]
    if cached then return cached end

    local class = ultraSafe(function() return instance.ClassName end, "")
    local score = 0

    if class == "ParticleEmitter" then
        local rate = ultraSafe(function() return instance.Rate end, 0)
        local lifetime = ultraSafe(function() return instance.Lifetime.Max end, 1)
        local size = ultraSafe(function() return instance.Size.Keypoints[#instance.Size.Keypoints].Value end, 1)
        score = 0.4 + math.min(4, rate / 20) + math.min(2, lifetime) + math.min(1.5, size / 4)
    elseif class == "Trail" then
        local lifetime = ultraSafe(function() return instance.Lifetime end, 0.5)
        score = 1 + lifetime * 2
    elseif class == "Beam" then
        local segments = ultraSafe(function() return instance.Segments end, 10)
        score = 1 + segments / 10
    elseif class == "Smoke" or class == "Fire" or class == "Sparkles" then
        score = 1.8
    elseif class == "PointLight" or class == "SpotLight" or class == "SurfaceLight" then
        local range = ultraSafe(function() return instance.Range end, 10)
        score = 1 + math.min(4, range / 25)
    elseif class == "BloomEffect" or class == "BlurEffect"
        or class == "ColorCorrectionEffect" or class == "SunRaysEffect"
        or class == "DepthOfFieldEffect" then
        score = 2.4
    elseif class == "Atmosphere" then
        score = 2.0
    else
        score = 0.5
    end

    ULTRA.costs[instance] = score
    return score
end

local function ultraInvalidate(instance)
    ULTRA.cache[instance] = nil
    ULTRA.costs[instance] = nil
    ULTRA.registryDirty = true
    ULTRA.scoreDirty = true
end

local function ultraCanTouch(instance)
    if not instance then return false end
    if ULTRA.protected[instance] then return false end

    local class = ultraSafe(function() return instance.ClassName end, "")
    return ULTRA_TYPES[class] == true
end

local function ultraProtect(instance)
    if instance then
        ULTRA.protected[instance] = true
    end
end

local function ultraUnprotect(instance)
    if instance then
        ULTRA.protected[instance] = nil
    end
end

local function ultraAttachSignals(instance)
    if not ultraCanTouch(instance) then return end

    -- Attribute/tag changes can invalidate cheap estimates without
    -- forcing a complete registry rebuild.
    ultraSafe(function()
        instance.AttributeChanged:Connect(function()
            ultraInvalidate(instance)
        end)
    end)
end

local function ultraScanBatch(batch)
    if type(registry) ~= "table" or #registry == 0 then return end

    local n = #registry
    if n ~= ULTRA.lastRegistryCount then
        ULTRA.lastRegistryCount = n
        ULTRA.registryCursor = 1
    end

    local cursor = ULTRA.registryCursor
    local processed = 0

    while processed < batch and n > 0 do
        if cursor > n then cursor = 1 end
        local entry = registry[cursor]
        if entry and entry.instance then
            ultraAttachSignals(entry.instance)
            if not ULTRA.costs[entry.instance] then
                ultraEstimate(entry.instance)
            end
        end
        cursor += 1
        processed += 1
    end

    ULTRA.registryCursor = cursor
    ULTRA.registrySweep += processed

    if ULTRA.registrySweep >= n then
        ULTRA.registrySweep = 0
        ULTRA.registryDirty = false
    end
end

local function ultraRankEntry(entry)
    if not entry or not entry.instance then return -math.huge end

    local cost = ultraEstimate(entry.instance)
    local learned = tonumber(entry.impact) or 0
    local confidence = tonumber(entry.confidence) or 0
    local disabled = entry.disabledByUs and 1 or 0

    -- Prefer expensive, repeatedly useful changes, but penalize
    -- uncertain experiments and already-disabled entries.
    return cost * 1.0
        + math.max(0, learned) * 2.5
        + confidence * 0.75
        - disabled * 8
end

local function ultraEmergencyCandidates(limit)
    local result = {}
    if type(registry) ~= "table" then return result end

    limit = limit or 12

    -- Partial selection keeps this O(n*k) with a small k instead of
    -- sorting the entire registry every decision cycle.
    for _, entry in ipairs(registry) do
        if entry and entry.instance and not entry.disabledByUs then
            local score = ultraRankEntry(entry)
            local inserted = false

            for i = 1, #result do
                if score > result[i].score then
                    table.insert(result, i, {entry = entry, score = score})
                    inserted = true
                    break
                end
            end

            if not inserted and #result < limit then
                result[#result + 1] = {entry = entry, score = score}
            end

            if #result > limit then
                result[#result] = nil
            end
        end
    end

    return result
end

local function ultraApplyEntry(entry, aggressive)
    if not entry or not entry.instance then return false end
    local inst = entry.instance

    if entry.disabledByUs then return false end

    local class = ultraSafe(function() return inst.ClassName end, "")
    local changed = false

    if class == "ParticleEmitter" then
        ultraCapture(inst, "Enabled")
        changed = ultraSetCached(inst, "Enabled", false)
    elseif class == "Trail" then
        ultraCapture(inst, "Enabled")
        changed = ultraSetCached(inst, "Enabled", false)
    elseif class == "Beam" then
        ultraCapture(inst, "Enabled")
        changed = ultraSetCached(inst, "Enabled", false)
    elseif class == "Smoke" or class == "Fire" or class == "Sparkles" then
        ultraCapture(inst, "Enabled")
        changed = ultraSetCached(inst, "Enabled", false)
    elseif class == "PointLight" or class == "SpotLight" or class == "SurfaceLight" then
        ultraCapture(inst, "Enabled")
        changed = ultraSetCached(inst, "Enabled", false)
    elseif aggressive and (
        class == "BloomEffect" or class == "BlurEffect"
        or class == "ColorCorrectionEffect" or class == "SunRaysEffect"
        or class == "DepthOfFieldEffect"
    ) then
        ultraCapture(inst, "Enabled")
        changed = ultraSetCached(inst, "Enabled", false)
    end

    if changed then
        entry.disabledByUs = true
        entry.ultraDisabled = true
    end

    return changed
end

local function ultraRestoreEntry(entry)
    if not entry or not entry.instance or not entry.ultraDisabled then
        return false
    end

    local inst = entry.instance
    local changed = ultraRestore(inst, "Enabled")
    if changed then
        entry.disabledByUs = false
        entry.ultraDisabled = false
    end
    return changed
end

local function ultraEmergencyPush()
    local candidates = ultraEmergencyCandidates(ULTRA.pressure >= 0.86 and 20 or 10)
    local changed = 0
    local aggressive = ULTRA.pressure >= 0.72

    for i = 1, #candidates do
        if ultraApplyEntry(candidates[i].entry, aggressive) then
            changed += 1
        end
    end

    return changed
end

local function ultraRecoveryPass()
    if ULTRA.recovery < 0.75 then return 0 end
    if type(registry) ~= "table" then return 0 end

    local restored = 0
    local checked = 0

    -- Restore only a small number per pass. This prevents recovery itself
    -- from creating a new frame spike.
    for _, entry in ipairs(registry) do
        if checked >= 4 then break end
        if entry and entry.ultraDisabled then
            if ultraRestoreEntry(entry) then restored += 1 end
            checked += 1
        end
    end

    return restored
end

local function ultraDecisionTick(now)
    if not ULTRA.enabled then return end
    if now - ULTRA.lastDecision < ULTRA.config.decisionInterval then return end

    ULTRA.lastDecision = now
    local desired = ultraShouldPromote(now)

    if desired > ULTRA.quality then
        ULTRA.quality = desired
        ULTRA.stableQuality = desired
        ULTRA.recovery = 0
        ULTRA.requestedQuality = desired
        ultraEmergencyPush()
        ULTRA.lastEmergency = now
    elseif desired < ULTRA.quality then
        ULTRA.quality = desired
        ULTRA.stableQuality = desired
        ultraRecoveryPass()
        ULTRA.lastRecovery = now
    end
end

local function ultraHeartbeat(dt)
    ULTRA.frame += 1
    ULTRA.heartbeat += 1

    ultraUpdateFrameModel(dt)

    local now = ultraNow()

    -- Emergency path is deliberately independent of the slower learning
    -- system, so catastrophic frame-time changes get an immediate response.
    if ULTRA.pressure >= 0.68
        and now - ULTRA.lastEmergency >= ULTRA.config.emergencyInterval then
        ULTRA.lastEmergency = now
        ultraEmergencyPush()
    end

    ultraDecisionTick(now)

    local batch = ULTRA.pressure >= 0.60
        and ULTRA.config.registryBatchEmergency
        or ULTRA.config.registryBatch

    if ULTRA.registryDirty or ULTRA.heartbeat % 7 == 0 then
        ultraScanBatch(batch)
    end

    -- Recovery is intentionally incremental.
    if ULTRA.recovery >= 0.82 and ULTRA.heartbeat % 13 == 0 then
        ultraRecoveryPass()
    end
end

-- ============================================================
-- FRAME-PACING GUARD
-- ============================================================
-- Bind only once. If the existing script already has a Heartbeat
-- connection, this remains an independent lightweight safety layer.
if RunService and RunService.Heartbeat then
    RunService.Heartbeat:Connect(ultraHeartbeat)
end

-- ============================================================
-- SMART PROPERTY HELPERS
-- ============================================================

local ULTRA_PROPERTY_COST = {
    Rate = true,
    Lifetime = true,
    Speed = true,
    Size = true,
    LightEmission = true,
    LightInfluence = true,
    Texture = true,
    Transparency = true,
    Color = true,
    Brightness = true,
    Range = true,
    Segments = true,
    Width0 = true,
    Width1 = true,
}

local function ultraWriteProperty(instance, property, value)
    if not ULTRA_PROPERTY_COST[property] then
        return ultraSetCached(instance, property, value)
    end

    ultraCapture(instance, property)
    return ultraSetCached(instance, property, value)
end

local function ultraScaleEmitter(instance, multiplier)
    if not instance then return false end
    local changed = false

    local rate = ultraSafe(function() return instance.Rate end, nil)
    if type(rate) == "number" then
        local target = math.max(0, rate * multiplier)
        changed = ultraWriteProperty(instance, "Rate", target) or changed
    end

    return changed
end

local function ultraScaleLight(instance, multiplier)
    if not instance then return false end
    local changed = false

    local brightness = ultraSafe(function() return instance.Brightness end, nil)
    if type(brightness) == "number" then
        changed = ultraWriteProperty(instance, "Brightness",
            math.max(0, brightness * multiplier)) or changed
    end

    local range = ultraSafe(function() return instance.Range end, nil)
    if type(range) == "number" then
        changed = ultraWriteProperty(instance, "Range",
            math.max(0, range * math.sqrt(multiplier))) or changed
    end

    return changed
end

local function ultraScaleBeam(instance, multiplier)
    if not instance then return false end
    local changed = false

    local segments = ultraSafe(function() return instance.Segments end, nil)
    if type(segments) == "number" then
        changed = ultraWriteProperty(instance, "Segments",
            math.max(1, math.floor(segments * multiplier))) or changed
    end

    return changed
end

-- ============================================================
-- DEVICE PROFILE
-- ============================================================

local ULTRA_PROFILE = {
    touch = false,
    mobile = false,
    viewport = Vector2.new(0, 0),
    fpsHint = 60,
    lowEnd = false,
    highEnd = false,
}

local function ultraDetectProfile()
    ULTRA_PROFILE.touch = ultraSafe(function()
        return UserInputService.TouchEnabled
    end, false)

    local camera = Workspace.CurrentCamera
    if camera then
        ULTRA_PROFILE.viewport = ultraSafe(function()
            return camera.ViewportSize
        end, Vector2.new(0, 0))
    end

    ULTRA_PROFILE.mobile =
        ULTRA_PROFILE.touch
        or ULTRA_PROFILE.viewport.X < 800

    local fps = state and tonumber(state.smoothedFPS) or 60
    ULTRA_PROFILE.fpsHint = fps

    ULTRA_PROFILE.lowEnd =
        ULTRA_PROFILE.mobile
        and ULTRA_PROFILE.viewport.X <= 900

    ULTRA_PROFILE.highEnd =
        not ULTRA_PROFILE.mobile
        and fps >= 100
end

task.spawn(function()
    while gui and gui.Parent do
        ultraDetectProfile()
        task.wait(5)
    end
end)

-- ============================================================
-- GUI OVERHEAD GOVERNOR
-- ============================================================
-- The dashboard should never update at the same frequency as the
-- performance controller during a crisis.
local ULTRA_GUI = {
    last = 0,
    crisisInterval = 0.32,
    normalInterval = 0.10,
}

local function ultraGuiShouldUpdate()
    local now = ultraNow()
    local pressure = ULTRA.pressure
    local interval = pressure >= 0.60
        and ULTRA_GUI.crisisInterval
        or ULTRA_GUI.normalInterval

    if now - ULTRA_GUI.last < interval then
        return false
    end

    ULTRA_GUI.last = now
    return true
end

-- ============================================================
-- EVENT-DRIVEN INSTANCE WATCH
-- ============================================================

local ULTRA_CONNECTIONS = {}

local function ultraWatchContainer(container)
    if not container or ULTRA_CONNECTIONS[container] then return end

    local ok, connection = pcall(function()
        return container.DescendantAdded:Connect(function(instance)
            if ultraCanTouch(instance) then
                ULTRA.registryDirty = true
                ULTRA.scoreDirty = true
                ultraEstimate(instance)
            end
        end)
    end)

    if ok then
        ULTRA_CONNECTIONS[container] = connection
    end
end

ultraWatchContainer(Workspace)

-- ============================================================
-- COST DECAY / LEARNING STABILIZER
-- ============================================================

local ULTRA_LEARNING = {
    decay = 0.997,
    floor = 0,
    ceiling = 100,
}

local function ultraDecayLearnedValues()
    if type(registry) ~= "table" then return end

    for _, entry in ipairs(registry) do
        if entry then
            if type(entry.impact) == "number" then
                entry.impact *= ULTRA_LEARNING.decay
                if math.abs(entry.impact) < ULTRA_LEARNING.floor then
                    entry.impact = 0
                end
                entry.impact = math.clamp(
                    entry.impact,
                    -ULTRA_LEARNING.ceiling,
                    ULTRA_LEARNING.ceiling
                )
            end
        end
    end
end

task.spawn(function()
    while gui and gui.Parent do
        task.wait(30)
        ultraDecayLearnedValues()
    end
end)

-- ============================================================
-- SPIKE BURST PROTECTION
-- ============================================================

local ULTRA_SPIKE = {
    count = 0,
    windowStart = 0,
    burst = false,
}

local function ultraRegisterSpike()
    local now = ultraNow()

    if now - ULTRA_SPIKE.windowStart > ULTRA.config.spikeWindow then
        ULTRA_SPIKE.windowStart = now
        ULTRA_SPIKE.count = 0
        ULTRA_SPIKE.burst = false
    end

    ULTRA_SPIKE.count += 1

    if ULTRA_SPIKE.count >= 3 then
        ULTRA_SPIKE.burst = true
        ULTRA.pressure = math.max(ULTRA.pressure, 0.62)
    end
end

-- ============================================================
-- SELF-OVERHEAD TELEMETRY
-- ============================================================

local ULTRA_TELEMETRY = {
    cycles = 0,
    totalCycleTime = 0,
    maxCycleTime = 0,
    lastCycleTime = 0,
}

local function ultraTimed(fn)
    local start = ultraNow()
    local ok, a, b, c = pcall(fn)
    local elapsed = ultraNow() - start

    ULTRA_TELEMETRY.cycles += 1
    ULTRA_TELEMETRY.totalCycleTime += elapsed
    ULTRA_TELEMETRY.lastCycleTime = elapsed
    ULTRA_TELEMETRY.maxCycleTime =
        math.max(ULTRA_TELEMETRY.maxCycleTime, elapsed)

    if not ok then
        ULTRA.errors += 1
        return nil
    end

    return a, b, c
end

-- ============================================================
-- FINAL SAFETY RULES
-- ============================================================

local function ultraSanity()
    if ULTRA.pressure < 0 then ULTRA.pressure = 0 end
    if ULTRA.pressure > 1 then ULTRA.pressure = 1 end

    if ULTRA.quality < 1 then ULTRA.quality = 1 end
    if ULTRA.quality > 7 then ULTRA.quality = 7 end

    if ULTRA.recovery < 0 then ULTRA.recovery = 0 end
    if ULTRA.recovery > 1 then ULTRA.recovery = 1 end
end

task.spawn(function()
    while gui and gui.Parent do
        ultraSanity()
        task.wait(2)
    end
end)

-- ============================================================
-- ULTRA STATUS
-- ============================================================

addLog("APE ULTRA 4K extension loaded — adaptive governor online", "info")

-- ============================================================
-- DATA-DRIVEN ULTRA TUNING MATRIX
-- ============================================================
local ULTRA_TUNING = {
    ["SAFE"] = {
        ["ParticleEmitter"] = {rate=0.965, enabled=true, priority=20},
        ["Trail"] = {rate=0.930, enabled=true, priority=19},
        ["Beam"] = {rate=0.895, enabled=true, priority=18},
        ["Smoke"] = {rate=1.000, enabled=true, priority=17},
        ["Fire"] = {rate=0.965, enabled=true, priority=16},
        ["Sparkles"] = {rate=0.930, enabled=true, priority=15},
        ["PointLight"] = {rate=0.895, enabled=true, priority=14},
        ["SpotLight"] = {rate=1.000, enabled=true, priority=13},
        ["SurfaceLight"] = {rate=0.965, enabled=true, priority=12},
        ["BloomEffect"] = {rate=0.930, enabled=true, priority=11},
        ["BlurEffect"] = {rate=0.895, enabled=true, priority=10},
        ["ColorCorrectionEffect"] = {rate=1.000, enabled=true, priority=9},
        ["SunRaysEffect"] = {rate=0.965, enabled=true, priority=8},
        ["DepthOfFieldEffect"] = {rate=0.930, enabled=true, priority=7},
        ["Atmosphere"] = {rate=0.895, enabled=true, priority=6},
    },
    ["BALANCED"] = {
        ["ParticleEmitter"] = {rate=0.795, enabled=false, priority=21},
        ["Trail"] = {rate=0.760, enabled=false, priority=20},
        ["Beam"] = {rate=0.725, enabled=false, priority=19},
        ["Smoke"] = {rate=0.830, enabled=false, priority=18},
        ["Fire"] = {rate=0.795, enabled=false, priority=17},
        ["Sparkles"] = {rate=0.760, enabled=false, priority=16},
        ["PointLight"] = {rate=0.725, enabled=false, priority=15},
        ["SpotLight"] = {rate=0.830, enabled=false, priority=14},
        ["SurfaceLight"] = {rate=0.795, enabled=false, priority=13},
        ["BloomEffect"] = {rate=0.760, enabled=false, priority=12},
        ["BlurEffect"] = {rate=0.725, enabled=false, priority=11},
        ["ColorCorrectionEffect"] = {rate=0.830, enabled=false, priority=10},
        ["SunRaysEffect"] = {rate=0.795, enabled=false, priority=9},
        ["DepthOfFieldEffect"] = {rate=0.760, enabled=false, priority=8},
        ["Atmosphere"] = {rate=0.725, enabled=false, priority=7},
    },
    ["AGGRESSIVE"] = {
        ["ParticleEmitter"] = {rate=0.625, enabled=false, priority=22},
        ["Trail"] = {rate=0.590, enabled=false, priority=21},
        ["Beam"] = {rate=0.555, enabled=false, priority=20},
        ["Smoke"] = {rate=0.660, enabled=false, priority=19},
        ["Fire"] = {rate=0.625, enabled=false, priority=18},
        ["Sparkles"] = {rate=0.590, enabled=false, priority=17},
        ["PointLight"] = {rate=0.555, enabled=false, priority=16},
        ["SpotLight"] = {rate=0.660, enabled=false, priority=15},
        ["SurfaceLight"] = {rate=0.625, enabled=false, priority=14},
        ["BloomEffect"] = {rate=0.590, enabled=false, priority=13},
        ["BlurEffect"] = {rate=0.555, enabled=false, priority=12},
        ["ColorCorrectionEffect"] = {rate=0.660, enabled=false, priority=11},
        ["SunRaysEffect"] = {rate=0.625, enabled=false, priority=10},
        ["DepthOfFieldEffect"] = {rate=0.590, enabled=false, priority=9},
        ["Atmosphere"] = {rate=0.555, enabled=false, priority=8},
    },
    ["EMERGENCY"] = {
        ["ParticleEmitter"] = {rate=0.455, enabled=false, priority=23},
        ["Trail"] = {rate=0.420, enabled=false, priority=22},
        ["Beam"] = {rate=0.385, enabled=false, priority=21},
        ["Smoke"] = {rate=0.490, enabled=false, priority=20},
        ["Fire"] = {rate=0.455, enabled=false, priority=19},
        ["Sparkles"] = {rate=0.420, enabled=false, priority=18},
        ["PointLight"] = {rate=0.385, enabled=false, priority=17},
        ["SpotLight"] = {rate=0.490, enabled=false, priority=16},
        ["SurfaceLight"] = {rate=0.455, enabled=false, priority=15},
        ["BloomEffect"] = {rate=0.420, enabled=false, priority=14},
        ["BlurEffect"] = {rate=0.385, enabled=false, priority=13},
        ["ColorCorrectionEffect"] = {rate=0.490, enabled=false, priority=12},
        ["SunRaysEffect"] = {rate=0.455, enabled=false, priority=11},
        ["DepthOfFieldEffect"] = {rate=0.420, enabled=false, priority=10},
        ["Atmosphere"] = {rate=0.385, enabled=false, priority=9},
    },
    ["POTATO"] = {
        ["ParticleEmitter"] = {rate=0.285, enabled=false, priority=24},
        ["Trail"] = {rate=0.250, enabled=false, priority=23},
        ["Beam"] = {rate=0.215, enabled=false, priority=22},
        ["Smoke"] = {rate=0.320, enabled=false, priority=21},
        ["Fire"] = {rate=0.285, enabled=false, priority=20},
        ["Sparkles"] = {rate=0.250, enabled=false, priority=19},
        ["PointLight"] = {rate=0.215, enabled=false, priority=18},
        ["SpotLight"] = {rate=0.320, enabled=false, priority=17},
        ["SurfaceLight"] = {rate=0.285, enabled=false, priority=16},
        ["BloomEffect"] = {rate=0.250, enabled=false, priority=15},
        ["BlurEffect"] = {rate=0.215, enabled=false, priority=14},
        ["ColorCorrectionEffect"] = {rate=0.320, enabled=false, priority=13},
        ["SunRaysEffect"] = {rate=0.285, enabled=false, priority=12},
        ["DepthOfFieldEffect"] = {rate=0.250, enabled=false, priority=11},
        ["Atmosphere"] = {rate=0.215, enabled=false, priority=10},
    },
}


local function ultraTuning(profile, className)
    local p = ULTRA_TUNING[profile]
    if not p then return nil end
    return p[className]
end

local function ultraApplyTuning(instance, profile)
    if not instance then return false end
    local className = ultraSafe(function() return instance.ClassName end, "")
    local t = ultraTuning(profile, className)
    if not t then return false end

    if className == "ParticleEmitter" then
        return ultraScaleEmitter(instance, t.rate)
    elseif className == "PointLight"
        or className == "SpotLight"
        or className == "SurfaceLight" then
        return ultraScaleLight(instance, t.rate)
    elseif className == "Beam" then
        return ultraScaleBeam(instance, t.rate)
    end

    if t.enabled == false then
        ultraCapture(instance, "Enabled")
        return ultraSetCached(instance, "Enabled", false)
    end

    return false
end

-- Expose a tiny internal control surface for the existing engine.
local function ultraGetStatus()
    return {
        version = ULTRA.version,
        pressure = ULTRA.pressure,
        quality = ULTRA.quality,
        recovery = ULTRA.recovery,
        frameEMA = ULTRA.emaFrame,
        jitter = ULTRA.emaJitter,
        writes = ULTRA.writes,
        skippedWrites = ULTRA.skippedWrites,
        errors = ULTRA.errors,
        registrySweep = ULTRA.registrySweep,
        profile = ULTRA_PROFILE.mobile and "MOBILE" or "DESKTOP",
    }
end

