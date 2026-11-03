local enemies = {}

---- Dummy ----

enemies.dummy = {}
enemies.dummy.spriteW = 48
enemies.dummy.spriteH = 48
enemies.dummy.hitboxW = 38
enemies.dummy.hitboxH = 40
enemies.dummy.hitboxOffsetX = 0
enemies.dummy.hitboxOffsetY = (enemies.dummy.spriteH - enemies.dummy.hitboxH) / 2
enemies.dummy.hitboxCornerRadius = 8
enemies.dummy.hp = 100
enemies.dummy.speed = 0
enemies.dummy.colliderType = "static"
enemies.dummy.spriteName = "trainingDummy"

---- Beholder ----

enemies.beholder = {}
enemies.beholder.spriteW = 16
enemies.beholder.spriteH = 16
enemies.beholder.hitboxW = 12
enemies.beholder.hitboxH = 12
enemies.beholder.hp = 60
enemies.beholder.speed = 0
enemies.beholder.colliderType = "static"
enemies.beholder.spriteName = "beholder"
enemies.beholder.shootInterval = 1.4
enemies.beholder.shootAngle = math.pi
enemies.beholder.projectileSpeed = 260
enemies.beholder.projectileSize = 5
enemies.beholder.projectileDuration = 4
enemies.beholder.projectileDamage = 10

enemies.list = {}
enemies.sprites = {}
enemies.projectiles = {}
enemies.world = nil

function enemies.load()
    enemies.sprites.trainingDummy = {
        idle = love.graphics.newImage("sprites/enemies/training_dummy/idle.png"),
        hit = {
            love.graphics.newImage("sprites/enemies/training_dummy/hit1.png"),
            love.graphics.newImage("sprites/enemies/training_dummy/hit2.png"),
            love.graphics.newImage("sprites/enemies/training_dummy/hit3.png"),
            love.graphics.newImage("sprites/enemies/training_dummy/hit4.png"),
            love.graphics.newImage("sprites/enemies/training_dummy/hit5.png")
        }
    }

    local beholderImage = love.graphics.newImage("sprites/enemies/beholder_16x16.png")
    enemies.sprites.beholder = {
        idle = beholderImage,
        idleQuad = love.graphics.newQuad(0, 16, 16, 16, beholderImage:getWidth(), beholderImage:getHeight()),
        projectile = beholderImage,
        projectileQuad = love.graphics.newQuad(192, 16, 16, 16, beholderImage:getWidth(), beholderImage:getHeight())
    }
end

local function makeRoundedRectanglePoints(width, height, radius)
    radius = math.min(radius or 0, width / 2, height / 2)
    local left = -width / 2
    local right = width / 2
    local top = -height / 2
    local bottom = height / 2

    return {
        left + radius, top,
        right - radius, top,
        right, top + radius,
        right, bottom - radius,
        right - radius, bottom,
        left + radius, bottom,
        left, bottom - radius,
        left, top + radius
    }
end

local function spawnProjectile(enemy)
    if not enemies.world then return end

    local projectile = {}
    projectile.x = enemy.collider:getX()
    projectile.y = enemy.collider:getY()
    projectile.angle = enemy.shootAngle
    projectile.speed = enemy.projectileSpeed
    projectile.timer = 0
    projectile.duration = enemy.projectileDuration
    projectile.damage = enemy.projectileDamage
    projectile.owner = enemy
    projectile.dead = false
    projectile.collider = enemies.world:newCollider("Circle", {
        projectile.x,
        projectile.y,
        enemy.projectileSize
    })
    projectile.collider:setType("dynamic")
    projectile.collider:setSensor(true)
    projectile.collider:setFixedRotation(true)
    projectile.collider:setBullet(true)
    projectile.collider.identity = "EnemyBullet"
    projectile.collider.parent = projectile
    projectile.collider:setLinearVelocity(
        math.cos(projectile.angle) * projectile.speed,
        math.sin(projectile.angle) * projectile.speed)

    function projectile.collider:enter(other, contact)
        if projectile.dead then return end

        if other.identity == "player1" or other.identity == "player2" then
            return function()
                if projectile.dead or projectile.collider:isDestroyed() then return end

                local player = other.identity == "player1" and player1 or player2
                if player
                    and (player.guardDashProtectTimer or 0) > 0
                    and player.guardDashAngle then
                    local px, py = player.collider:getPosition()
                    local bx, by = projectile.collider:getPosition()
                    local frontX = math.cos(player.guardDashAngle)
                    local frontY = math.sin(player.guardDashAngle)
                    local frontDot = (bx - px) * frontX + (by - py) * frontY

                    if frontDot > 0 then
                        projectile.collider:destroy()
                        projectile.dead = true
                        return
                    end
                end

                if player then
                    player.current_hp = math.max(0, player.current_hp - projectile.damage)
                end
                projectile.collider:destroy()
                projectile.dead = true
            end
        end
    end

    table.insert(enemies.projectiles, projectile)
