scale = 4.5
Enemies = require "enemies"

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
    love.graphics.setDefaultFilter("nearest", "nearest")

    anim8 = require 'libraries/anim8'
    sti = require 'libraries/sti'
    wf = require 'libraries.windfield'
    


    gameMap = sti('maps/base_arena.lua')

    -- Crear mundo de colisiones
    world = wf.newWorld(0, 0)

    world:addCollisionClass('Player')   -- solo crea la clase
    world:addCollisionClass('Enemy')    -- crea la segunda
    world:addCollisionClass('Attack')  

    --world:on('Attack', 'Enemy', function(attackFixture, enemyFixture, col)



    Enemies.load(world)
    world:setQueryDebugDrawing(true) -- podés quitar esto luego, es útil para debug

    -- Crear colisiones en los bordes
    walls = {}
    walls.top = world:newRectangleCollider(0, -50, 1920, 50)
    walls.bottom = world:newRectangleCollider(0, 1088, 1920, 50)
    walls.left = world:newRectangleCollider(-50, 0, 50, 1088)
    walls.right = world:newRectangleCollider(1920, 0, 50, 1088)
    for _, wall in pairs(walls) do
        wall:setType('static')
    end

    -- Personaje
    player = {}
    player.x = 400
    player.y = 200
    player.speed = 300
    player.hp = 300
    player.spriteSheet = love.graphics.newImage('sprites/player-sheet.png')
    player.grid = anim8.newGrid(12, 18, player.spriteSheet:getWidth(), player.spriteSheet:getHeight())

    player.animations = {}
    player.animations.down = anim8.newAnimation(player.grid('1-4', 1), 0.2)
    player.animations.left = anim8.newAnimation(player.grid('1-4', 2), 0.2)
    player.animations.right = anim8.newAnimation(player.grid('1-4', 3), 0.2)
    player.animations.up = anim8.newAnimation(player.grid('1-4', 4), 0.2)
    player.anim = player.animations.left

    player.collider = world:newBSGRectangleCollider(player.x, player.y, 10 * scale, 16 * scale, 14)
    player.collider:setFixedRotation(true)

        -- HP
    Enemies.dummy.hpMax = 100      -- guardo max para dibujar la barra
    Enemies.dummy.hp    = Enemies.dummy.hpMax

    -- Arma cuerpo-a-cuerpo muy simple
    player.weapon = {
        range    = 60,    -- píxeles
        damage   = 15,
        cooldown = 0.35
    }
    player.canAttack  = true
    player.attackTime = 0
end


function love.update(dt)
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

        
    local len = math.sqrt(vx^2 + vy^2)
    if len > 0 then
        vx = (vx / len) * player.speed
        vy = (vy / len) * player.speed
    end

    player.collider:setLinearVelocity(vx, vy)   


    player.x = player.collider:getX()
    player.y = player.collider:getY()

    if not isMoving then
        player.anim:gotoFrame(2)
    end

-- ===== Cool-down usual =====
if not player.canAttack then
    player.attackTime = player.attackTime - dt
    if player.attackTime <= 0 then player.canAttack = true end
end

    player.anim:update(dt)
    world:update(dt)

-- ===== Vida del hitbox + chequeo de colisión =====
if player.currentHitbox and not player.currentHitbox:isDestroyed() then
    local hb = player.currentHitbox
    hb.life = hb.life - dt
    if hb:enter('Enemy') then                -- ← AQUÍ aplicamos daño
        local d = Enemies.dummy
        if d.hp > 0 then
            d.hp = math.max(0, d.hp - player.weapon.damage)
            print('Hit! HP dummy:', d.hp)
        end
    end
    if hb.life <= 0 then hb:destroy() end
end
end

function love.mousepressed(mx, my, button)
    if button ~= 1 or not player.canAttack then return end   -- solo click izq

    player.canAttack  = false
    player.attackTime = player.weapon.cooldown

    -- 1️⃣  dirección del jugador al puntero
    local dx = mx - player.x
    local dy = my - player.y
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end        -- por si hace click exacto en el centro

    local dirX, dirY = dx/len, dy/len

    -- 2️⃣  posición del hitbox: un poco delante del jugador
    local offset = player.weapon.range * 0.6      -- ajustá “0.6” a tu gusto
    local hbX = player.x + dirX * offset
    local hbY = player.y + dirY * offset

    -- 3️⃣  crear hitbox sensor
    local hbRadius = 25
    local hitbox = world:newCircleCollider(
                       hbX, hbY, hbRadius)
    hitbox:setType('dynamic')
    hitbox:setCollisionClass('Attack')
    hitbox:setSensor(true)

    hitbox.life = 0.10
    player.currentHitbox = hitbox
end

function love.draw()
    gameMap:draw()
    player.anim:draw(
    player.spriteSheet,
    player.x,
    player.y,
    nil,
    scale,
    nil,
    6,
    9
    )
    local d = Enemies.dummy
    local cx, cy = d.collider:getPosition()
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle('fill',
        cx - 20, cy - 35,   -- 40×70 centrado
        40, 70)
    love.graphics.setColor(1, 1, 1)

        -- --- Jugador (HP bar encima) ---
    drawHPBar(
        player.x - 25,                -- x
        player.y - (18*scale)/2 - 12, -- y (un poco sobre la cabeza)
        50, 5,                        -- ancho, alto
        player.hp, 100)

    -- --- Dummy ---
    drawHPBar(
        Enemies.dummy.collider:getX() - 20,
        Enemies.dummy.collider:getY() - Enemies.dummy.h/2 - 10,
        40, 4,
        Enemies.dummy.hp, Enemies.dummy.hpMax)
    world:draw() -- (opcional) útil para debug
end
