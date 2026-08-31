-- Connected Discord-GitHub | Discord: B1rdal | GitHub: B1rdal | Roblox: B1rdal

--Get class
local Class = "Illusionist"

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
local resources = Services.ReplicatedStorage:WaitForChild("Meshes")
local PROJECTILESFOLDER = Services.ReplicatedStorage:WaitForChild("CLIENTACCESS"):WaitForChild("CLASSES"):WaitForChild(Class):WaitForChild("PROJECTILES")

----------------------//STATS\\----------------------
--------LMB---------
local LMBStats = {
	CD = .8,
	Range = 40,
	Velocity = 50,
	Damage = 25,
	Radius = 5
}

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
local Remote = Services.ReplicatedStorage:WaitForChild("REMOTES"):WaitForChild("ServerRemote")
local Damage = Services.ReplicatedStorage.REMOTES:WaitForChild("DamageRemote")
local RemoteProjectile = Services.ReplicatedStorage.REMOTES:WaitForChild("ProjectileServer")

----------------------//Values \\----------------------
local abilityDebounce = {
	LMBdoing = false,
	Qdoing = false,
	Edoing = false,
	Fdoing = false,
	Rdoing = false,
}
--Cooldown tracker
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

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local h = character:WaitForChild("Humanoid")
local Root = character:WaitForChild("HumanoidRootPart")
local animator = h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator")

local uiFrame = script.Parent

-- Cache animations
local LMBANIM1 = animator:LoadAnimation(uiFrame.LMBANIM1)
local LMBANIM2 = animator:LoadAnimation(uiFrame.LMBANIM2)
local LMBAnimations = {LMBANIM1, LMBANIM2}

local QANIM = animator:LoadAnimation(uiFrame.QANIM)

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
	local sound = Instance.new("Sound")

	sound.Parent = Par
	sound.SoundId = id
	sound.Volume = vol
	sound.PlaybackSpeed = pit

	sound:Play()

	Services.Debris:AddItem(sound,5)

	return sound
end

----------------------//GENERAL FUNCTIONS\\----------------------

-- Find the model containing a humanoid without assuming
-- the hit part is exactly one or two parents deep
local function getHumanoidTarget(instance)
	local current = instance

	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")

			if humanoid then
				return current,humanoid
			end
		end

		current = current.Parent
	end

	return nil,nil
end

-- Check whether an ability is currently on cooldown
local function isOnCooldown(action)
	return os.clock() < (cooldownEnds[action] or 0)
end

-- Cooldown UI visual + Cooldown Handler
local function startCooldown(action,cooldownTime)
	local cooldownFrame = uiFrame[action].Cooldown
	local cooldownValue = cooldownFrame.CD

	local newCooldownEnd = os.clock() + cooldownTime

	-- Do not shorten an existing cooldown
	cooldownEnds[action] = math.max(cooldownEnds[action] or 0,newCooldownEnd)

	cooldownVersions[action] += 1

	local version = cooldownVersions[action]

	cooldownFrame.Visible = true

	task.spawn(function()
		while version == cooldownVersions[action] do
			local remaining = cooldownEnds[action] - os.clock()

			if remaining <= 0 then
				break
			end

			cooldownValue.Value = remaining
			cooldownFrame.Text = string.format("%.1f",remaining)

			task.wait(.1)
		end

		-- A newer cooldown replaced this one
		if version ~= cooldownVersions[action] then
			return
		end

		cooldownEnds[action] = 0
		cooldownValue.Value = 0
		cooldownFrame.Text = action
	end)
end

----------------------//LMB\\----------------------