end

function enemies.spawn(enemyType, x, y, world, size_multiplier, hp_multiplier, speed_multiplier, initial_damage)
    assert(enemies[enemyType], "Tipo de enemigo no definido: " .. tostring(enemyType)) -- Input error check
    enemies.world = world
    local enemyType = enemies[enemyType]

    ---- Default values ----
    size_multiplier = size_multiplier or 1
    hp_multiplier = hp_multiplier or 1
    speed_multiplier = speed_multiplier or 1
    initial_damage = initial_damage or 0

    ---- Create enemy ----
    local new_enemy = {}
    new_enemy.x = x
    new_enemy.y = y
    new_enemy.spriteWidth = enemyType.spriteW * size_multiplier
    new_enemy.spriteHeight = enemyType.spriteH * size_multiplier
    new_enemy.width = enemyType.hitboxW * size_multiplier
    new_enemy.height = enemyType.hitboxH * size_multiplier
    new_enemy.hitboxOffsetX = (enemyType.hitboxOffsetX or 0) * size_multiplier
    new_enemy.hitboxOffsetY = (enemyType.hitboxOffsetY or 0) * size_multiplier
    new_enemy.hp = enemyType.hp * hp_multiplier
    new_enemy.current_hp = new_enemy.hp - initial_damage
    new_enemy.speed = enemyType.speed * speed_multiplier
    new_enemy.sprite = enemies.sprites[enemyType.spriteName]
    new_enemy.hitTimer = 0
    new_enemy.shootInterval = enemyType.shootInterval
    new_enemy.shootTimer = enemyType.shootInterval or 0
    new_enemy.shootAngle = enemyType.shootAngle
    new_enemy.projectileSpeed = enemyType.projectileSpeed
    new_enemy.projectileSize = enemyType.projectileSize
    new_enemy.projectileDuration = enemyType.projectileDuration
    new_enemy.projectileDamage = enemyType.projectileDamage

    if enemyType.hitboxCornerRadius then
        new_enemy.collider = world:newCollider(
            "Polygon",
            makeRoundedRectanglePoints(
                new_enemy.width,
                new_enemy.height,
                enemyType.hitboxCornerRadius * size_multiplier))
        new_enemy.collider:setPosition(
            new_enemy.x + new_enemy.hitboxOffsetX,
            new_enemy.y + new_enemy.hitboxOffsetY)
    else
        new_enemy.collider = world:newCollider("Rectangle",{
            new_enemy.x + new_enemy.hitboxOffsetX,
            new_enemy.y + new_enemy.hitboxOffsetY,
            new_enemy.width,
            new_enemy.height})
    end
    new_enemy.collider:setType(enemyType.colliderType or "dynamic")
    new_enemy.collider.identity = "Enemy"
    new_enemy.collider.parent   = new_enemy  
    new_enemy.collider:setFixedRotation(true)

    function new_enemy:takeDamage(damage)
        self.current_hp = math.max(0, self.current_hp - damage)
        self.hitTimer = 0.25
    end

    table.insert(enemies.list, new_enemy)
end

function enemies.getDrawPosition(enemy)
    local cx, cy = enemy.collider:getPosition()
    return cx - enemy.hitboxOffsetX, cy - enemy.hitboxOffsetY
end

