Enemies = require "enemies"
anim8 = require 'libraries.anim8'
sti = require 'libraries.sti'
bf = require 'libraries.breezefield'
Weapons = require "weapons"

scale = 4.5

print("================Iniciando juego================")    

local GAMEPAD_DEADZONE = 0.25
local DEBUG_TIME_SCALE = 1.0
local DASH_DURATION = 0.12
local DASH_SPEED = 750
local DASH_COOLDOWN = 0.45
local DASH_DUST_FRAME_SIZE = 128
local DASH_DUST_FRAME_TIME = 0.04
local DASH_DUST_SCALE = 0.45
local dashDustImage = nil
local dashDustQuads = {}
local dashDustEffects = {}

local function applyDeadzone(value)
    value = value or 0
    if math.abs(value) < GAMEPAD_DEADZONE then return 0 end
    return value
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

local function updateDash(player, dt, dashPressed, moveX, moveY)
    player.dashCooldownTimer = math.max(0, (player.dashCooldownTimer or 0) - dt)

    if dashPressed and not player.wasDashPressed and player.dashCooldownTimer <= 0 then
        local moveLength = math.sqrt(moveX^2 + moveY^2)
        player.dashAngle = moveLength > 0 and math.atan2(moveY, moveX) or getAttackAngle(player)
        player.dashTime = DASH_DURATION
        player.dashCooldownTimer = DASH_COOLDOWN
        spawnDashDustEffect(player, player.dashAngle)
    end
    player.wasDashPressed = dashPressed

    if player.dashTime and player.dashTime > 0 then
        player.dashTime = math.max(0, player.dashTime - dt)
        return math.cos(player.dashAngle) * DASH_SPEED, math.sin(player.dashAngle) * DASH_SPEED, true
    end

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
    player1.grid = anim8.newGrid(12, 18, player1.spriteSheet:getWidth(), player1.spriteSheet:getHeight())
    player1.shield = nil



    player1.animations = {}
    player1.animations.down = anim8.newAnimation(player1.grid('1-4', 1), 0.2)
    player1.animations.left = anim8.newAnimation(player1.grid('1-4', 2), 0.2)
    player1.animations.right = anim8.newAnimation(player1.grid('1-4', 3), 0.2)
    player1.animations.up = anim8.newAnimation(player1.grid('1-4', 4), 0.2)
    player1.anim = player1.animations.left

    player1.collider = world:newCollider("Rectangle",{player1.x, player1.y, 10 * scale, 16 * scale, 14})
    player1.collider:setFixedRotation(true)
    player1.collider.identity = "player1"
    player1.attackTime = 0
    player1.canAttack = true
    player1.dashTime = 0
    player1.dashCooldownTimer = 0
    player1.wasDashPressed = false


    ---- player2 ----

    player2 = {}
    player2.x = 400
    player2.y = 200
    player2.speed = 300
    player2.hp = 300
    player2.current_hp = 300
    player2.currentWeapon = "sword"
    player2.spriteSheet = love.graphics.newImage('sprites/player2-sheet.png')
    player2.grid = anim8.newGrid(12, 18, player2.spriteSheet:getWidth(), player2.spriteSheet:getHeight())
    player2.shield = nil
    player2.gamepad = nil
    player2.aimAngle = nil

    player2.animations = {}
    player2.animations.down = anim8.newAnimation(player2.grid('1-4', 1), 0.2)
    player2.animations.left = anim8.newAnimation(player2.grid('1-4', 2), 0.2)
    player2.animations.right = anim8.newAnimation(player2.grid('1-4', 3), 0.2)
    player2.animations.up = anim8.newAnimation(player2.grid('1-4', 4), 0.2)
    player2.anim = player2.animations.left

    player2.collider = world:newCollider("Rectangle",{player2.x, player2.y, 10 * scale, 16 * scale, 14})
    player2.collider:setFixedRotation(true)
    player2.collider.identity = "player2"
    player2.attackTime = 0
    player2.canAttack = true
    player2.dashTime = 0
    player2.dashCooldownTimer = 0
    player2.wasDashPressed = false

    ---- player1 Functions----

    function getAngleToMouse(player)
        local mx, my = love.mouse.getPosition()
        return math.atan2(my - player.y, mx - player.x)
    end

    function getAttackAngle(player)
        return player.aimAngle or getAngleToMouse(player)
    end

    ---- Starting Enemies ----

    Enemies.spawn("dummy", 1000, 400, world,2)