local function LMBFire()
	-- Animation Handling
	if anim == 1 then
		anim = 2

		LMBANIM1:Play()
		LMBANIM1:AdjustSpeed(1.25)

		task.wait(.2)
	else
		anim = 1

		LMBANIM2:Play()
		LMBANIM2:AdjustSpeed(1.25)

		task.wait(.1)
	end

	-- Stop if the character died during the attack animation
	if h.Health <= 0 then
		return
	end

	--Remote:FireServer("IllusionistLMB", "Illusionist", nil, LMBStats.Velocity, LMBStats.Range, nil, QLMB)
	sounds(character.HumanoidRootPart,"rbxassetid://" .. abilitySounds.QLMB,10,1.5)

	-- Create the local projectile visual
	local projectile = PROJECTILESFOLDER.attack
	local bullet = projectile:Clone()

	local projectileCFrame = character.HumanoidRootPart.CFrame * CFrame.new(0,1,-4)

	bullet.Size = Vector3.new(2.5,2.5,2.5)
	bullet.CFrame = projectileCFrame
	bullet.Material = Enum.Material.Neon
	bullet.Transparency = 0
	bullet.LocalTransparencyModifier = 0
	bullet.CanCollide = false
	bullet.Anchored = true
	bullet.Name = "Illusionist_Sphere"
	bullet.Parent = workspace.GameplayProjectiles

	-- Replicate projectile visual to other clients
	local projectileData = {
		Projectile = projectile,
		ProjectileCframe = projectileCFrame,
		ProjectileColor = "",
		ProjectileStats = LMBStats,
	}

	RemoteProjectile:FireServer(projectileData)

	-- Prevent this projectile from registering multiple hits
	local hitConfirmed = false

	-- Spherecast settings
	local rayParams = RaycastParams.new()

	rayParams.FilterDescendantsInstances = {
		character,
		workspace.GameplayProjectiles
	}

	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	-- Value to track projectile movement
	local distanceTraveled = 0

	-- Lock the direction when the projectile is fired
	local direction = projectileCFrame.LookVector

	local connection

	-- Clean projectile and disconnect Heartbeat
	local function cleanupProjectile()
		if connection then
			connection:Disconnect()
			connection = nil
		end

		if bullet and bullet.Parent then
			bullet:Destroy()
		end
	end

	-- Handle Spherecast hit
	local function detectHit(result)
		if not result then
			return false
		end

		local hitInstance = result.Instance
		local hitTarget,targetHumanoid = getHumanoidTarget(hitInstance)

		-- Detect valid humanoid target
		if hitTarget and targetHumanoid and hitTarget ~= character then
			if not hitTarget:IsDescendantOf(character) and targetHumanoid.Health > 0 then
				hitConfirmed = true

				local damageData = {
					Type = "Projectile",
					Name = "IllusionistLMB",
					Class = "Illusionist",
					action = nil,

					Damage = LMBStats.Damage,
					Velocity = nil,
					Range = LMBStats.Range,
					Radius = nil,

					Target = hitTarget,

					statusEffect = {"StatusEffect"},
					hitEffect = {"HitEffect"},

					Duration = 0,
				}

				-- Send data to the server to be compared with
				Damage:FireServer(damageData)

				return true
			end
		end

		-- Stop the projectile if it hits a solid object
		if hitInstance:IsA("BasePart") and hitInstance.CanCollide and hitInstance.Transparency < 1 then
			hitConfirmed = true

			return true
		end

		return false
	end

	-- Cleanup based on maximum projectile lifetime
	Services.Debris:AddItem(bullet,(LMBStats.Range / LMBStats.Velocity) + 1)

	-- Projectile Movement
	connection = Services.RunService.Heartbeat:Connect(function(deltaTime)
		-- Cleanup if projectile is removed
		if not bullet.Parent then
			cleanupProjectile()
			return
		end

		-- Stop updating after a confirmed hit
		if hitConfirmed then
			cleanupProjectile()
			return
		end

		-- Prevent projectile moving further than range
		local remainingDistance = LMBStats.Range - distanceTraveled

		if remainingDistance <= 0 then
			cleanupProjectile()
			return
		end

		-- Calculate how far the projectile moves this frame
		local moveDistance = math.min(LMBStats.Velocity * deltaTime,remainingDistance)
		local currentPosition = bullet.Position

		-- Spherecast to check for hits
		local result = workspace:Spherecast(currentPosition,bullet.Size.X * 0.5,direction * moveDistance,rayParams)

		if detectHit(result) then
			cleanupProjectile()
			return
		end

		-- Move projectile
		bullet.CFrame = bullet.CFrame + direction * moveDistance
		distanceTraveled += moveDistance

		-- Cleanup when projectile reaches range
		if distanceTraveled >= LMBStats.Range then
			cleanupProjectile()
		end
	end)
end

local function LMBcooldown(addition)
	startCooldown("LMB",LMBStats.CD + addition)
end

--------------------------//Q\\--------------------------

