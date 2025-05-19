Enemies = require "enemies"
anim8 = require 'libraries.anim8'
sti = require 'libraries.sti'
bf = require 'libraries.breezefield'

scale = 4.5

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
    
    ---- Player ----

    player = {}
    player.x = 400
    player.y = 200
    player.speed = 300
    player.hp = 300
    player.current_hp = 300
    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid(12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight())

    player.animations = {}
    player.animations.down = anim8.newAnimation(player.grid('1-4', 1), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-4', 2), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-4', 3), 0.2)
    player.animations.up = anim8.newAnimation(player.grid('1-4', 4), 0.2)
    player.anim = player.animations.left

    player.collider = world:newCollider("Rectangle",{player.x, player.y, 10 * scale, 16 * scale, 14})
    player.collider:setFixedRotation(true)
    player.attackHitbox = nil -- Requerido por el ataque


    ---- Player Functions----

    function player:getAngleToMouse()
    local mouseX, mouseY = love.mouse.getPosition()
    local dx = mouseX - self.x
    local dy = mouseY - self.y
    return math.atan2(dy, dx)
    end

    ---- Starting Enemies ----

    Enemies.spawn("dummy", 1000, 400, world)

    ---- Simple weapon ----

    player.weapon = {
        range    = 60,    -- píxeles
        damage   = 15,
        cooldown = 0.35
    }
    player.canAttack  = true
    player.attackTime = 0
end


function love.update(dt)

    -------- Player Movement --------

    ---- Definitions ----
    
    local isMoving = false
    local vx, vy = 0, 0

    if love.keyboard.isDown("d") then
        vx = player.speed
        player.anim = player.animations.right
        isMoving = true
    end
    if love.keyboard.isDown("a") then
        vx = player.speed *-1
        player.anim = player.animations.left
        isMoving = true
    end
    if love.keyboard.isDown("s") then
        vy = player.speed
        player.anim = player.animations.down
        isMoving = true
    end
    if love.keyboard.isDown("w") then
        vy = player.speed * -1
        player.anim = player.animations.up
        isMoving = true
    end
        
    ---- Diagonal movement ----

    local len = math.sqrt(vx^2 + vy^2)
    if len > 0 then
        vx = (vx / len) * player.speed
        vy = (vy / len) * player.speed
    end

    ---- Collider-based movement ----

    player.collider:setLinearVelocity(vx, vy)   

    player.x = player.collider:getX()
    player.y = player.collider:getY()

    if not isMoving then
        player.anim:gotoFrame(2)
    end

    -------- Player Attack --------

    ---- CoolDown ----

    if not player.canAttack then
        player.attackTime = player.attackTime - dt
        if player.attackTime <= 0 then player.canAttack = true end
    end

    ---- Atack on click ----

    if love.mouse.isDown(1) and player.canAttack then
        local angle = player:getAngleToMouse()
        local offset = player.weapon.range
        local hitboxX = player.x + math.cos(angle) * offset
        local hitboxY = player.y + math.sin(angle) * offset

        local hitboxWidth  = 20
        local hitboxHeight = 20

        local hitbox = world:newCollider("Rectangle",{hitboxX, hitboxY, hitboxWidth, hitboxHeight})
        hitbox:setType("dynamic")
        hitbox.identity = "PlayerAttack"
        hitbox.life = 0.1 -- segundos que dura el hitbox

        function hitbox:enter(other, contact)
            if other.identity == "Enemy" then
                local enemy = other.parent     
                if enemy and enemy.current_hp then
                    enemy.current_hp = math.max(
                        0, enemy.current_hp - player.weapon.damage)
                    print("¡Golpe!", enemy.current_hp .. " HP restante")
                end
            end
        end
        player.attackHitbox = hitbox
        player.attackAngle = angle
        player.canAttack = false
        player.attackTime = player.weapon.cooldown
    end

    world:update(dt)
    player.anim:update(dt)

    -------- Collitions check --------

    if player.attackHitbox and not player.attackHitbox:isDestroyed() then
        local hitbox = player.attackHitbox
        hitbox.life = hitbox.life - dt

        if hitbox.life <= 0 then
            hitbox:destroy()
            player.attackHitbox = nil
        end
    end
end


function love.draw()

    -------- Map --------
    gameMap:draw()

    -------- Player --------
    player.anim:draw(                -- sprite/animación
        player.spriteSheet,
        player.x, player.y,
        nil,                         -- rot
        scale,                       -- escala
        nil,
        6, 9)                        -- offsets

    ---- Barra de vida del jugador ----
    drawHPBar(
        player.x - 25,               -- x
        player.y - (18 * scale) / 2 - 12, -- y (sobre la cabeza)
        50, 5,                       -- ancho, alto
        player.current_hp,           -- vida actual
        player.hp)                   -- vida máxima


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

