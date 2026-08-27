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
local resources = Services.ReplicatedStorage.Meshes
local PROJECTILESFOLDER = Services.ReplicatedStorage:FindFirstChild("CLIENTACCESS").CLASSES[Class].PROJECTILES


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
local QStats={
	CD=6,
	Damage=10,
	MaxTarget=8,
	Range=30,
	Radius=12,
	TPRange=25,
	MovementDelay=0.6,
}
----------------------//Remotes\\----------------------
local Remote = Services.ReplicatedStorage.REMOTES.ServerRemote
local Damage = Services.ReplicatedStorage.REMOTES.DamageRemote
local RemoteProjectile = Services.ReplicatedStorage.REMOTES.ProjectileServer

----------------------//Values \\----------------------
local abilityDebounce={
	LMBdoing = false,
	Qdoing = false,
	Edoing = false,
	Fdoing = false,
	Rdoing = false,
}

local ammo = 12
local anim = 1
local dashposition = "Forward"
local dashside = "None"



local player = game.Players.LocalPlayer
local character = player.Character
local h = character:WaitForChild("Humanoid")
local Root = character.HumanoidRootPart

local mouse = player:GetMouse()

if not character then return end

local uiFrame=script.Parent

-- Cache aniamtions
local LMBANIM1 = h:LoadAnimation(uiFrame.LMBANIM1)
local LMBANIM2 = h:LoadAnimation(uiFrame.LMBANIM2)
local LMBAnimations = {LMBANIM1, LMBANIM2}

QANIM = h:LoadAnimation(uiFrame.QANIM)
--TEMPLATE : Damage:FireServer(Type,name,class,nil,dmg,veloc,range,radius,effects,duration)

