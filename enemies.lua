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

enemies.list = {}
enemies.sprites = {}

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

function enemies.spawn(enemyType, x, y, world, size_multiplier, hp_multiplier, speed_multiplier, initial_damage)
    assert(enemies[enemyType], "Tipo de enemigo no definido: " .. tostring(enemyType)) -- Input error check
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
    end
end

function enemies.draw(enemy)
    local cx, cy = enemies.getDrawPosition(enemy)
    local sprite = enemy.sprite and enemy.sprite.idle

    if enemy.sprite and enemy.hitTimer > 0 then
        local frame = math.floor((0.25 - enemy.hitTimer) / 0.05) + 1
        sprite = enemy.sprite.hit[math.min(frame, #enemy.sprite.hit)]
    end

    if sprite then
        local scaleX = enemy.spriteWidth / sprite:getWidth()
        local scaleY = enemy.spriteHeight / sprite:getHeight()

        love.graphics.draw(
            sprite,
            cx,
            cy,
            nil,
            scaleX,
            scaleY,
            sprite:getWidth() / 2,
            sprite:getHeight() / 2)
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

return enemies
