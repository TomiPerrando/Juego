Enemies = require "enemies"
anim8 = require 'libraries.anim8'
sti = require 'libraries.sti'
bf = require 'libraries.breezefield'
Weapons = require "weapons"

scale = 6.75

print("================Iniciando juego================")    

local GAMEPAD_DEADZONE = 0.25
local DEBUG_TIME_SCALE = 1
local DEBUG_TIME_SCALE_STEP = 0.1
local DEBUG_TIME_SCALE_MIN = 0.1
local DEBUG_TIME_SCALE_MAX = 2
local DASH_DURATION = 0.12
local DASH_SPEED = 750
local DASH_COOLDOWN = 0.45
local GUARD_DASH_DURATION = 0.56
local GUARD_DASH_SPEED = 560
local DASH_DUST_FRAME_SIZE = 128
local DASH_DUST_FRAME_TIME = 0.04
local DASH_DUST_SCALE = 0.45
local WEAPON_CHANGE_DISPLAY_DURATION = 0.45
local BASE_PLAYER_FRAME_SIZE = 96
local BASE_PLAYER_DRAW_SCALE = 2.0
local BASE_PLAYER_DRAW_ORIGIN_X = 48
local BASE_PLAYER_DRAW_ORIGIN_Y = 48
local SWORD_FRAME_SIZE = 144
local SWORD_DRAW_SCALE = 1.5
local SWORD_DRAW_ORIGIN_X = 72
local SWORD_DRAW_ORIGIN_Y = 72
local SHIELD_FRAME_SIZE = 144
local SHIELD_DRAW_SCALE = 2.175
local SHIELD_DRAW_ORIGIN_X = 72
local SHIELD_DRAW_ORIGIN_Y = 72
local SHIELD_BLOCK_START_DURATION = 0.08
local SHIELD_CHARGE_START_DURATION = 0.10
local SHIELD_CHARGE_RECOVERY_DURATION = 0.08
local dashDustImage = nil
local dashDustQuads = {}
local dashDustEffects = {}

local function applyDeadzone(value)
    value = value or 0
    if math.abs(value) < GAMEPAD_DEADZONE then return 0 end
    return value
end

local function changeDebugTimeScale(delta)
    DEBUG_TIME_SCALE = math.max(
        DEBUG_TIME_SCALE_MIN,
        math.min(DEBUG_TIME_SCALE_MAX, DEBUG_TIME_SCALE + delta))
end

local function loadDashDustEffects()
    dashDustImage = love.graphics.newImage("sprites/effects/dash_dust_vfx2.png")
    dashDustQuads = {}

    for i = 0, 4 do
        table.insert(
            dashDustQuads,
            love.graphics.newQuad(
                i * DASH_DUST_FRAME_SIZE,
                0,
                DASH_DUST_FRAME_SIZE,
                DASH_DUST_FRAME_SIZE,
                dashDustImage:getWidth(),
                dashDustImage:getHeight()))
    end
end

local function spawnDashDustEffect(player, angle)
    if not dashDustImage then return end

    table.insert(dashDustEffects, {
        x = player.x - math.cos(angle) * 10,
        y = player.y + (18 * scale) / 2,
        timer = 0
    })
end

local function updateDashDustEffects(dt)
    for i = #dashDustEffects, 1, -1 do
        local effect = dashDustEffects[i]
        effect.timer = effect.timer + dt

        if effect.timer >= #dashDustQuads * DASH_DUST_FRAME_TIME then
            table.remove(dashDustEffects, i)
        end
    end
end

