Enemies = require "enemies"
anim8 = require 'libraries.anim8'
sti = require 'libraries.sti'
bf = require 'libraries.breezefield'
Weapons = require "weapons"

-- poop 

scale = 4.5

print("================Iniciando juego================")    

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

function love.load()

    -------- Configs --------

    love.graphics.setDefaultFilter("nearest", "nearest") -- No suavizar imagenes
    gameMap = sti('maps/base_arena.lua')                 -- Carga el mapa

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
    player1.x = 400 -- player1["x"] = 400
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
    player1.anim = player1.animations.right

    player1.collider = world:newCollider("Rectangle",{player1.x, player1.y, 10 * scale, 16 * scale, 14})
    player1.collider:setFixedRotation(true)
    player1.collider.identity = "player1"
    player1.attackTime = 0


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

    -- Sprite bala --

    bala = {}
    bala.sprite = love.graphics.newImage('sprites/ball_only.png')

    espada = love.graphics.newImage('sprites/sword.png')

    ---- player1 Functions----

    function getAngleToMouse(player)
        local mx, my = love.mouse.getPosition()
        return math.atan2(my - player.y, mx - player.x)
    end

    ---- Starting Enemies ----

    Enemies.spawn("dummy", 1000, 400, world)

function love.update(dt)

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

    ---- Collider-based movement ----

    player1.collider:setLinearVelocity(vx, vy)   

    player1.x = player1.collider:getX()
    player1.y = player1.collider:getY()

    if not isMoving then
        player1.anim:gotoFrame(2)
    end


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
        
    ---- Diagonal movement ----

    local len = math.sqrt(vx^2 + vy^2)
    if len > 0 then
        vx = (vx / len) * player2.speed
        vy = (vy / len) * player2.speed
    end

    ---- Collider-based movement ----

    player2.collider:setLinearVelocity(vx, vy)   

    player2.x = player2.collider:getX()
    player2.y = player2.collider:getY()

    if not isMoving then
        player2.anim:gotoFrame(2)
    end


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
    if love.mouse.isDown(4) and player2.canAttack then
        local weapon = Weapons[player2.currentWeapon]          -- "sword" o lo que sea
        weapon.attacks.swing:execute(player2, world)                         
        player2.canAttack  = false
        player2.attackTime = weapon.cooldown
    end

    if love.keyboard.isDown("e") and player2.canAttack then
        local weapon = Weapons["rifle"]     -- "sword" o lo que sea
        weapon.attacks.shot:execute(player2, world)                          
        player2.canAttack  = false
        player2.attackTime = weapon.cooldown
    end
    if love.mouse.isDown(5) then
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
    
    player1.anim:update(dt)
    player2.anim:update(dt)
end
end


function love.draw()

    -------- Map --------
    gameMap:draw()

    -------- player1 --------
    player1.anim:draw(                -- sprite/animación
        player1.spriteSheet,
        player1.x, player1.y,
        nil,                         -- rot
        scale,                       -- escala
        nil,
        6, 9)                        -- offsets

            -------- player2 --------
    player2.anim:draw(                -- sprite/animación
        player2.spriteSheet,
        player2.x, player2.y,
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

    --- Bala ---
    
    local scalee = 4

    for i = #ActiveAttacks, 1, -1 do
        if ActiveAttacks[i].collider.identity == "PlayerBullet" then
            local bulletX = ActiveAttacks[i].collider:getX()
            local bulletY = ActiveAttacks[i].collider:getY()
            local bulletAngle = ActiveAttacks[i].collider:getAngle()
            local scale_bullet = 16 / bala.sprite:getWidth() -- asumimos ancho=alto

            love.graphics.draw(
                bala.sprite,
                bulletX,
                bulletY,
                bulletAngle,
                scale_bullet,
                scale_bullet,
                bala.sprite:getWidth() / 2,
                bala.sprite:getHeight() / 2
            )
        end
        
        if ActiveAttacks[i].collider.identity == "PlayerSword" then
            local swordX = ActiveAttacks[i].collider:getX()
            local swordY = ActiveAttacks[i].collider:getY()
            local swordAngle = ActiveAttacks[i].collider:getAngle()
            local scalee_x = 60 / espada:getWidth() --   60 / 6 = 10 
            local scalee_y = 18 / espada:getHeight() --  18 / 15 = 1.2  --> escala para que el sprite sea del mismo tamaño que el collider.

            love.graphics.draw(
                espada,
                swordX,
                swordY,
                swordAngle,
                scalee_x,
                scalee_y,
                espada:getWidth() / 2, -- Ahora que son iguales, los centros son los mísmos.
                espada:getHeight() / 2
            )
        end


    end


    -------- Enemies --------
    for _, enemy in ipairs(Enemies.list) do

        ---- Cuerpo (placeholder en rojo) ----
        local cx, cy = enemy.collider:getPosition()
        love.graphics.setColor(0.8, 0.1, 0.1)
        love.graphics.rectangle('fill',
            cx - enemy.width / 2,
            cy - enemy.height / 2,
            enemy.width,
            enemy.height)
        love.graphics.setColor(1, 1, 1)

        ---- Barra de vida ----
        drawHPBar(
            cx - enemy.width / 2,
            cy - enemy.height / 2 - 10,
            enemy.width,
            4,
            enemy.current_hp,
            enemy.hp)
    end


    -------- Debug (colliders) --------
    world:draw() -- quitá o comenta esto cuando no haga falta
end