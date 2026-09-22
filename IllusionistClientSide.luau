-- Connected Discord-GitHub | Discord: B1rdal | GitHub: B1rdal | Roblox: B1rdal

local Class = "Illusionist" -- Class used for this ability

----------------------//Service\\----------------------
local Services = {
	Debris = game:GetService("Debris"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	StarterPlayer = game:GetService("StarterPlayer"),
	UserInputService = game:GetService("UserInputService"),
	RunService = game:GetService("RunService")
}
local starterPlayerScripts = Services.StarterPlayer:FindFirstChild("StarterPlayerScripts")

----------------------//Visual Mesh\\----------------------
local resources = Services.ReplicatedStorage:FindFirstChild("Meshes") -- Get the shared meshes
if not resources then return end -- Stop if the meshes are missing
local PROJECTILESFOLDER = Services.ReplicatedStorage:WaitForChild("CLIENTACCESS"):WaitForChild("CLASSES"):WaitForChild(Class)
	:WaitForChild("PROJECTILES")-- Get the class' projectiles folider

----------------------//STATS\\----------------------
---------Q----------
local QStats = {
	CD = .1,
	Damage = 10,
	MaxTarget = 8,
	Range = 30,
	Radius = 12,
	TPRange = 25,
	MovementDelay = 0.6,
}

----------------------//Remotes\\----------------------
local Remote = Services.ReplicatedStorage:WaitForChild("REMOTES"):WaitForChild("ServerRemote") -- Main server remote
local Damage = Services.ReplicatedStorage.REMOTES:WaitForChild("DamageRemote") -- Sends damage to the server
local RemoteProjectile = Services.ReplicatedStorage.REMOTES:WaitForChild("ProjectileServer") -- Sends replicated projectile 

----------------------//Values \\----------------------

local abilityDebounce = {
	LMBdoing = false,
	Qdoing = false,
	Edoing = false,
	Fdoing = false,
	Rdoing = false,
}
local cooldownEnds = {
	LMB = 0,
	Q = 0,
}

local cooldownVersions = {
	LMB = 0,
	Q = 0,
}

local anim = 1
local dashposition = "Forward"
local dashside = "None"

local player = game.Players.LocalPlayer -- Get local player
local character = player.Character or player.CharacterAdded:Wait() -- Wait for the character
local h = character:WaitForChild("Humanoid") -- Get the Humanoid
local Root = character:WaitForChild("HumanoidRootPart") -- Get the root part
local animator = h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator") -- Get the animator

local uiFrame = script.Parent

--Cache animations
local LMBANIM1 = animator:LoadAnimation(uiFrame.LMBANIM1)
local LMBANIM2 = animator:LoadAnimation(uiFrame.LMBANIM2)
local QANIM = animator:LoadAnimation(uiFrame.QANIM)

local LMBAnimations = {LMBANIM1, LMBANIM2} -- Keep both LMB animations together.


----------------------//SOUNDS\\----------------------
local abilitySounds = {
	LMB = 213603013,
	DASH = 506273075,
	QLMB = 850175467,
	QAB = 260433768,
	F = 201858072,
	R = 201858072,
}

--[[
To play ability sounds locally
sounds(character.HumanoidRootPart,"rbxassetid://157878578",1.4,2)

@param Par: Where the sound will be parented
@param id: The sound ID to play
@param vol: The volume of the sound
@param pit: The playback speed of the sound
]]
local function sounds(Par,id,vol,pit)
	local sound = Instance.new("Sound") -- Create the sound

	sound.Parent = Par -- Put it on the given part
	sound.SoundId = id
	sound.Volume = vol
	sound.PlaybackSpeed = pit

	sound:Play() -- Play the sound

	Services.Debris:AddItem(sound,5) -- Remove it after a few seconds

	return sound
end

----------------------//GENERAL FUNCTIONS\\----------------------

-- Find the model that owns the hit part.
local function getHumanoidTarget(instance)
	local current = instance -- Start from the hit part

	while current and current ~= workspace do -- Check parents until Workspace
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid") -- Look for a Humanoid

			if humanoid then
				return current,humanoid
			end
		end

		current = current.Parent -- Move up one parent
	end

	return nil,nil
end

-- Check if an ability is cooling down
local function isOnCooldown(action)
	return os.clock() < (cooldownEnds[action] or 0) -- Check if the cooldown is still active
end

-- Handle the cooldown and its UI.
local function startCooldown(action,cooldownTime)
	local cooldownFrame = uiFrame[action].Cooldown -- Get this ability cooldown UI
	local cooldownValue = cooldownFrame.CD

	local newCooldownEnd = os.clock() + cooldownTime -- Time the cooldown should end

	cooldownEnds[action] = math.max(cooldownEnds[action] or 0,newCooldownEnd) -- Do not shorten an existing cooldown

	cooldownVersions[action] += 1 -- Mark this as the newest cooldown

	local version = cooldownVersions[action]

	cooldownFrame.Visible = true -- Show the cooldown

	task.spawn(function()
		while version == cooldownVersions[action] do
			local remaining = cooldownEnds[action] - os.clock() -- Time left

			if remaining <= 0 then
				break --Stop the loop if cooldown is over
			end

			cooldownValue.Value = remaining
			cooldownFrame.Text = string.format("%.1f",remaining) -- Show one decimal place

			task.wait(.1) -- Update every 0.1 seconds
		end

		if version ~= cooldownVersions[action] then
			return -- exit if the verison is outdated
		end

		cooldownEnds[action] = 0
		cooldownValue.Value = 0
		cooldownFrame.Text = action -- Put the ability name back
	end)
end

--------------------------//Q\\--------------------------

-- Find where Q should land.
local function getQFinalPosition()
	local rootCFrame = character.HumanoidRootPart.CFrame -- Save the current position

	local moveRayParams = RaycastParams.new() -- Setup the raycast filter

	moveRayParams.FilterDescendantsInstances = {
		character,
		workspace.GameplayProjectiles
	}

	moveRayParams.FilterType = Enum.RaycastFilterType.Exclude
	moveRayParams.IgnoreWater = true

	local moveRayResult = workspace:Raycast(rootCFrame.Position,rootCFrame.LookVector * QStats.TPRange,moveRayParams) -- Check for a wall

	local finalPosition = rootCFrame.Position + (rootCFrame.LookVector * QStats.TPRange) -- Start with the full dash range

	if moveRayResult then
		local distance = (moveRayResult.Position - rootCFrame.Position).Magnitude
		local safeDistance = math.max(0,distance - 2) -- Stop a little before the wall

		finalPosition = rootCFrame.Position + (rootCFrame.LookVector * safeDistance) --Update final position
	end

	local groundRayResult = workspace:Raycast(finalPosition + Vector3.new(0,5,0),Vector3.new(0,-15,0),moveRayParams) -- Check for the ground

	if groundRayResult then
		finalPosition = Vector3.new(finalPosition.X,groundRayResult.Position.Y + .5,finalPosition.Z) --Update final position
	end

	return finalPosition
end

-- Show Q landing position
local function createQIndicator(finalPosition)
	local scaleConversion = 3

	local initialBullet = Services.ReplicatedStorage.Meshes.FlatCircle:Clone() -- Create the landing marker

	initialBullet.CFrame = CFrame.new(finalPosition)
	initialBullet.Material = Enum.Material.Neon
	initialBullet.Transparency = .8
	initialBullet.CanCollide = false
	initialBullet.Anchored = true
	initialBullet.Name = "Illu_Predict"

	if initialBullet:FindFirstChild("Mesh") then
		initialBullet.Mesh.Scale = Vector3.new(QStats.Radius * scaleConversion,1,QStats.Radius * scaleConversion) -- Match the Q radius
	end

	initialBullet.TopSurface = Enum.SurfaceType.Smooth
	initialBullet.BottomSurface = Enum.SurfaceType.Smooth
	initialBullet.Parent = workspace.GameplayProjectiles

	Services.Debris:AddItem(initialBullet,2) -- Remove the marker later

	return initialBullet
end

-- Move the player to the Q position.
local function moveCharacterToQPosition(finalPosition)
	local root = character.HumanoidRootPart

	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0,velocity.Y,0) -- Clear horizontal momentum
	root.AssemblyAngularVelocity = Vector3.zero

	local attachment = Instance.new("Attachment") -- Attachment used for movement

	attachment.Name = "QMovementAttachment"
	attachment.Parent = root

	local alignPosition = Instance.new("AlignPosition") -- Pull the player to the target

	alignPosition.Name = "QMovement"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.Position = finalPosition + Vector3.new(0,2.5,0) -- Set the dash destination
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.RigidityEnabled = false
	alignPosition.MaxForce = 545000
	alignPosition.MaxVelocity = 200 -- Limit dash speed
	alignPosition.Responsiveness = 100 -- Make the dash react quickly
	alignPosition.Parent = root

	task.delay(.1,function() -- Clean up after the dash
		if alignPosition.Parent then
			alignPosition:Destroy()
		end

		if attachment.Parent then
			attachment:Destroy()
		end

		if root.Parent then
			local currentVelocity = root.AssemblyLinearVelocity
			-- Reset the player's velocity
			root.AssemblyLinearVelocity = Vector3.new(0,currentVelocity.Y,0)
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- Create the Q explosion effect
local function createQExplosion(finalPosition)
	local scaleConversion = 3 -- Conversion for the visual

	local explosion = Services.ReplicatedStorage.Meshes.Part:Clone() -- Create the explosion effect

	explosion.Parent = character.Effect -- Parent to the Effect folder
	explosion.Name = "ExplosionCircle"

	explosion.Size = Vector3.new(0,0,0)
	explosion.BrickColor = BrickColor.new("Cool yellow")
	explosion.Material = Enum.Material.Neon
	explosion.Transparency = .25
	explosion.CanCollide = false
	explosion.Anchored = true
	explosion.CFrame = CFrame.new(finalPosition)

	local explosionMesh = Instance.new("SpecialMesh") -- Make the effect round

	explosionMesh.MeshType = Enum.MeshType.Sphere
	explosionMesh.Scale = Vector3.new(1,1,1)
	explosionMesh.Parent = explosion

	Services.Debris:AddItem(explosion,1) -- Clean it up after a second

	-- (Better to use TweenService here)
	task.spawn(function()
		for i = 1,20 do -- Grow and fade the effect
			if not explosion.Parent then
				return -- Stops if the character doesn't exisdt
			end

			task.wait()

			local size = QStats.Radius * scaleConversion * (i / 20) -- Increass sieze per loop

			explosion.Size = Vector3.new(size,size,size)
			explosion.Transparency += .03
		end

		if explosion.Parent then
			explosion:Destroy()
		end
	end)

	return explosion
end

-- Damage enemies around Q
local function damageQTargets(finalPosition)
	local enemyFolder = workspace:FindFirstChild("Enemy") -- Get the enemy folder

	if not enemyFolder then
		return -- Stops if the character doesn't exist
	end

	local overlapParams = OverlapParams.new() -- Setup the radius search

	overlapParams.FilterDescendantsInstances = {enemyFolder} -- Whitelist the enemy's folder
	overlapParams.FilterType = Enum.RaycastFilterType.Include -- Whitelist

	local radius = QStats.Radius + 7

	local nearbyParts = workspace:GetPartBoundsInRadius(finalPosition,radius,overlapParams) -- Find nearby enemy parts

	local damagedTargets = {} -- Remember enemies already hit
	local targetCount = 0 -- Track how many enemies were hit

	for _,part in ipairs(nearbyParts) do
		if targetCount >= QStats.MaxTarget then -- Stop at the target limit
			break
		end

		local target,targetHumanoid = getHumanoidTarget(part) -- Check for valid target with Humanoid
		
		if not target then  
			continue
		end

		if not targetHumanoid then
			continue
		end

		if damagedTargets[target] then -- Skip enemies already hit
			continue
		end

		if not target:IsDescendantOf(enemyFolder) then -- Skip if target is outside of enemy's folder
			continue
		end

		if targetHumanoid.Health <= 0 then
			continue -- Skip if target is dead
		end

		damagedTargets[target] = true -- Mark this enemy as hit
		targetCount += 1 -- Count the hit
		
		-- Compile data to send to the server
		local damageData = {
			Type = "Area",
			Name = "IllusionistQDMG",
			Class = "Illusionist",
			action = nil,

			Damage = QStats.Damage,
			Velocity = nil,
			Range = QStats.Range,
			Radius = QStats.Radius,

			Target = target,

			statusEffect = {"StatusEffect"},
			hitEffect = {"HitEffect"},

			Duration = 0,
		}

		Damage:FireServer(damageData) -- Send the damage to the server to compare
	end
end

-- Use the Q ability
local function QFire()
	for _,animTrack in ipairs(LMBAnimations) do -- Check both LMB animations.
		if animTrack.IsPlaying then -- if the animation is playing
			animTrack:Stop(.1) -- Stop the LMB animation
		end
	end

	QANIM:Play() -- Play the Q animation

	uiFrame.Doing.Value = true -- Lock other abilities

	local finalPosition = getQFinalPosition() -- Get the dash destination

	local initialBullet = createQIndicator(finalPosition) -- Show where Q will land

	task.delay(QStats.MovementDelay,function() -- Wait for the Q wind-up
		if h.Health <= 0 or not character.Parent then
			if initialBullet.Parent then
				initialBullet:Destroy()
			end

			uiFrame.Doing.Value = false
			return
		end

		moveCharacterToQPosition(finalPosition) -- Dash to the saved position

		if initialBullet.Parent then
			initialBullet:Destroy()
		end

		sounds(character.HumanoidRootPart,"rbxassetid://" .. abilitySounds.QAB,7,1)

		createQExplosion(finalPosition) -- Create the landing effect

		damageQTargets(finalPosition) -- Damage nearby enemies

		task.delay(.5,function()
			if uiFrame.Parent then
				uiFrame.Doing.Value = false
			end
		end)
	end)
end

-- Handle Q cooldown
local function Qcooldown()
	startCooldown("Q",QStats.CD) -- Start Q cooldown
end

------------------------//ACTIVATED FUNCTIONS\\--------------------------------

-- Run the shared ability checks.
local function inputHandler(action,cooldown,fireFunc)
	local debounceName = action .. "doing" -- Get this ability debounce.

	if uiFrame.Doing.Value then -- Another ability is already running
		return
	end

	if abilityDebounce[debounceName] then -- Stop duplicate activations
		return
	end

	if isOnCooldown(action) then -- Stop if it is on cooldown
		return
	end

	if h.PlatformStand then -- Do not use abilities while stunned
		return
	end

	if h.Health <= 0 then -- Stop if the player is dead
		return
	end

	abilityDebounce[debounceName] = true -- Lock this ability

	fireFunc() -- Use the ability
	cooldown() -- Start its cooldown

	abilityDebounce[debounceName] = false -- Unlock the ability
end

Services.UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed then -- Ignore input already used by the UI
		return
	end
	
	if not player.Character then -- Prevent usage if character doesn't exist
		return
	end
	
	if input.KeyCode == Enum.KeyCode.Q then -- Q pressed
		inputHandler("Q",Qcooldown,QFire) -- Try to use Q
		return
	end


	if input.KeyCode == Enum.KeyCode.A then -- Moving left
		dashside = "Left"
	elseif input.KeyCode == Enum.KeyCode.D then -- Moving right
		dashside = "Right"
	elseif input.KeyCode == Enum.KeyCode.W then -- Moving forward
		dashposition = "Forward"
	elseif input.KeyCode == Enum.KeyCode.S then -- Moving backward
		dashposition = "Backward"
	end

end)

Services.UserInputService.InputEnded:Connect(function(input)

	if not player.Character then -- Prevent usage if character doesn't exist
		return
	end

	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then -- Left or right released
		dashside = "None"
	end

	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then -- Forward or backward released
		dashposition = "None"
	end
end)