local function drawDashDustEffects()
    if not dashDustImage then return end

    for _, effect in ipairs(dashDustEffects) do
        local frame = math.floor(effect.timer / DASH_DUST_FRAME_TIME) + 1
        frame = math.min(frame, #dashDustQuads)

        love.graphics.draw(
            dashDustImage,
            dashDustQuads[frame],
            effect.x,
            effect.y,
            nil,
            DASH_DUST_SCALE,
            DASH_DUST_SCALE,
            DASH_DUST_FRAME_SIZE / 2,
            DASH_DUST_FRAME_SIZE / 2)
    end
end

local function updateDash(player, dt, dashPressed, moveX, moveY, blockPressed)
    player.dashCooldownTimer = math.max(0, (player.dashCooldownTimer or 0) - dt)

    if dashPressed and not player.wasDashPressed and player.dashCooldownTimer <= 0 then
        local moveLength = math.sqrt(moveX^2 + moveY^2)
        player.dashAngle = moveLength > 0 and math.atan2(moveY, moveX) or getAttackAngle(player)
        local isGuardDash = player.currentWeapon == "shield" and blockPressed
        player.dashTime = isGuardDash and GUARD_DASH_DURATION or DASH_DURATION
        player.dashSpeed = isGuardDash and GUARD_DASH_SPEED or DASH_SPEED
        player.dashIsGuard = isGuardDash
        player.dashCooldownTimer = DASH_COOLDOWN
        if isGuardDash then
            local weapon = Weapons["shield"]
            weapon.attacks.guardDash:execute(player, world, player.dashAngle)
            player.shieldChargeStartTimer = SHIELD_CHARGE_START_DURATION
            player.shieldChargeRecoveryTimer = 0
        end
        spawnDashDustEffect(player, player.dashAngle)
    end
    player.wasDashPressed = dashPressed

    if player.dashTime and player.dashTime > 0 then
        player.dashTime = math.max(0, player.dashTime - dt)
        return math.cos(player.dashAngle) * player.dashSpeed, math.sin(player.dashAngle) * player.dashSpeed, true
    end

    if player.dashIsGuard then
        player.shieldChargeRecoveryTimer = SHIELD_CHARGE_RECOVERY_DURATION
    end
    player.dashIsGuard = false
    return moveX, moveY, false
end

local function getPlayer2Gamepad()
    if not player2 then return nil end
    if player2.gamepad then return player2.gamepad end

    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            player2.gamepad = joystick
            player2.aimAngle = player2.aimAngle or 0
            print("Player 2 gamepad:", joystick:getName())
            return joystick
        end
    end
end

local function ignoreEnemyBodyCollisionDuringGuardDash(player)
    function player.collider:preSolve(other, contact)
        if other.identity == "Enemy" and (player.guardDashProtectTimer or 0) > 0 then
            contact:setEnabled(false)
        end
    end
end

local function makeShieldDirectionAnimations(image, frameTime)
    local grid = anim8.newGrid(SHIELD_FRAME_SIZE, SHIELD_FRAME_SIZE, image:getWidth(), image:getHeight())

    return {
        down = anim8.newAnimation(grid('1-4', 1), frameTime),
        left = anim8.newAnimation(grid('5-8', 1), frameTime),
        right = anim8.newAnimation(grid('9-12', 1), frameTime),
        up = anim8.newAnimation(grid('13-16', 1), frameTime)
    }
end

local function makeShieldBlockStartAnimations(image)
    local grid = anim8.newGrid(SHIELD_FRAME_SIZE, SHIELD_FRAME_SIZE, image:getWidth(), image:getHeight())

    return {
        down = anim8.newAnimation(grid('1-1', 1), SHIELD_BLOCK_START_DURATION),
        left = anim8.newAnimation(grid('5-5', 1), SHIELD_BLOCK_START_DURATION),
        right = anim8.newAnimation(grid('9-9', 1), SHIELD_BLOCK_START_DURATION),
        up = anim8.newAnimation(grid('13-13', 1), SHIELD_BLOCK_START_DURATION)
    }
end

local function makeShieldBlockLoopAnimations(image)
    local grid = anim8.newGrid(SHIELD_FRAME_SIZE, SHIELD_FRAME_SIZE, image:getWidth(), image:getHeight())

    return {
        down = anim8.newAnimation(grid('2-4', 1), 0.12),
        left = anim8.newAnimation(grid('6-8', 1), 0.12),
        right = anim8.newAnimation(grid('10-12', 1), 0.12),
        up = anim8.newAnimation(grid('14-16', 1), 0.12)
    }
end

local function makeSwordDirectionAnimations(image, frameTime)
    local grid = anim8.newGrid(SWORD_FRAME_SIZE, SWORD_FRAME_SIZE, image:getWidth(), image:getHeight())

    return {
        down = anim8.newAnimation(grid('1-4', 1), frameTime),
        left = anim8.newAnimation(grid('1-4', 2), frameTime),
        up = anim8.newAnimation(grid('1-4', 3), frameTime),
        right = anim8.newAnimation(grid('1-4', 4), frameTime)
    }
end

local function loadSwordPlayerSprites()
    local idleImage = love.graphics.newImage("sprites/Player/sword_idle.png")
    local runImage = love.graphics.newImage("sprites/Player/sword_run.png")
    local attackImage = love.graphics.newImage("sprites/Player/sword_attack.png")

    return {
        idle = {
            image = idleImage,
            animations = makeSwordDirectionAnimations(idleImage, 0.2)
        },
        run = {
            image = runImage,
            animations = makeSwordDirectionAnimations(runImage, 0.12)
        },
        attack = {
            image = attackImage,
            animations = makeSwordDirectionAnimations(attackImage, 0.03)
        }
    }
end

local function makeSingleDirectionAnimationsByFrames(image, frames, frameTime)
    local grid = anim8.newGrid(SHIELD_FRAME_SIZE, SHIELD_FRAME_SIZE, image:getWidth(), image:getHeight())
    local animation = anim8.newAnimation(grid(frames, 1), frameTime)

    return {
        down = animation,
        right = animation,
        left = animation,
        up = animation
    }
end

local function loadShieldPlayerSprites()
    local idleImage = love.graphics.newImage("sprites/Player/shield_idle.png")
    local runImage = love.graphics.newImage("sprites/Player/shield_run_WIP.png")
    local blockImage = love.graphics.newImage("sprites/Player/shield_block.png")
    local chargeImage = love.graphics.newImage("sprites/Player/shield_charge_test1-sheet.png")

    return {
        idle = {
            image = idleImage,
            animations = makeShieldDirectionAnimations(idleImage, 0.2)
        },
        run = {
            image = runImage,
            animations = makeShieldDirectionAnimations(runImage, 0.12)
        },
        blockStart = {
            image = blockImage,
            animations = makeShieldBlockStartAnimations(blockImage)
        },
        block = {
            image = blockImage,
            animations = makeShieldBlockLoopAnimations(blockImage)
        },
        chargeStart = {
            image = chargeImage,
            animations = makeSingleDirectionAnimationsByFrames(chargeImage, '1-2', 0.05)
        },
        chargeLoop = {
            image = chargeImage,
            animations = makeSingleDirectionAnimationsByFrames(chargeImage, '3-4', 0.05)
        },
        chargeRecovery = {
            image = chargeImage,
            animations = makeSingleDirectionAnimationsByFrames(chargeImage, '5-5', SHIELD_CHARGE_RECOVERY_DURATION)
        }
    }
end

local function makeBasePlayerAnimations(image, frameTime)
    local grid = anim8.newGrid(BASE_PLAYER_FRAME_SIZE, BASE_PLAYER_FRAME_SIZE, image:getWidth(), image:getHeight())
    return anim8.newAnimation(grid('1-2', 1), frameTime)
end

local function makeBasePlayerHandsAnimation(image, frameTime)
    local grid = anim8.newGrid(BASE_PLAYER_FRAME_SIZE, BASE_PLAYER_FRAME_SIZE, image:getWidth(), image:getHeight())
    return anim8.newAnimation(grid('1-4', 1), frameTime)
end

local function loadBasePlayerSprites()
    local idleImage = love.graphics.newImage("sprites/Player/new_animations/idle.png")
    local walkImage = love.graphics.newImage("sprites/Player/new_animations/walk.png")
    local walkHandsImage = love.graphics.newImage("sprites/Player/new_animations/walk_hands.png")

    return {
        idle = {
            image = idleImage,
            animation = makeBasePlayerAnimations(idleImage, 0.25)
        },
        walk = {
            image = walkImage,
            animation = makeBasePlayerAnimations(walkImage, 0.16)
        },
        walkHands = {
            image = walkHandsImage,
            animation = makeBasePlayerHandsAnimation(walkHandsImage, 0.16)
        }
    }
end

local function createPlayerAnimations(spriteSheet)
    local grid = anim8.newGrid(12, 18, spriteSheet:getWidth(), spriteSheet:getHeight())

    return grid, {
        down = anim8.newAnimation(grid('1-4', 1), 0.2),
        left = anim8.newAnimation(grid('1-4', 2), 0.2),
        right = anim8.newAnimation(grid('1-4', 3), 0.2),
        up = anim8.newAnimation(grid('1-4', 4), 0.2)
    }
end

local function selectPlayerDrawAnimation(player, isMoving, dt)
    if Weapons.swordUsesPlayerSprites() and player.currentWeapon == "sword" and player.swordSprites then
        local action = "idle"
        if (player.attackVisualTimer or 0) > 0 then
            action = "attack"
        elseif isMoving then
            action = "run"
        end

        local direction = player.facing or "down"
        local sprite = player.swordSprites[action]
        local animation = sprite.animations[direction]

        if player.drawAnim ~= animation then
            animation:gotoFrame(1)
        end

        player.drawSpriteSheet = sprite.image
        player.drawAnim = animation
        player.drawHandsSpriteSheet = nil
        player.drawHandsAnim = nil
        player.drawScaleX = SWORD_DRAW_SCALE
        player.drawScaleY = SWORD_DRAW_SCALE
        player.drawOriginX = SWORD_DRAW_ORIGIN_X
        player.drawOriginY = SWORD_DRAW_ORIGIN_Y
        return
    end

    if player.currentWeapon ~= "shield" or not player.shieldSprites then
        if player.baseSprites then
            local action = isMoving and "walk" or "idle"
            local sprite = player.baseSprites[action]

            if player.drawAnim ~= sprite.animation then
                sprite.animation:gotoFrame(1)
            end

            player.drawSpriteSheet = sprite.image
            player.drawAnim = sprite.animation
            player.drawHandsSpriteSheet = nil
            player.drawHandsAnim = nil
            if player.currentWeapon == "hands" and action == "walk" and player.baseSprites.walkHands then
                player.drawHandsSpriteSheet = player.baseSprites.walkHands.image
                player.drawHandsAnim = player.baseSprites.walkHands.animation
            end
            player.drawScaleX = BASE_PLAYER_DRAW_SCALE * (player.visualDirectionX or 1)
            player.drawScaleY = BASE_PLAYER_DRAW_SCALE
            player.drawOriginX = BASE_PLAYER_DRAW_ORIGIN_X
            player.drawOriginY = BASE_PLAYER_DRAW_ORIGIN_Y
        else
            player.drawSpriteSheet = player.spriteSheet
            player.drawAnim = player.anim
            player.drawHandsSpriteSheet = nil
            player.drawHandsAnim = nil
            player.drawScaleX = scale
            player.drawScaleY = scale
            player.drawOriginX = 6
            player.drawOriginY = 9
        end
        player.shieldDrawAction = nil
        return
    end

    local action = "idle"
    if (player.guardDashProtectTimer or 0) > 0 then
        if (player.shieldChargeStartTimer or 0) > 0 then
            action = "chargeStart"
            player.shieldChargeStartTimer = math.max(0, player.shieldChargeStartTimer - dt)
        else
            action = "chargeLoop"
        end
    elseif (player.shieldChargeRecoveryTimer or 0) > 0 then
        action = "chargeRecovery"
        player.shieldChargeRecoveryTimer = math.max(0, player.shieldChargeRecoveryTimer - dt)
    elseif player.shield and (player.shieldBlockStartTimer or 0) > 0 then
        action = "blockStart"
        player.shieldBlockStartTimer = math.max(0, player.shieldBlockStartTimer - dt)
    elseif player.shield then
        action = "block"
    elseif isMoving then
        action = "run"
    end

    local direction = player.facing or "down"
    local sprite = player.shieldSprites[action]
    local animation = sprite.animations[direction]

    if player.drawAnim ~= animation then
        animation:gotoFrame(1)
    end

    player.drawSpriteSheet = sprite.image
    player.drawAnim = animation
    player.drawHandsSpriteSheet = nil
    player.drawHandsAnim = nil
    player.drawScaleX = SHIELD_DRAW_SCALE
    player.drawScaleY = SHIELD_DRAW_SCALE
    player.drawOriginX = SHIELD_DRAW_ORIGIN_X
    player.drawOriginY = SHIELD_DRAW_ORIGIN_Y
    player.shieldDrawAction = action
end

local function stopBlocking(player)
    if not player.shield then return end

    print("DESTROYING SHIELD COLLIDER.")
    player.shield.collider:destroy()
    player.shield.dead = true
    player.shield = nil
    player.canAttack = true
    player.shieldBlockStartTimer = 0
end

local function getWeaponNumber(weaponName)
    if weaponName == "sword" then return "Sword" end
    if weaponName == "shield" then return "Shield" end
    if weaponName == "rifle" then return "Rifle" end
    if weaponName == "hands" then return "Hands" end
end

local function equipWeapon(player, weaponName)
    if player.currentWeapon == weaponName then return end

    if player.currentWeapon == "shield" then
        stopBlocking(player)
    end

    player.currentWeapon = weaponName
    player.weaponChangeText = getWeaponNumber(weaponName)
    player.weaponChangeTimer = WEAPON_CHANGE_DISPLAY_DURATION
end

local function updateWeaponSelection()
    local selectedWeapon = nil

    if love.keyboard.isDown("1") then
        selectedWeapon = "sword"
    elseif love.keyboard.isDown("2") then
        selectedWeapon = "shield"
    elseif love.keyboard.isDown("3") then
        selectedWeapon = "rifle"
    elseif love.keyboard.isDown("4") then
        selectedWeapon = "hands"
    end

    if not selectedWeapon then return end

    equipWeapon(player1, selectedWeapon)
    equipWeapon(player2, selectedWeapon)
end

local function updateAttackCooldown(player, dt)
    if player.canAttack then return end

    player.attackTime = player.attackTime - dt
    if player.attackTime <= 0 then
        player.canAttack = true
    end
end

local function updateShieldCounter(player, dt)
    if not player.shieldCounterTimer or player.shieldCounterTimer <= 0 then return end

    player.shieldCounterTimer = math.max(0, player.shieldCounterTimer - dt)
end

local function useShieldPrimary(player, primaryPressed, dt)
    local justPressed = primaryPressed and not player.wasPrimaryPressed
    local justReleased = not primaryPressed and player.wasPrimaryPressed
    local weapon = Weapons["shield"]

    if justPressed then
        player.primaryHoldTime = 0
        player.primaryChargedExecuted = false
    end

    if primaryPressed then
        player.primaryHoldTime = (player.primaryHoldTime or 0) + dt
        if not player.primaryChargedExecuted
            and player.primaryHoldTime >= weapon.attacks.chargedSlam.holdTime
            and player.canAttack then
            stopBlocking(player)
            weapon.attacks.chargedSlam:execute(player, world)
            player.canAttack = false
            player.attackTime = weapon.attacks.chargedSlam.cooldown
            player.primaryChargedExecuted = true
        end
    elseif justReleased and not player.primaryChargedExecuted and player.canAttack then
        stopBlocking(player)
        if player.shieldCounterTimer and player.shieldCounterTimer > 0 then
            weapon.attacks.counter:execute(player, world)
            player.shieldCounterTimer = 0
            player.attackTime = weapon.attacks.counter.cooldown
        else
            weapon.attacks.bash:execute(player, world)
            player.attackTime = weapon.cooldown
        end
        player.canAttack = false
    end

    player.wasPrimaryPressed = primaryPressed
end

local function usePrimaryWeapon(player, primaryPressed, dt)
    if player.currentWeapon == "shield" then
        useShieldPrimary(player, primaryPressed, dt)
        return
    end
    if player.currentWeapon == "hands" then
        player.wasPrimaryPressed = primaryPressed
        return
    end

    if not primaryPressed or not player.canAttack then
        player.wasPrimaryPressed = primaryPressed
        return
    end

    if player.currentWeapon == "sword" then
        local weapon = Weapons["sword"]
        weapon.attacks.swing:execute(player, world)
        player.canAttack = false
        player.attackTime = weapon.cooldown
    elseif player.currentWeapon == "rifle" then
        local weapon = Weapons["rifle"]
        weapon.attacks.shot:execute(player, world)
        player.canAttack = false
        player.attackTime = weapon.cooldown
    end

    player.wasPrimaryPressed = primaryPressed
end

local function updateShieldBlock(player, blockPressed)
    if player.currentWeapon ~= "shield" then
        stopBlocking(player)
        return
    end

    if blockPressed then
        if not player.shield then
            print("NOT CURRENT BLOCK")
            local weapon = Weapons["shield"]
            player.shield = weapon.attacks.block:execute(player, world)
            player.shieldBlockStartTimer = SHIELD_BLOCK_START_DURATION
        end
    else
        stopBlocking(player)
    end
end

local function updateWeaponChangeVisual(player, dt)
    if not player.weaponChangeTimer or player.weaponChangeTimer <= 0 then return end

    player.weaponChangeTimer = math.max(0, player.weaponChangeTimer - dt)
end

local function drawWeaponChangeVisual(player)
    if not player.weaponChangeTimer or player.weaponChangeTimer <= 0 then return end

    local progress = 1 - (player.weaponChangeTimer / WEAPON_CHANGE_DISPLAY_DURATION)
    local alpha = 1 - progress
    local yOffset = 70 + progress * 12
    local text = player.weaponChangeText or getWeaponNumber(player.currentWeapon)

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.print(text, player.x - 6 + 1, player.y - yOffset + 1, 0, 2, 2)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, player.x - 6, player.y - yOffset, 0, 2, 2)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHPBar(x, y, w, h, hp, hpMax)
    -- fondo gris
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle('fill', x, y, w, h)
    -- parte viva (verde-roja según %)
    local ratio = hp / hpMax
    local r = 1 - ratio
    local g = ratio
    love.graphics.setColor(r, g, 0)
    love.graphics.rectangle('fill', x+1, y+1, (w-2)*ratio, h-2)
    love.graphics.setColor(1,1,1)  -- reset
