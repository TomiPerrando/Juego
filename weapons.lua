local weapons = {}
local swordImage = nil
local swordSlashImage = nil
local swordPackSwingImage = nil
local bulletImage = nil
local swordSlashQuads = {}
local swordPackSwingQuads = {}
local bulletQuad = nil
local bulletImpactQuad = nil
local bulletImpactEffects = {}

local bulletVisual = {
    scale = 2,
    angleOffset = math.pi / 2,
    originX = 2.5,
    originY = 4.5
}

local bulletImpactVisual = {
    duration = 0.12,
    startScale = 0.4,
    endScale = 0.8,
    originX = 16,
    originY = 16
}

local swordVisuals = {
    slash = {
        scaleX = 1.0,
        scaleY = 2.0,
        distance = 45,
        angleOffset = 0,
        originX = 24,
        originY = 23.5
    },
    pack = {
        scale = 1,
        distance = 42,
        angleOffset = math.pi / 2,
        originX = 64,
        originY = 64
    }
}

local function makeQuads(image, frameWidth, frameHeight)
    local quads = {}
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()

    for y = 0, imageHeight - frameHeight, frameHeight do
        for x = 0, imageWidth - frameWidth, frameWidth do
            table.insert(quads, love.graphics.newQuad(x, y, frameWidth, frameHeight, imageWidth, imageHeight))
        end
    end

    return quads
end

local function getAttackFrame(attack, totalFrames)
    local duration = weapons.sword.attacks.swing.duration
    local progress = math.min(attack.timer / duration, 0.999)
    return math.floor(progress * totalFrames) + 1
end

local function getSwordComboDirection(player)
    player.swordComboStep = (player.swordComboStep or 0) + 1
    if player.swordComboStep > 2 then
        player.swordComboStep = 1
    end

    return player.swordComboStep == 1 and 1 or -1
end

local function facePlayerToAngle(player, angle, duration)
    if not player.animations then return end

    local dx = math.cos(angle)
    local dy = math.sin(angle)
    if math.abs(dx) > math.abs(dy) then
        player.attackAnim = dx > 0 and player.animations.right or player.animations.left
    else
        player.attackAnim = dy > 0 and player.animations.down or player.animations.up
    end

    player.anim = player.attackAnim
    player.attackFacingTime = duration
end

----
-- Placeholder visual de ataque
-- Simula que el personaje mete el cuerpo hacia el golpe hasta tener sprites reales.
----

local function startPlayerAttackVisual(player, angle, duration)
    player.attackVisualAngle = angle
    player.attackVisualDuration = duration
    player.attackVisualTimer = duration
    player.attackVisualDistance = 8
end

local function spawnBulletImpact(x, y)
    table.insert(bulletImpactEffects, {
        x = x,
        y = y,
        timer = 0
    })
end

function weapons.load()
    swordImage = love.graphics.newImage("sprites/weapons/swd_iron_blade_01_64x64.png")
    swordSlashImage = love.graphics.newImage("sprites/weapons/pixel_art_sword_slash_sprites.png")
    swordPackSwingImage = love.graphics.newImage("sprites/weapons/swd_iron_blade_01_swing_128x128.png")
    bulletImage = love.graphics.newImage("sprites/weapons/fox_shot_sheet.png")

    swordSlashQuads = makeQuads(swordSlashImage, 64, 47)
    swordPackSwingQuads = makeQuads(swordPackSwingImage, 128, 128)
    -- FS_GUN_YELLOW, id 67 en raw_packs/FoxShotSheet/FoX_const.txt.
    bulletQuad = love.graphics.newQuad(15, 162, 5, 9, bulletImage:getWidth(), bulletImage:getHeight())
    -- FS_L_BALL_YELLOW, id 75. Reutilizado como impacto breve de bala.
    bulletImpactQuad = love.graphics.newQuad(64, 176, 32, 32, bulletImage:getWidth(), bulletImage:getHeight())
end
local ActiveAttacks = {}     -- la gestiona este módulo

-------- Sword --------

weapons.sword = {
    visualMode = "slash", -- "none", "slash", "pack"
    cooldown  = 0.35,
    damage    = 15,
    range     = 20, -- Que tan lejos del centro del personaje se crean los ataques
    length= 60,
    width = 18,
    recoilDistance = 8,
    attacks = {
        swing = {        
            duration  = 0.10,
            timer      = 0,
            damage     = 20,
            arc = math.rad(90)     -- barrido total (90°)
            }
        }
}