----------------------//SOUNDS\\----------------------
local abilitySounds={
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
function sounds(Par,id,vol,pit)
	local sound=Instance.new("Sound")
	sound.Parent=Par
	sound.SoundId=id
	sound.Volume=vol
	sound.PlaybackSpeed=pit
	sound:Play()
	Services.Debris:AddItem(sound,5)
	return sound
end




----------------------//LMB\\----------------------
function LMBFire()
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

	--Remote:FireServer("IllusionistLMB", "Illusionist", nil, LMBStats.Velocity, LMBStats.Range, nil, QLMB)
	sounds(character.HumanoidRootPart, "rbxassetid://" .. abilitySounds.QLMB, 10, 1.5)


	-- Create the local projectile visual
	local projectile = PROJECTILESFOLDER.attack
	local bullet = projectile:Clone()

	local projectileCFrame = character.HumanoidRootPart.CFrame * CFrame.new(0, 1, -4)

	bullet.Size = Vector3.new(2.5, 2.5, 2.5)
	bullet.CFrame = projectileCFrame
	bullet.Material = Enum.Material.Neon
	bullet.Transparency = 1
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

	-- Raycast hitbox to detect hits
	local function detectHit(position, lastPosition)
		if hitConfirmed then
			return true
		end

		local rayParams = RaycastParams.new()

		-- Ignore the shooter
		rayParams.FilterDescendantsInstances = {character}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local bulletSize = bullet.Size

		-- Create raycast offsets based on the projectile's size
		local offsets = {
			Vector3.new(0, 0, 0),                  -- Center
			Vector3.new(bulletSize.X / 2, 0, 0),   -- Right
			Vector3.new(-bulletSize.X / 2, 0, 0),  -- Left
			Vector3.new(0, bulletSize.Y / 2, 0),   -- Up
			Vector3.new(0, -bulletSize.Y / 2, 0),  -- Down
			Vector3.new(0, 0, bulletSize.Z / 2),   -- Forward
			Vector3.new(0, 0, -bulletSize.Z / 2),  -- Backward
		}

		-- Cast multiple rays to approximate the projectile's hitbox
		for _, offset in ipairs(offsets) do
			local result = workspace:Raycast(
				lastPosition + offset,
				position - lastPosition,
				rayParams
			)

			-- Detect valid hit target 
			if result then
				local hitInstance = result.Instance
				local hitTarget = nil

				if hitInstance.Parent:FindFirstChild("Humanoid") then
					hitTarget = hitInstance.Parent

				elseif hitInstance.Parent.Parent
					and hitInstance.Parent.Parent:FindFirstChild("Humanoid") then

					hitTarget = hitInstance.Parent.Parent
				end

				-- If it hits a humanoid target (and it's not the shooter)
				if hitTarget and not hitTarget:IsDescendantOf(character) then
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
				end

				-- Stop the projectile if it hits a solid object
				if hitInstance.CanCollide and hitInstance.Transparency < 1 then
					hitConfirmed = true
				end

				if hitConfirmed then
					bullet.Transparency = 1
					bullet.Anchored = true

					task.delay(0.1, function()
						if bullet then
							bullet:Destroy()
						end
					end)

					return true
				end
			end
		end

		return false
	end

	-- Value to track projectile movements
	local lastPosition = bullet.Position
	local distanceTraveled = 0


	-- Lock the direction when the projectile is fired
	local direction = projectileCFrame.LookVector

	local connection

	-- Projectile Movement
	connection = Services.RunService.Heartbeat:Connect(function(deltaTime)
		-- Cleanup if projectile is removed
		if not bullet.Parent then
			connection:Disconnect()
			return
		end

		-- Stop updating after a confirmed hit
		if hitConfirmed then
			connection:Disconnect()
			return
		end

		-- Calculate how far the projectile moves this frame
		local moveDistance = LMBStats.Velocity * deltaTime

		-- Prevent projectile moving further than range
		local remainingDistance = LMBStats.Range - distanceTraveled
		moveDistance = math.min(moveDistance, remainingDistance)

		local currentPosition = bullet.Position
		local newPosition = currentPosition + direction * moveDistance

		-- Raycast between the previous and new position
		if detectHit(newPosition, currentPosition) then
			connection:Disconnect()
			return
		end

		-- Move projectile
		bullet.CFrame = bullet.CFrame + direction * moveDistance

		lastPosition = newPosition
		distanceTraveled += moveDistance

		-- Cleanup when projectile reaches range
		if distanceTraveled >= LMBStats.Range then
			connection:Disconnect()
			bullet:Destroy()
		end
	end)
end

function LMBcooldown(addition)
	local cooldownFrame = uiFrame.LMB.Cooldown
	local cooldownValue = cooldownFrame.CD
	local cooldownTime = LMBStats.CD+addition

	-- Set Initial Values
	cooldownValue.Value = cooldownTime
	cooldownFrame.Visible = true

	-- Smooth Countdown Without Overloading the Game
	local startTime = tick() -- Get current time
	while tick() - startTime < cooldownTime do
		local remaining = cooldownTime - (tick() - startTime)
		if remaining <= 0 then break end

		cooldownValue.Value = remaining
		cooldownFrame.Text = string.format("%.1f", remaining) -- Keep 1 decimal place
		task.wait(0.1) -- Yield properly
	end

	-- Ensure Final Cleanup
	cooldownValue.Value = 0
	cooldownFrame.Text = "0"
	uiFrame.LMB.Cooldown.Text = "LMB"
end



--------------------------//Q\\--------------------------

function QFire()

	-- Stop any currently playing LMB attack animations
	for _, animTrack in ipairs(LMBAnimations) do
		if animTrack.IsPlaying then
			animTrack:Stop()
			wait(.1)
		end
	end

	-- Play Q ability animation
	QANIM:Play()

	-- Prevent other abilities/actions while Q is being performed
	uiFrame.Doing.Value = true

	-- Prevent the explosion from damaging more than one target
	local debounce = false

	-- Store current cast position
	local rootCFrame = character.HumanoidRootPart.CFrame

	-- Additional size for the tp indicator and explosion scale
	local scaleConversion = 3


	-- Check possible dash distance using raycast
	local moveRayParams = RaycastParams.new()
	moveRayParams.FilterDescendantsInstances = {character}
	moveRayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Cast forward to check whether an obstacle blocks the full dash distance
	local moveRayResult = workspace:Raycast(rootCFrame.Position,rootCFrame.LookVector * QStats.TPRange, moveRayParams)

	-- Default destination is the full teleport/dash range
	local finalPosition =rootCFrame.Position + (rootCFrame.LookVector * QStats.TPRange)

	-- Stop the dash at the first obstacle encountered
	if moveRayResult then
		finalPosition = moveRayResult.Position
	end

	-- Cast downward from the destination to place the character near the ground
	local groundRayResult = workspace:Raycast(finalPosition,Vector3.new(0, -10, 0), moveRayParams)

	if groundRayResult then
		finalPosition = Vector3.new(finalPosition.X, groundRayResult.Position.Y + .5, finalPosition.Z)
	end


	-- Ability Execution
	task.spawn(function()


		-- Create a warning circle showing where the movement burst will end
		local initialBullet = Services.ReplicatedStorage.Meshes.FlatCircle:Clone()
		initialBullet.CFrame = CFrame.new(finalPosition)
		initialBullet.Material = Enum.Material.Neon
		initialBullet.Transparency = 0.8
		initialBullet.CanCollide = false
		initialBullet.Anchored = true
		initialBullet.Name = "ExsapurosionQ"

		initialBullet.Mesh.Scale = Vector3.new(QStats.Radius * scaleConversion,1,QStats.Radius * scaleConversion)

		initialBullet.TopSurface = Enum.SurfaceType.Smooth
		initialBullet.BottomSurface = Enum.SurfaceType.Smooth
		initialBullet.Parent = workspace.GameplayProjectiles


		Services.Debris:AddItem(initialBullet, 2)


		-- Wait before moving the character to the marked location
		task.wait(QStats.MovementDelay)

		-- Dash 
		task.spawn(function()
			local b = Instance.new("BodyPosition")
			b.Parent = character.HumanoidRootPart

			b.P = 2000
			b.D = 100
			-- Dash and send slightly above to prevent clipping
			b.Position = finalPosition + Vector3.new(0, 2.5, 0)
			b.MaxForce = Vector3.new(545000, 545000, 545000)

			Services.Debris:AddItem(b, 0.1)
		end)


		-- Allow ability usage
		task.spawn(function()
			task.wait(0.5)
			uiFrame.Doing.Value = false
		end)


		-- Remove the destination marker once the movement burst begins
		initialBullet:Destroy()

		-- Play the Q explosion sound
		sounds(character.HumanoidRootPart,"rbxassetid://" .. abilitySounds.QAB,7,1)

		-- Create explosion visual
		local explosion =Services.ReplicatedStorage.Meshes.Part:Clone()

		explosion.Parent = character.Effect
		explosion.Name = "ExplosionCircle"

		-- Visual size init at size 0
		explosion.Size = Vector3.new(0, 0, 0)

		explosion.BrickColor = BrickColor.new("Cool yellow")
		explosion.Material = Enum.Material.Neon
		explosion.Transparency = 0.25
		explosion.CanCollide = false
		explosion.Anchored = true
		explosion.CFrame = CFrame.new(finalPosition)

		-- Make the explosion visual spherical
		local explosionMesh = Instance.new("SpecialMesh")
		explosionMesh.MeshType = Enum.MeshType.Sphere
		explosionMesh.Scale = Vector3.new(1, 1, 1)
		explosionMesh.Parent = explosion

		-- Safety cleanup for the explosion effect
		Services.Debris:AddItem(explosion, 1)


		-- Create explosion visual
		local hitbox = explosion:Clone()
		hitbox.Transparency = 1
		hitbox.Parent = workspace.GameplayProjectiles


		-- Explosion visual gradually expand and fade the explosion
		task.spawn(function()
			for i = 1, 20 do
				task.wait()

				explosion.Size = Vector3.new(QStats.Radius * scaleConversion * (i / 20), QStats.Radius * scaleConversion * (i / 20),QStats.Radius * scaleConversion * (i / 20))

				explosion.Transparency =explosion.Transparency + 0.03
			end

			explosion:Destroy()
		end)


		-- Repeatedly scan nearby enemies during the explosion window
		for _ = 1, QStats.MaxTarget do
			task.wait()

			-- Stop scanning after a target has already been hit
			if not debounce then
				local radius = QStats.Radius + 7

				for _, child in ipairs(workspace.Enemy:GetChildren()) do
					local humanoid = child:FindFirstChild("Humanoid")
					local torso = child:FindFirstChild("Torso")

					-- Check whether the target is inside the explosion radius
					if humanoid and torso and (explosion.Position - torso.Position).Magnitude <= radius and child ~= character then

						-- Prevent another target from being damaged by this cast
						debounce = true

						local damageData = {
							Type = "Area",
							Name = "IllusionistQDMG",
							Class = "Illusionist",
							action = nil,

							Damage = QStats.Damage,
							Velocity = nil,
							Range = QStats.Range,
							Radius = QStats.Radius,

							Target = child,

							statusEffect = {"StatusEffect"},
							hitEffect = {"HitEffect"},

							Duration = 0,
						}

						-- Send the detected hit to the server for validation/damage
						Damage:FireServer(damageData)

					end
				end
			end
		end
		
		-- Cleanup
		explosion:Destroy()
	end)
end



function Qcooldown()
	local cooldownFrame = uiFrame.Q.Cooldown
	local cooldownValue = cooldownFrame.CD
	local cooldownTime = QStats.CD

	-- Set Initial Values
	cooldownValue.Value = cooldownTime
	cooldownFrame.Visible = true
	
	-- Show LMB cooldown without stopping Q Cooldown
	task.spawn(function()
		LMBcooldown(1)
	end)
	local startTime = tick() -- Get current time
	while tick() - startTime < cooldownTime do
		local remaining = cooldownTime - (tick() - startTime)
		if remaining <= 0 then break end

		cooldownValue.Value = remaining
		cooldownFrame.Text = string.format("%.1f", remaining) -- Keep 1 decimal place
		task.wait(0.1) -- Yield properly
	end

	-- Ensure Final Cleanup
	cooldownValue.Value = 0
	cooldownFrame.Text = "0"
end

------------------------//ACTIVATED FUNCTIONS\\--------------------------------
local held = false -- For lmb held input

-- Used to activate ability and show the cooldown locally
-- @param action: The ability slot name
-- @param cooldown: The ability cooldown function
-- @param fireFunc: The ability activation function
-- @param doingFlag: Whether the ability is currently being performed
local function inputHandler(action, cooldown, fireFunc, doingFlag)
	if uiFrame[action]["Cooldown"].Text == action
		and not uiFrame.Doing.Value
		and not doingFlag then

		if not h.PlatformStand then
			doingFlag = true

			fireFunc()
			cooldown()

			uiFrame[action]["Cooldown"].Text = action

			doingFlag = false
		end
	end
end


-- Keyboard check for ability usage
mouse.KeyDown:Connect(function(k)
	if k == "q" then
		inputHandler("Q", Qcooldown, QFire, abilityDebounce.Qdoing)
	end

	--if k == "e" then inputHandler("E", Ecooldown, EFire, Edoing) end
	--if k == "r" then inputHandler("R", Rcooldown, RFire, Rdoing) end
	--if k == "f" then inputHandler("F", Fcooldown, FFire, Fdoing) end
end)

-- Check for hold input for LMB
mouse.Button1Down:Connect(function()
	held = true
	task.spawn(function()
		while held do
			if uiFrame.LMB.Cooldown.Text == "LMB" and not uiFrame.Doing.Value and not abilityDebounce.LMBdoing then
				abilityDebounce.LMBdoing = true	
				LMBFire()		
				LMBcooldown(0)
				abilityDebounce.LMBdoing = false
			end
			Services.RunService.Heartbeat:Wait() -- Uses frame-based waiting instead of busy looping
		end
	end)
end)

-- Check for release input for LMB
mouse.Button1Up:Connect(function() held = false end)


-- Movement key check for directional movement
Services.UserInputService.InputBegan:Connect(function(input)
	if player.Character then
		if input.KeyCode == Enum.KeyCode.A then dashside = "Left" end
		if input.KeyCode == Enum.KeyCode.D then dashside = "Right" end
		if input.KeyCode == Enum.KeyCode.W then dashposition = "Forward" end
		if input.KeyCode == Enum.KeyCode.S then dashposition = "Backward" end
	end
end)

-- Movement key release for directional movement
Services.UserInputService.InputEnded:Connect(function(input)
	if player.Character then
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then dashside = "None" end
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then dashposition = "None" end
	end
end)