function enemies.update(dt)
    for _, enemy in ipairs(enemies.list) do
        if enemy.hitTimer > 0 then
            enemy.hitTimer = enemy.hitTimer - dt
        end

        if enemy.shootInterval and enemy.current_hp > 0 then
            enemy.shootTimer = enemy.shootTimer - dt
            if enemy.shootTimer <= 0 then
                spawnProjectile(enemy)
                enemy.shootTimer = enemy.shootInterval
            end
        end

        if enemy.knockbackTimer and enemy.knockbackTimer > 0 then
            local moveTime = math.min(dt, enemy.knockbackTimer)
            local cx, cy = enemy.collider:getPosition()

            enemy.collider:setPosition(
                cx + enemy.knockbackVx * moveTime,
                cy + enemy.knockbackVy * moveTime)

            enemy.knockbackTimer = enemy.knockbackTimer - moveTime
            if enemy.knockbackTimer <= 0 then
                enemy.knockbackVx = nil
                enemy.knockbackVy = nil
                enemy.knockbackTimer = nil
            end
        end
    end

    for i = #enemies.projectiles, 1, -1 do
        local projectile = enemies.projectiles[i]

        if not projectile.dead and not projectile.collider:isDestroyed() then
            projectile.timer = projectile.timer + dt
            local vx, vy = projectile.collider:getLinearVelocity()
            if vx ~= 0 or vy ~= 0 then
                projectile.angle = math.atan2(vy, vx)
            end

            if projectile.timer >= projectile.duration then
                projectile.collider:destroy()
                projectile.dead = true
            end
        end

        if projectile.dead then
            table.remove(enemies.projectiles, i)
        end
    end
end

function enemies.draw(enemy)
    local cx, cy = enemies.getDrawPosition(enemy)
    local sprite = enemy.sprite and enemy.sprite.idle

    if enemy.sprite and enemy.sprite.hit and enemy.hitTimer > 0 then
        local frame = math.floor((0.25 - enemy.hitTimer) / 0.05) + 1
        sprite = enemy.sprite.hit[math.min(frame, #enemy.sprite.hit)]
    end

    if sprite then
        local scaleX = enemy.spriteWidth / sprite:getWidth()
        local scaleY = enemy.spriteHeight / sprite:getHeight()
        local quad = enemy.sprite and enemy.sprite.idleQuad
        local spriteWidth = quad and 16 or sprite:getWidth()
        local spriteHeight = quad and 16 or sprite:getHeight()

        if quad then
            scaleX = enemy.spriteWidth / spriteWidth
            scaleY = enemy.spriteHeight / spriteHeight
            love.graphics.draw(
                sprite,
                quad,
                cx,
                cy,
                nil,
                scaleX,
                scaleY,
                spriteWidth / 2,
                spriteHeight / 2)
        else
            love.graphics.draw(
                sprite,
                cx,
                cy,
                nil,
                scaleX,
                scaleY,
                sprite:getWidth() / 2,
                sprite:getHeight() / 2)
        end
        return
    end

    love.graphics.setColor(0.8, 0.1, 0.1)
    cx, cy = enemy.collider:getPosition()
    love.graphics.rectangle('fill',
        cx - enemy.width / 2,
        cy - enemy.height / 2,
        enemy.width,
        enemy.height)
    love.graphics.setColor(1, 1, 1)
end

function enemies.drawProjectiles()
    local sprite = enemies.sprites.beholder and enemies.sprites.beholder.projectile
    local quad = enemies.sprites.beholder and enemies.sprites.beholder.projectileQuad

    for _, projectile in ipairs(enemies.projectiles) do
        if not projectile.dead and not projectile.collider:isDestroyed() then
            local x, y = projectile.collider:getPosition()

            if sprite and quad then
                love.graphics.draw(
                    sprite,
                    quad,
                    x,
                    y,
                    projectile.angle + math.pi / 2,
                    2,
                    2,
                    8,
                    8)
            else
                love.graphics.setColor(1, 0.2, 0.2)
                love.graphics.circle("fill", x, y, 5)
                love.graphics.setColor(1, 1, 1)
            end
        end
    end
end

return enemies