end

local function updateAttackFacing(player, dt)
    if not player.attackFacingTime or player.attackFacingTime <= 0 then return end

    player.attackFacingTime = player.attackFacingTime - dt
    if player.attackAnim then
        player.anim = player.attackAnim
    end
end

----
-- Placeholder visual de ataque: lunge del sprite
-- No mueve el collider. Reemplazar cuando haya animaciones reales de ataque.
----

local function updateAttackVisual(player, dt)
    if not player.attackVisualTimer or player.attackVisualTimer <= 0 then return end

    player.attackVisualTimer = math.max(0, player.attackVisualTimer - dt)
end

local function getAttackDrawOffset(player)
    if not player.attackVisualTimer or player.attackVisualTimer <= 0 then
        return 0, 0
    end

    local progress = 1 - (player.attackVisualTimer / player.attackVisualDuration)
    local amount = 0
    if progress < 0.4 then
        amount = player.attackVisualDistance * (progress / 0.4)
    else
        amount = player.attackVisualDistance * (1 - ((progress - 0.4) / 0.6))
    end

    return math.cos(player.attackVisualAngle) * amount, math.sin(player.attackVisualAngle) * amount
end

function love.load()

    -------- Configs --------

    love.graphics.setDefaultFilter("nearest", "nearest") -- No suavizar imagenes
    gameMap = sti('maps/base_arena.lua')                 -- Carga el mapa
    Enemies.load()
    Weapons.load()
    loadDashDustEffects()

    -------- Physics  --------

    world = bf.newWorld(0, 0)
    --world:setQueryDebugDrawing(true) -- podés quitar esto luego, es útil para debug

    ---- Walls ----

    walls = {}
    walls.top    = world:newCollider("Rectangle",{0,   -50, 1920, 50})
    walls.bottom = world:newCollider("Rectangle",{0,  1088, 1920, 50})
    walls.left   = world:newCollider("Rectangle",{-50,   0,   50, 1088})
    walls.right  = world:newCollider("Rectangle",{1920,  0,   50, 1088})

    for _, wall in pairs(walls) do
        wall:setType("static")      -- inmóviles
    end

    -------- Main Entities --------
    
    ---- player1 ----

    player1 = {}
    player1.x = 400
    player1.y = 200
    player1.speed = 300
    player1.hp = 300
    player1.current_hp = 300
    player1.currentWeapon = "sword"
    player1.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player1.grid, player1.animations = createPlayerAnimations(player1.spriteSheet)
    player1.swordSprites = loadSwordPlayerSprites()
    player1.baseSprites = loadBasePlayerSprites()
    player1.shieldSprites = loadShieldPlayerSprites()
    player1.shield = nil
    player1.facing = "left"
    player1.visualDirectionX = -1
    player1.anim = player1.animations.left
    player1.drawSpriteSheet = player1.spriteSheet
    player1.drawAnim = player1.anim
    player1.drawScaleX = scale
    player1.drawScaleY = scale
    player1.drawOriginX = 6
    player1.drawOriginY = 9

    player1.collider = world:newCollider("Rectangle",{player1.x, player1.y, 10 * scale, 16 * scale, 14})
    player1.collider:setFixedRotation(true)
    player1.collider.identity = "player1"
    ignoreEnemyBodyCollisionDuringGuardDash(player1)
    player1.attackTime = 0
    player1.canAttack = true
    player1.dashTime = 0
    player1.dashCooldownTimer = 0
    player1.wasDashPressed = false
    player1.wasPrimaryPressed = false
    player1.primaryHoldTime = 0
    player1.primaryChargedExecuted = false
    player1.shieldChargePoints = 0
    player1.shieldChargeStartTimer = 0
    player1.shieldChargeRecoveryTimer = 0
    player1.guardDashProtectTimer = 0


    ---- player2 ----

    player2 = {}
    player2.x = 400
    player2.y = 200
    player2.speed = 300
    player2.hp = 300
    player2.current_hp = 300
    player2.currentWeapon = "sword"
    player2.spriteSheet = love.graphics.newImage('sprites/player2-sheet.png')
    player2.grid, player2.animations = createPlayerAnimations(player2.spriteSheet)
    player2.swordSprites = loadSwordPlayerSprites()
    player2.baseSprites = loadBasePlayerSprites()
    player2.shieldSprites = loadShieldPlayerSprites()
    player2.shield = nil
    player2.gamepad = nil
    player2.aimAngle = nil
    player2.facing = "left"
    player2.visualDirectionX = -1
    player2.anim = player2.animations.left
    player2.drawSpriteSheet = player2.spriteSheet
    player2.drawAnim = player2.anim
    player2.drawScaleX = scale
    player2.drawScaleY = scale
    player2.drawOriginX = 6
    player2.drawOriginY = 9

    player2.collider = world:newCollider("Rectangle",{player2.x, player2.y, 10 * scale, 16 * scale, 14})
    player2.collider:setFixedRotation(true)
    player2.collider.identity = "player2"
    ignoreEnemyBodyCollisionDuringGuardDash(player2)
    player2.attackTime = 0
    player2.canAttack = true
    player2.dashTime = 0
    player2.dashCooldownTimer = 0
    player2.wasDashPressed = false
    player2.wasPrimaryPressed = false
    player2.primaryHoldTime = 0
    player2.primaryChargedExecuted = false
    player2.shieldChargePoints = 0
    player2.shieldChargeStartTimer = 0
    player2.shieldChargeRecoveryTimer = 0
    player2.guardDashProtectTimer = 0

    ---- player1 Functions----

    function getAngleToMouse(player)
        local mx, my = love.mouse.getPosition()
        return math.atan2(my - player.y, mx - player.x)
    end

    function getAttackAngle(player)
        return player.aimAngle or getAngleToMouse(player)
    end

    local function updateAimFacing(player)
        if player.currentWeapon ~= "sword" then return end

        local aimX = math.cos(getAttackAngle(player))
        if math.abs(aimX) > 0.2 then
            player.visualDirectionX = aimX > 0 and 1 or -1
        end
    end

    ---- Starting Enemies ----

    Enemies.spawn("dummy", 1000, 400, world,2)
    Enemies.spawn("beholder", 900, 200, world,3)