function love.update(dt)
    dt = dt * DEBUG_TIME_SCALE

    -------- player1 Movement --------
     
    ---- Definitions ----
    
    local isMoving = false
    local vx, vy = 0, 0

    if love.keyboard.isDown("d") then
        vx = player1.speed
        player1.anim = player1.animations.right
        isMoving = true
    end
    if love.keyboard.isDown("a") then
        vx = player1.speed *-1
        player1.anim = player1.animations.left
        isMoving = true
    end
    if love.keyboard.isDown("s") then
        vy = player1.speed
        player1.anim = player1.animations.down
        isMoving = true
    end
    if love.keyboard.isDown("w") then
        vy = player1.speed * -1
        player1.anim = player1.animations.up
        isMoving = true
    end
        
    ---- Diagonal movement ----

    local len = math.sqrt(vx^2 + vy^2)
    if len > 0 then
        vx = (vx / len) * player1.speed
        vy = (vy / len) * player1.speed
    end

    local player1IsDashing
    vx, vy, player1IsDashing = updateDash(player1, dt, love.keyboard.isDown("space"), vx, vy)
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
    updateAttackFacing(player1, dt)
    updateAttackVisual(player1, dt)


    -------- player2 Movement --------
     
    ---- Definitions ----
    
    local isMoving = false
    local vx, vy = 0, 0

    if love.keyboard.isDown("right") then
        vx = player2.speed
        player2.anim = player2.animations.right
        isMoving = true
    end
    if love.keyboard.isDown("left") then
        vx = player2.speed *-1
        player2.anim = player2.animations.left
        isMoving = true
    end
    if love.keyboard.isDown("down") then
        vy = player2.speed
        player2.anim = player2.animations.down
        isMoving = true
    end
    if love.keyboard.isDown("up") then
        vy = player2.speed * -1
        player2.anim = player2.animations.up
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
            else
                player2.anim = gy > 0 and player2.animations.down or player2.animations.up
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

    local player2DashPressed = love.keyboard.isDown("rshift") or (gamepad and gamepad:isGamepadDown("b"))
    local player2IsDashing
    vx, vy, player2IsDashing = updateDash(player2, dt, player2DashPressed, vx, vy)
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
    updateAttackFacing(player2, dt)
    updateAttackVisual(player2, dt)


    -------- player1 Attack --------

    -- Cooldown
    if not player1.canAttack then
        player1.attackTime = player1.attackTime - dt
        if player1.attackTime <= 0 then player1.canAttack = true end
    end

    -- Disparo del ataque (solo si hay clic y arma lista)
    if love.mouse.isDown(1) and player1.canAttack then
        local weapon = Weapons[player1.currentWeapon]          -- "sword" o lo que sea
        weapon.attacks.swing:execute(player1, world)                         
        player1.canAttack  = false
        player1.attackTime = weapon.cooldown
    end

    if love.mouse.isDown(2) and player1.canAttack then
        local weapon = Weapons["rifle"]     -- "sword" o lo que sea
        weapon.attacks.shot:execute(player1, world)                          
        player1.canAttack  = false
        player1.attackTime = weapon.cooldown
    end
    if love.mouse.isDown(3) then
        if not player1.shield then
            print("NOT CURRENT BLOCK")
            local weapon = Weapons["shield"]     
            player1.shield = weapon.attacks.block:execute(player1, world)  
        end
    else
        if player1.shield  then
            print("DESTROYING SHIELD COLLIDER.")
            player1.shield.collider:destroy()
            player1.shield.dead = true
            player1.shield = nil
            player1.canAttack = true
        end
    end

        -------- player2 Attack --------

    -- Cooldown
    if not player2.canAttack then
        player2.attackTime = player2.attackTime - dt
        if player2.attackTime <= 0 then player2.canAttack = true end
    end

    -- Disparo del ataque (solo si hay clic y arma lista)
    local player2Gamepad = getPlayer2Gamepad()

    if (love.mouse.isDown(4) or (player2Gamepad and player2Gamepad:isGamepadDown("a"))) and player2.canAttack then
        local weapon = Weapons[player2.currentWeapon]          -- "sword" o lo que sea
        weapon.attacks.swing:execute(player2, world)                         
        player2.canAttack  = false
        player2.attackTime = weapon.cooldown
    end

    if (love.keyboard.isDown("e") or (player2Gamepad and player2Gamepad:isGamepadDown("rightshoulder"))) and player2.canAttack then
        local weapon = Weapons["rifle"]     -- "sword" o lo que sea
        weapon.attacks.shot:execute(player2, world)                          
        player2.canAttack  = false
        player2.attackTime = weapon.cooldown
    end
    if love.mouse.isDown(5) or (player2Gamepad and player2Gamepad:isGamepadDown("leftshoulder")) then
        if not player2.shield  then
            print("NOT CURRENT BLOCK")
            local weapon = Weapons["shield"]     
            player2.shield = weapon.attacks.block:execute(player2, world)  
        end
    else
        if player2.shield then
            print("DESTROYING SHIELD COLLIDER.")
            player2.shield.collider:destroy()
            player2.shield.dead = true
            player2.shield = nil
            player2.canAttack = true
        end
    end


    Weapons.update(dt)
    world:update(dt)
    Enemies.update(dt)
    updateDashDustEffects(dt)
    
    player1.anim:update(dt)
    player2.anim:update(dt)
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


function love.draw()

    -------- Map --------
    gameMap:draw()

    -------- Weapons --------
    Weapons.draw()

    -------- Dash Dust --------
    drawDashDustEffects()

    -------- player1 --------
    -- Placeholder visual: offset temporal del sprite durante el ataque.
    local player1DrawOffsetX, player1DrawOffsetY = getAttackDrawOffset(player1)
    player1.anim:draw(                -- sprite/animación
        player1.spriteSheet,
        player1.x + player1DrawOffsetX, player1.y + player1DrawOffsetY,
        nil,                         -- rot
        scale,                       -- escala
        nil,
        6, 9)                        -- offsets

            -------- player2 --------
    -- Placeholder visual: offset temporal del sprite durante el ataque.
    local player2DrawOffsetX, player2DrawOffsetY = getAttackDrawOffset(player2)
    player2.anim:draw(                -- sprite/animación
        player2.spriteSheet,
        player2.x + player2DrawOffsetX, player2.y + player2DrawOffsetY,
        nil,                         -- rot
        scale,                       -- escala
        nil,
        6, 9)                        -- offsets

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

    -------- Debug (colliders) --------
    world:draw() -- quitá o comenta esto cuando no haga falta
end