-- Calculate the dash position for the Q dash
local function getQFinalPosition()
	local rootCFrame = character.HumanoidRootPart.CFrame

	local moveRayParams = RaycastParams.new()

	moveRayParams.FilterDescendantsInstances = {
		character,
		workspace.GameplayProjectiles
	}

	moveRayParams.FilterType = Enum.RaycastFilterType.Exclude
	moveRayParams.IgnoreWater = true

	-- Cast forward to check whether an obstacle blocks the full dash distance
	local moveRayResult = workspace:Raycast(rootCFrame.Position,rootCFrame.LookVector * QStats.TPRange,moveRayParams)

	-- Default destination is the full dash range
	local finalPosition = rootCFrame.Position + (rootCFrame.LookVector * QStats.TPRange)

	-- Stop slightly before the first obstacle encountered
	if moveRayResult then
		local distance = (moveRayResult.Position - rootCFrame.Position).Magnitude
		local safeDistance = math.max(0,distance - 2)

		finalPosition = rootCFrame.Position + (rootCFrame.LookVector * safeDistance)
	end

	-- Cast downward from slightly above the destination
	local groundRayResult = workspace:Raycast(finalPosition + Vector3.new(0,5,0),Vector3.new(0,-15,0),moveRayParams)

	if groundRayResult then
		finalPosition = Vector3.new(finalPosition.X,groundRayResult.Position.Y + .5,finalPosition.Z)
	end

	return finalPosition
end

-- Create the predicted hitbox range
local function createQIndicator(finalPosition)
	-- To make it scale correctly with the hitbox
	local scaleConversion = 3

	local initialBullet = Services.ReplicatedStorage.Meshes.FlatCircle:Clone()

	initialBullet.CFrame = CFrame.new(finalPosition)
	initialBullet.Material = Enum.Material.Neon
	initialBullet.Transparency = .8
	initialBullet.CanCollide = false
	initialBullet.Anchored = true
	initialBullet.Name = "Illu_Predict"

	if initialBullet:FindFirstChild("Mesh") then
		initialBullet.Mesh.Scale = Vector3.new(QStats.Radius * scaleConversion,1,QStats.Radius * scaleConversion)
	end

	initialBullet.TopSurface = Enum.SurfaceType.Smooth
	initialBullet.BottomSurface = Enum.SurfaceType.Smooth
	initialBullet.Parent = workspace.GameplayProjectiles

	Services.Debris:AddItem(initialBullet,2)

	return initialBullet
end