function weapons.sword.attacks.swing:execute(player, world)
    print(">> weapons.sword.swing: iniciando ataque")    

    -------- Instancia del collider --------
    local weapon = weapons.sword
    local swing = self
    local newSwing = {}
    newSwing.timer = 0
    newSwing.player = player
    newSwing.baseAngle = getAttackAngle(player)
    newSwing.comboDirection = getSwordComboDirection(player)
    facePlayerToAngle(player, newSwing.baseAngle, swing.duration)
    -- Placeholder visual: lunge del cuerpo sincronizado con el swing.
    startPlayerAttackVisual(player, newSwing.baseAngle, swing.duration)
    if newSwing.comboDirection == 1 then
        newSwing.startAngle = newSwing.baseAngle - weapon.attacks.swing.arc/2
        newSwing.endAngle   = newSwing.baseAngle + weapon.attacks.swing.arc/2
    else
        newSwing.startAngle = newSwing.baseAngle + weapon.attacks.swing.arc/2
        newSwing.endAngle   = newSwing.baseAngle - weapon.attacks.swing.arc/2
    end
    newSwing.didRecoil = false
    newSwing.pendingRecoilAngle = nil
    newSwing.collider = world:newCollider("Rectangle", {player.x , player.y, weapon.length, weapon.width})
    newSwing.collider:setType("dynamic")
    newSwing.collider:setSensor(true)
    newSwing.collider.identity = "PlayerSword"
    newSwing.dead = false
    print("Collider creado en:", player.x, player.y)

    -- callback de impacto
    function newSwing.collider:enter(other, contact)
        print(">> swing.collider:enter with", other.identity)
        if other.identity == "Enemy" then
            print("parent es", other.parent)
            if other.parent.takeDamage then
                other.parent:takeDamage(swing.damage)
            else
                other.parent.current_hp =
                    math.max(0, other.parent.current_hp - swing.damage)
            end
            print("Enemigo HP ahora:", other.parent.current_hp)

            if not newSwing.didRecoil then
                newSwing.pendingRecoilAngle = self:getAngle()
                newSwing.didRecoil = true
            end
        end
    end

    -------- Update --------
    
    function newSwing:update(dt)
        -- avanzar tiempo
        local currentSwing = self
        if currentSwing.pendingRecoilAngle then
            local angle = currentSwing.pendingRecoilAngle
            local px, py = player.collider:getPosition()
            player.collider:setPosition(
                px - math.cos(angle) * weapon.recoilDistance,
                py - math.sin(angle) * weapon.recoilDistance)
            player.x = player.collider:getX()
            player.y = player.collider:getY()
            currentSwing.pendingRecoilAngle = nil
        end

        currentSwing.timer = currentSwing.timer + dt

        local t = currentSwing.timer / swing.duration
        -- destruir al terminar
        if t >= 1 then
            print(">> swing: tiempo cumplido, destruyendo collider")
            currentSwing.collider:destroy()
            currentSwing.dead = true
            return
        end

        -- ángulo y posición intermedios
        local currentAngle = currentSwing.startAngle + t * (currentSwing.endAngle - currentSwing.startAngle)
        local cx = player.x + math.cos(currentAngle) * ((weapon.length/2) + weapon.range)
        local cy = player.y  + math.sin(currentAngle) * ((weapon.length/2) + weapon.range)

        currentSwing.collider:setPosition(cx, cy)
        currentSwing.collider:setAngle(currentAngle)
    end

    table.insert(ActiveAttacks, newSwing)
    print(">> swing agregado, ActiveAttacks =", #ActiveAttacks)
end

weapons.rifle = {
    cooldown  = 0.4,
    damage    = 1,
    offset     = 20, -- Que tan lejos del centro del personaje se crean los ataques
    range = 300,
    bullet_size = 4,
    piercing = false,
    attacks = {
        shot = {        
            duration  = 3,
            timer      = 0,
            damage     = 10,
            bullet_speed = 800
            }
        }
}

function weapons.rifle.attacks.shot:execute(player, world)
    print(">> Shot: iniciando ataque")    

    -------- Instancia del collider --------
    local weapon = weapons.rifle
    local shot = self
    local newShot = {}
    newShot.timer = 0
    newShot.angle = getAttackAngle(player)
    newShot.piercing = weapon.piercing
    newShot.hitEnemies = {}
    facePlayerToAngle(player, newShot.angle, 0.12)
    newShot.collider = world:newCollider("Circle", {player.x , player.y, weapon.bullet_size})
    newShot.collider:setType("dynamic")
    newShot.collider:setSensor(true)
    newShot.collider.identity = "PlayerBullet"
    newShot.collider.parent = newShot
    newShot.collider:setFixedRotation(true)
    newShot.collider:setBullet(true)
    newShot.dead = false
    print("Collider creado en:", player.x, player.y)
    newShot.collider:setLinearVelocity(math.cos(newShot.angle)*shot.bullet_speed, math.sin(newShot.angle)*shot.bullet_speed)

    -- callback de impacto
    function newShot.collider:enter(other, contact)
        if other.identity ~= "Enemy" then return end

        return function()
            if newShot.dead or newShot.collider:isDestroyed() then return end

            local enemy = other.parent
            if not enemy or newShot.hitEnemies[enemy] then return end
            newShot.hitEnemies[enemy] = true

            if enemy.takeDamage then
                enemy:takeDamage(shot.damage)
            else
                enemy.current_hp = math.max(0, enemy.current_hp - shot.damage)
            end
            print("Enemigo HP ahora:", enemy.current_hp)

            local impactX, impactY = newShot.collider:getPosition()
            spawnBulletImpact(impactX, impactY)

            if not newShot.piercing then
                newShot.collider:destroy()
                newShot.dead = true
            end
        end
    end

    -------- Update --------
    
    function newShot:update(dt)
        -- avanzar tiempo
        local currentShot = self
        currentShot.timer = currentShot.timer + dt

        local t = currentShot.timer / shot.duration
        -- destruir al terminar
        if t >= 1 then
            print(">> swing: tiempo cumplido, destruyendo collider")
            currentShot.collider:destroy()
            currentShot.dead = true
            return
        end

        local vx, vy = currentShot.collider:getLinearVelocity()
        if vx ~= 0 or vy ~= 0 then
            currentShot.angle = math.atan2(vy, vx)
        end
    end

    table.insert(ActiveAttacks, newShot)
    print(">> swing agregado, ActiveAttacks =", #ActiveAttacks)
end

-------- Shield --------

currentBlock = newBlock  

weapons.shield = {
    cooldown  = 0.35,
    damage    = 15,
    offset     = 50, -- Que tan lejos del centro del personaje se crean los ataques
    length= 30,
    width = 50,
    attacks = {
        block = {        
            duration  = 0.20,
            timer      = 0,
            damage     = 20,
            arc = math.rad(90)     -- barrido total (90°)
            }
        }
}



function weapons.shield.attacks.block:execute(player, world)
    print(">> Bloqueando")    

    -------- Instancia del collider --------
    local weapon = weapons.shield
    local newBlock = {}
    newBlock.angle = getAttackAngle(player)
    facePlayerToAngle(player, newBlock.angle, weapon.attacks.block.duration)
    newBlock.collider = world:newCollider("Rectangle", {player.x + math.cos(newBlock.angle) * weapon.offset, player.y + math.cos(newBlock.angle) * weapon.offset, weapon.length, weapon.width})
    newBlock.collider:setType("dynamic")
    newBlock.collider:setSensor(true)
    newBlock.collider.identity = "PlayerShield"
    newBlock.dead = false
    print("Collider creado en:", player.x, player.y)

----------------------------------------------------------------
-- callback de impacto dentro de execute
----------------------------------------------------------------
function newBlock.collider:enter(other, contact)
    if other.identity ~= "PlayerBullet" then return end

    -- 1) velocidad actual de la bala
    local vx, vy = other:getLinearVelocity()

    -- 2) normal “geométrica” del escudo  = (cos θ, sin θ)
    --    θ es el ángulo del collider (en radianes)
    local ang = self:getAngle()
    local nx, ny = math.cos(ang), math.sin(ang)

    -- (Si quisieras “hacia afuera” inviertes: nx = -nx, ny = -ny)

    -- 3) reflejar: v' = v - 2⋅(v·n)⋅n
    local dot = vx*nx + vy*ny
    local rx  = vx - 2*dot*nx
    local ry  = vy - 2*dot*ny

    -- 4) amortiguar (sin elasticidad)
    local DAMP = 0.5         -- 0 = se pega, 1 = rebote perfecto
    rx, ry = rx*DAMP, ry*DAMP

    -- 5) asignar la nueva velocidad
    other:setLinearVelocity(rx, ry)

    -- (Opcional) si guardas vx,vy en la tabla-bala:
    if other.parent then
        other.parent.vx, other.parent.vy = rx, ry
    end