function love.update(dt)
    dt = dt * DEBUG_TIME_SCALE
    updateWeaponSelection()

    -------- player1 Movement --------
     
    ---- Definitions ----
    
    local isMoving = false
    local vx, vy = 0, 0

    if love.keyboard.isDown("d") then
        vx = player1.speed
        player1.anim = player1.animations.right
        player1.facing = "right"
        player1.visualDirectionX = 1
        isMoving = true
    end
    if love.keyboard.isDown("a") then
        vx = player1.speed *-1
        player1.anim = player1.animations.left
        player1.facing = "left"
        player1.visualDirectionX = -1
        isMoving = true
    end
    if love.keyboard.isDown("s") then
        vy = player1.speed
        player1.anim = player1.animations.down
        player1.facing = "down"
        isMoving = true
    end
    if love.keyboard.isDown("w") then
        vy = player1.speed * -1
        player1.anim = player1.animations.up
        player1.facing = "up"
        isMoving = true
    end
        
    ---- Diagonal movement ----

    local len = math.sqrt(vx^2 + vy^2)
    if len > 0 then
        vx = (vx / len) * player1.speed
        vy = (vy / len) * player1.speed
    end

    local player1BlockPressed = love.mouse.isDown(2)
    local player1IsDashing
    vx, vy, player1IsDashing = updateDash(player1, dt, love.keyboard.isDown("space"), vx, vy, player1BlockPressed)
    if player1IsDashing then
        isMoving = true
    end

    ---- Collider-based movement ----

    player1.collider:setLinearVelocity(vx, vy)   

    player1.x = player1.collider:getX()
    player1.y = player1.collider:getY()

    if not isMoving then
        player1.anim:gotoFrame(2)
    end
    local player1IsMoving = isMoving
    updateAttackFacing(player1, dt)
    updateAttackVisual(player1, dt)
    updateWeaponChangeVisual(player1, dt)
    updateShieldCounter(player1, dt)


    -------- player2 Movement --------
     
    ---- Definitions ----
    
    local isMoving = false
    local vx, vy = 0, 0

    if love.keyboard.isDown("right") then
        vx = player2.speed
        player2.anim = player2.animations.right
        player2.facing = "right"
        player2.visualDirectionX = 1
        isMoving = true
    end
    if love.keyboard.isDown("left") then
        vx = player2.speed *-1
        player2.anim = player2.animations.left
        player2.facing = "left"
        player2.visualDirectionX = -1
        isMoving = true
    end
    if love.keyboard.isDown("down") then
        vy = player2.speed
        player2.anim = player2.animations.down
        player2.facing = "down"
        isMoving = true
    end
    if love.keyboard.isDown("up") then
        vy = player2.speed * -1
        player2.anim = player2.animations.up
        player2.facing = "up"
        isMoving = true
    end

    local gamepad = getPlayer2Gamepad()
    if gamepad then
        local gx = applyDeadzone(gamepad:getGamepadAxis("leftx"))
        local gy = applyDeadzone(gamepad:getGamepadAxis("lefty"))
        local isMovingWithStick = gx ~= 0 or gy ~= 0

        if isMovingWithStick then
            vx = gx * player2.speed
            vy = gy * player2.speed
            isMoving = true

            if math.abs(gx) > math.abs(gy) then
                player2.anim = gx > 0 and player2.animations.right or player2.animations.left
                player2.facing = gx > 0 and "right" or "left"
                player2.visualDirectionX = gx > 0 and 1 or -1
            else
                player2.anim = gy > 0 and player2.animations.down or player2.animations.up
                player2.facing = gy > 0 and "down" or "up"
                if gx ~= 0 then
                    player2.visualDirectionX = gx > 0 and 1 or -1
                end
            end
        end

        local aimX = applyDeadzone(gamepad:getGamepadAxis("rightx"))
        local aimY = applyDeadzone(gamepad:getGamepadAxis("righty"))
        if aimX ~= 0 or aimY ~= 0 then
            player2.aimAngle = math.atan2(aimY, aimX)
        elseif isMovingWithStick then
            player2.aimAngle = math.atan2(gy, gx)
        end
    end
        
    ---- Diagonal movement ----

    local len = math.sqrt(vx^2 + vy^2)
    if len > 0 then
        vx = (vx / len) * player2.speed
        vy = (vy / len) * player2.speed
    end

    local player2BlockPressed = love.mouse.isDown(5) or (gamepad and gamepad:isGamepadDown("leftshoulder"))
    local player2DashPressed = love.keyboard.isDown("rshift") or (gamepad and gamepad:isGamepadDown("b"))
    local player2IsDashing
    vx, vy, player2IsDashing = updateDash(player2, dt, player2DashPressed, vx, vy, player2BlockPressed)
    if player2IsDashing then
        isMoving = true
    end

    ---- Collider-based movement ----

    player2.collider:setLinearVelocity(vx, vy)   

    player2.x = player2.collider:getX()
    player2.y = player2.collider:getY()

    if not isMoving then
        player2.anim:gotoFrame(2)
    end
    local player2IsMoving = isMoving
    updateAttackFacing(player2, dt)
    updateAttackVisual(player2, dt)
    updateWeaponChangeVisual(player2, dt)
    updateShieldCounter(player2, dt)


    -------- player1 Attack --------

    updateAttackCooldown(player1, dt)
    usePrimaryWeapon(player1, love.mouse.isDown(1), dt)
    updateShieldBlock(player1, player1BlockPressed)

        -------- player2 Attack --------

    updateAttackCooldown(player2, dt)
    local player2Gamepad = getPlayer2Gamepad()
    usePrimaryWeapon(player2, love.mouse.isDown(4) or (player2Gamepad and player2Gamepad:isGamepadDown("a")), dt)
    updateShieldBlock(player2, player2BlockPressed)

    updateAimFacing(player1)
    updateAimFacing(player2)
    selectPlayerDrawAnimation(player1, player1IsMoving, dt)
    selectPlayerDrawAnimation(player2, player2IsMoving, dt)

    Weapons.update(dt)
    world:update(dt)
    Enemies.update(dt)
    updateDashDustEffects(dt)
    
    player1.drawAnim:update(dt)
    player2.drawAnim:update(dt)
    if player1.drawHandsAnim then
        player1.drawHandsAnim:update(dt)
    end
    if player2.drawHandsAnim then
        player2.drawHandsAnim:update(dt)
    end