-- Move the character using AlignPosition instead of BodyPosition
local function moveCharacterToQPosition(finalPosition)
	local root = character.HumanoidRootPart

	-- Remove existing horizontal momentum before starting the movement
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0,velocity.Y,0)
	root.AssemblyAngularVelocity = Vector3.zero

	local attachment = Instance.new("Attachment")

	attachment.Name = "QMovementAttachment"
	attachment.Parent = root

	local alignPosition = Instance.new("AlignPosition")

	alignPosition.Name = "QMovement"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.Position = finalPosition + Vector3.new(0,2.5,0)
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.RigidityEnabled = false
	alignPosition.MaxForce = 545000
	alignPosition.MaxVelocity = 200
	alignPosition.Responsiveness = 100
	alignPosition.Parent = root

	-- Remove Q movement momentum once the dash finishes
	task.delay(.1,function()
		if alignPosition.Parent then
			alignPosition:Destroy()
		end

		if attachment.Parent then
			attachment:Destroy()
		end

		if root.Parent then
			local currentVelocity = root.AssemblyLinearVelocity

			root.AssemblyLinearVelocity = Vector3.new(0,currentVelocity.Y,0)
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- Q Explosion visual
local function createQExplosion(finalPosition)
	local scaleConversion = 3

	local explosion = Services.ReplicatedStorage.Meshes.Part:Clone()

	explosion.Parent = character.Effect
	explosion.Name = "ExplosionCircle"

	explosion.Size = Vector3.new(0,0,0)
	explosion.BrickColor = BrickColor.new("Cool yellow")
	explosion.Material = Enum.Material.Neon
	explosion.Transparency = .25
	explosion.CanCollide = false
	explosion.Anchored = true
	explosion.CFrame = CFrame.new(finalPosition)

	-- Make the explosion visual spherical
	local explosionMesh = Instance.new("SpecialMesh")

	explosionMesh.MeshType = Enum.MeshType.Sphere
	explosionMesh.Scale = Vector3.new(1,1,1)
	explosionMesh.Parent = explosion

	-- Cleanup
	Services.Debris:AddItem(explosion,1)

	-- Explosion visual gradually expands and fades
	task.spawn(function()
		for i = 1,20 do
			if not explosion.Parent then
				return
			end

			task.wait()

			local size = QStats.Radius * scaleConversion * (i / 20)

			explosion.Size = Vector3.new(size,size,size)
			explosion.Transparency += .03
		end

		if explosion.Parent then
			explosion:Destroy()
		end
	end)

	return explosion
end

-- Damage up to QStats.MaxTarget unique enemies
local function damageQTargets(finalPosition)
	local enemyFolder = workspace:FindFirstChild("Enemy")

	if not enemyFolder then
		return
	end

	local overlapParams = OverlapParams.new()

	overlapParams.FilterDescendantsInstances = {enemyFolder}
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	
	local radius = QStats.Radius + 7

	-- Find all nearby enemy parts with one spatial query
	local nearbyParts = workspace:GetPartBoundsInRadius(finalPosition,radius,overlapParams)

	-- Reset state per cast
	local damagedTargets = {}
	local targetCount = 0

	for _,part in ipairs(nearbyParts) do
		if targetCount >= QStats.MaxTarget then
			break
		end

		local target,targetHumanoid = getHumanoidTarget(part)

		if not target then
			continue
		end

		if not targetHumanoid then
			continue
		end

		if damagedTargets[target] then
			continue
		end

		if not target:IsDescendantOf(enemyFolder) then
			continue
		end

		if targetHumanoid.Health <= 0 then
			continue
		end
		
		
		damagedTargets[target] = true
		targetCount += 1
		
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

		-- Send data to the server to be compared with
		Damage:FireServer(damageData)
	end
end

local function QFire()
	-- Stop any currently playing LMB attack animations
	for _,animTrack in ipairs(LMBAnimations) do
		if animTrack.IsPlaying then
			animTrack:Stop(.1)
		end
	end

	-- Play Q ability animation
	QANIM:Play()

	-- Prevent other abilities/actions while Q is being performed
	uiFrame.Doing.Value = true

	-- Calculate the cast destination once
	local finalPosition = getQFinalPosition()

	-- Create a prediction circle showing where the movement burst will end
	local initialBullet = createQIndicator(finalPosition)

	-- Wait before moving the character to the marked location
	task.delay(QStats.MovementDelay,function()
		-- Stop if the character died before Q activated
		if h.Health <= 0 or not character.Parent then
			if initialBullet.Parent then
				initialBullet:Destroy()
			end

			uiFrame.Doing.Value = false
			return
		end

		-- Dash
		moveCharacterToQPosition(finalPosition)

		-- Remove the destination marker once the movement burst begins
		if initialBullet.Parent then
			initialBullet:Destroy()
		end

		-- Play the Q explosion sound
		sounds(character.HumanoidRootPart,"rbxassetid://" .. abilitySounds.QAB,7,1)

		-- Create explosion visual
		createQExplosion(finalPosition)

		-- Damage nearby enemies
		damageQTargets(finalPosition)

		-- Allow ability usage again
		task.delay(.5,function()
			if uiFrame.Parent then
				uiFrame.Doing.Value = false
			end
		end)
	end)
end

local function Qcooldown()
	startCooldown("Q",QStats.CD)

	-- Show LMB cooldown without stopping Q Cooldown
	LMBcooldown(1)
end

------------------------//ACTIVATED FUNCTIONS\\--------------------------------

local held = false -- For lmb held input

-- Used to activate ability and show the cooldown locally
-- @param action: The ability slot name
-- @param cooldown: The ability cooldown function
-- @param fireFunc: The ability activation function
local function inputHandler(action,cooldown,fireFunc)
	local debounceName = action .. "doing"

	if uiFrame.Doing.Value then
		return
	end

	if abilityDebounce[debounceName] then
		return
	end

	if isOnCooldown(action) then
		return
	end

	if h.PlatformStand then
		return
	end

	if h.Health <= 0 then
		return
	end

	abilityDebounce[debounceName] = true

	fireFunc()
	cooldown()

	abilityDebounce[debounceName] = false
end

-- Keyboard and mouse check for ability usage
Services.UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed then
		return
	end

	-- Q ability
	if input.KeyCode == Enum.KeyCode.Q then
		inputHandler("Q",Qcooldown,QFire)
		return
	end

	-- LMB held input
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if held then
			return
		end

		held = true

		task.spawn(function()
			while held do
				if h.Health <= 0 then
					held = false
					break
				end

				inputHandler("LMB",function()
					LMBcooldown(0)
				end,LMBFire)

				Services.RunService.Heartbeat:Wait()
			end
		end)

		return
	end

	-- Movement key check for directional movement
	if not player.Character then
		return
	end

	if input.KeyCode == Enum.KeyCode.A then
		dashside = "Left"
	elseif input.KeyCode == Enum.KeyCode.D then
		dashside = "Right"
	elseif input.KeyCode == Enum.KeyCode.W then
		dashposition = "Forward"
	elseif input.KeyCode == Enum.KeyCode.S then
		dashposition = "Backward"
	end

end)

-- Check for release input for LMB and movement key
Services.UserInputService.InputEnded:Connect(function(input)
	-- LMB release
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		held = false
	end

	-- Movement key release for directional movement
	if not player.Character then
		return
	end

	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
		dashside = "None"
	end

	if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then
		dashposition = "None"
	end
end)