end




    -------- Update --------
    
    function newBlock:update(dt)
        local currentBlock = self
        currentBlock.angle = getAttackAngle(player)

        local cx = player.x + math.cos(currentBlock.angle) * (weapon.offset) 
        local cy = player.y  + math.sin(currentBlock.angle) * (weapon.offset)
        
        currentBlock.collider:setPosition(cx, cy)
        currentBlock.collider:setAngle(currentBlock.angle)
    end
    currentBlock = newBlock      
    table.insert(ActiveAttacks, newBlock)
    return newBlock
    --(">> Block agregado, ActiveAttacks =", #ActiveAttacks)
end



----------------------------------------------------------------
--------  Llamada de mantenimiento desde el juego  ------------
----------------------------------------------------------------
function weapons.update(dt)
    for i = #ActiveAttacks, 1, -1 do
        if not ActiveAttacks[i].dead and not ActiveAttacks[i].collider:isDestroyed() then
            ActiveAttacks[i]:update(dt)
        end
        if ActiveAttacks[i].dead then
            print(">> weapons.update: removiendo collider muerto")
            table.remove(ActiveAttacks, i)
        end
    end

    for i = #bulletImpactEffects, 1, -1 do
        local effect = bulletImpactEffects[i]
        effect.timer = effect.timer + dt

        if effect.timer >= bulletImpactVisual.duration then
            table.remove(bulletImpactEffects, i)
        end
    end
end

function weapons.draw()
    if not swordImage then return end

    for _, effect in ipairs(bulletImpactEffects) do
        local progress = effect.timer / bulletImpactVisual.duration
        local alpha = 1 - progress
        local scale = bulletImpactVisual.startScale +
            (bulletImpactVisual.endScale - bulletImpactVisual.startScale) * progress

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(
            bulletImage,
            bulletImpactQuad,
            effect.x,
            effect.y,
            0,
            scale,
            scale,
            bulletImpactVisual.originX,
            bulletImpactVisual.originY)
        love.graphics.setColor(1, 1, 1, 1)
    end

    for _, attack in ipairs(ActiveAttacks) do
        if attack.collider.identity == "PlayerBullet" and not attack.dead and not attack.collider:isDestroyed() then
            local x, y = attack.collider:getPosition()
            love.graphics.draw(
                bulletImage,
                bulletQuad,
                x,
                y,
                attack.angle + bulletVisual.angleOffset,
                bulletVisual.scale,
                bulletVisual.scale,
                bulletVisual.originX,
                bulletVisual.originY)
        end

        if attack.collider.identity == "PlayerSword" and not attack.dead and not attack.collider:isDestroyed() then
            local x, y = attack.collider:getPosition()
            local angle = attack.collider:getAngle()
            local mode = weapons.sword.visualMode

            if mode == "slash" then
                local visual = swordVisuals.slash
                local slashFrame = getAttackFrame(attack, #swordSlashQuads)
                local drawX = attack.player.x + math.cos(attack.baseAngle) * visual.distance
                local drawY = attack.player.y + math.sin(attack.baseAngle) * visual.distance
                local scaleY = visual.scaleY * attack.comboDirection

                love.graphics.draw(
                    swordSlashImage,
                    swordSlashQuads[slashFrame],
                    drawX,
                    drawY,
                    attack.baseAngle + visual.angleOffset,
                    visual.scaleX,
                    scaleY,
                    visual.originX,
                    visual.originY)
            end

            if mode == "pack" then
                local visual = swordVisuals.pack
                local packFrame = getAttackFrame(attack, #swordPackSwingQuads)
                local drawX = attack.player.x + math.cos(attack.baseAngle) * visual.distance
                local drawY = attack.player.y + math.sin(attack.baseAngle) * visual.distance
                local scaleY = visual.scale * attack.comboDirection

                love.graphics.draw(
                    swordPackSwingImage,
                    swordPackSwingQuads[packFrame],
                    drawX,
                    drawY,
                    attack.baseAngle + visual.angleOffset,
                    visual.scale,
                    scaleY,
                    visual.originX,
                    visual.originY)
            else
                love.graphics.draw(
                    swordImage,
                    x,
                    y,
                    angle + math.pi / 2,
                    1,
                    1,
                    swordImage:getWidth() / 2,
                    swordImage:getHeight() / 2)
            end
        end
    end
end

return weapons