end
end

function love.joystickadded(joystick)
    if player2 and joystick:isGamepad() and not player2.gamepad then
        player2.gamepad = joystick
        player2.aimAngle = player2.aimAngle or 0
        print("Player 2 gamepad:", joystick:getName())
    end
end

function love.joystickremoved(joystick)
    if player2 and player2.gamepad == joystick then
        player2.gamepad = nil
        player2.aimAngle = nil
    end
end

function love.keypressed(key)
    if key == "o" then
        changeDebugTimeScale(-DEBUG_TIME_SCALE_STEP)
    elseif key == "p" then
        changeDebugTimeScale(DEBUG_TIME_SCALE_STEP)
    elseif key == "\\" then
        DEBUG_TIME_SCALE = 1
    end
end


function love.draw()

    -------- Map --------
    gameMap:draw()

    -------- Weapons --------
    Weapons.draw()

    -------- Enemy Projectiles --------
    Enemies.drawProjectiles()

    -------- Dash Dust --------
    drawDashDustEffects()

    -------- player1 --------
    -- Placeholder visual: offset temporal del sprite durante el ataque.
    local player1DrawOffsetX, player1DrawOffsetY = getAttackDrawOffset(player1)
    local player1AttackAngle = getAttackAngle(player1)
    if Weapons.heldWeaponDrawsBehind(player1, player1AttackAngle) then
        Weapons.drawHeldWeapon(player1, player1DrawOffsetX, player1DrawOffsetY, player1AttackAngle)
    end
    player1.drawAnim:draw(            -- sprite/animación
        player1.drawSpriteSheet,
        player1.x + player1DrawOffsetX, player1.y + player1DrawOffsetY,
        nil,                         -- rot
        player1.drawScaleX,           -- escala x
        player1.drawScaleY,           -- escala y
        player1.drawOriginX, player1.drawOriginY) -- offsets
    if player1.drawHandsAnim then
        player1.drawHandsAnim:draw(
            player1.drawHandsSpriteSheet,
            player1.x + player1DrawOffsetX, player1.y + player1DrawOffsetY,
            nil,
            player1.drawScaleX,
            player1.drawScaleY,
            player1.drawOriginX, player1.drawOriginY)
    end

    if not Weapons.heldWeaponDrawsBehind(player1, player1AttackAngle) then
        Weapons.drawHeldWeapon(player1, player1DrawOffsetX, player1DrawOffsetY, player1AttackAngle)
    end

            -------- player2 --------
    -- Placeholder visual: offset temporal del sprite durante el ataque.
    local player2DrawOffsetX, player2DrawOffsetY = getAttackDrawOffset(player2)
    local player2AttackAngle = getAttackAngle(player2)
    if Weapons.heldWeaponDrawsBehind(player2, player2AttackAngle) then
        Weapons.drawHeldWeapon(player2, player2DrawOffsetX, player2DrawOffsetY, player2AttackAngle)
    end
    player2.drawAnim:draw(            -- sprite/animación
        player2.drawSpriteSheet,
        player2.x + player2DrawOffsetX, player2.y + player2DrawOffsetY,
        nil,                         -- rot
        player2.drawScaleX,           -- escala x
        player2.drawScaleY,           -- escala y
        player2.drawOriginX, player2.drawOriginY) -- offsets
    if player2.drawHandsAnim then
        player2.drawHandsAnim:draw(
            player2.drawHandsSpriteSheet,
            player2.x + player2DrawOffsetX, player2.y + player2DrawOffsetY,
            nil,
            player2.drawScaleX,
            player2.drawScaleY,
            player2.drawOriginX, player2.drawOriginY)
    end

    if not Weapons.heldWeaponDrawsBehind(player2, player2AttackAngle) then
        Weapons.drawHeldWeapon(player2, player2DrawOffsetX, player2DrawOffsetY, player2AttackAngle)
    end

    Weapons.drawPlayerOverlays()

    drawWeaponChangeVisual(player1)
    drawWeaponChangeVisual(player2)

    ---- Barra de vida del jugador ----
    drawHPBar(
        player1.x - 25,               -- x
        player1.y - (18 * scale) / 2 - 12, -- y (sobre la cabeza)
        50, 5,                       -- ancho, alto
        player1.current_hp,           -- vida actual
        player1.hp)                   -- vida máxima


    -------- Enemies --------
    for _, enemy in ipairs(Enemies.list) do

        local cx, cy = Enemies.getDrawPosition(enemy)
        Enemies.draw(enemy)

        ---- Barra de vida ----
        local barWidth = enemy.spriteWidth or enemy.width
        local barHeight = enemy.spriteHeight or enemy.height
        drawHPBar(
            cx - barWidth / 2,
            cy - barHeight / 2 - 10,
            barWidth,
            4,
            enemy.current_hp,
            enemy.hp)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        string.format("Time scale: %.1f  (O/P adjust, \\ reset)", DEBUG_TIME_SCALE),
        10,
        10)

    -------- Debug (colliders) --------
    --world:draw() -- quitá o comenta esto cuando no haga falta
end
