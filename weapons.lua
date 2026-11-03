local weapons = {}
local swordImage = nil
local swordSlashImage = nil
local swordPackSwingImage = nil
local shieldImage = nil
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

local shieldVisual = {
    scale = 0.35,
    finalBashScale = 0.48,
    blockDistance = 28,
    blockRecoilDistance = 10,
    blockRecoilDuration = 0.10,
    bashStartDistance = 26,
    bashEndDistance = 44,
    upFlipThreshold = -0.85,
    originX = 80,
    originY = 80
}

local shieldCounterVisual = {
    scale = 0.55,
    distance = 42
}

local shieldSlamVisual = {
    duration = 0.18,
    baseRadius = 34,
    radiusPerLevel = 16
}

local heldSwordVisual = {
    scale = 1.55,
    distanceX = 30,
    distanceY = 8,
    maxTilt = 0.75,
    behindAngleY = -0.75,
    originX = 32,
    originY = 56
}

local swordVisuals = {
    slash = {
        scaleX = 1.55,
        scaleY = 3.1,
        distance = 45,
        angleOffset = 0,
        originX = 24,
        originY = 23.5
    },
    legacySwingSlash = {
        swordScale = 1.55,
        slashScaleX = 1.55,
        slashScaleY = 3.1,
        slashDelay = 0.035,
        slashDuration = 0.09,
        slashDistance = 45,
        slashFrames = {4, 5},
        slashAngleOffset = 0,
        swordAngleOffset = math.pi / 2,
        slashOriginX = 24,
        slashOriginY = 23.5
    },
    poseSlash = {
        swordScale = 1.55,
        swordDelay = 0.055,
        slashDelay = 0.085,
        slashDuration = 0.085,
        slashFrames = {4, 5},
        slashScaleX = 1.55,
        slashScaleY = 3.1,
        slashDistance = 45,
        slashAngleOffset = 0,
        slashOriginX = 24,
        slashOriginY = 23.5,
        swordAngleOffset = math.pi / 2,
        swordDistance = 50
    },
    pack = {
        scale = 1,
        distance = 42,
        angleOffset = math.pi / 2,
        originX = 64,
        originY = 64
    }
}

local swordVisualPresets = {
    fullbody_pack = {
        usePlayerSprites = true,
        weaponMode = "none"
    },
    modular_legacy_swing_slash = {
        usePlayerSprites = false,
        weaponMode = "legacy_swing_slash"
    },
    modular_pose_slash = {
        usePlayerSprites = false,
        weaponMode = "pose_slash"
    },
    modular_pose_sword_only = {
        usePlayerSprites = false,
        weaponMode = "pose_sword_only"
    },
    modular_sword_only = {
        usePlayerSprites = false,
        weaponMode = "primitive"
    },
    modular_slash_only = {
        usePlayerSprites = false,
        weaponMode = "slash"
    },
    modular_pack_swing = {
        usePlayerSprites = false,
        weaponMode = "pack"
    }
}

local function getSwordVisualPreset()
    return swordVisualPresets[weapons.sword.visualPreset] or swordVisualPresets.fullbody_pack
end

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

local function getTimedFrame(timer, delay, duration, frames)
    if timer < delay then return nil end

    local progress = math.min((timer - delay) / duration, 0.999)
    local frameIndex = math.floor(progress * #frames) + 1
    return frames[frameIndex]
end

local function getSwordComboStep(player, comboWindow)
    local now = love.timer.getTime()
    if (player.heldSwordPoseTimer or 0) <= 0
        and (not player.swordComboLastTime or now - player.swordComboLastTime > comboWindow) then
        player.swordComboStep = 0
    end

    player.swordComboStep = (player.swordComboStep or 0) + 1
    if player.swordComboStep > 2 then
        player.swordComboStep = 1
    end

    player.swordComboLastTime = now
    return player.swordComboStep
end

local function updateHeldSwordPose(player, dt)
    if not player or player.currentWeapon ~= "sword" then return end

    if (player.heldSwordPoseDelay or 0) > 0 then
        player.heldSwordPoseDelay = math.max(0, player.heldSwordPoseDelay - dt)
    end

    if (player.heldSwordPoseTimer or 0) > 0 then
        player.heldSwordPoseTimer = math.max(0, player.heldSwordPoseTimer - dt)
        if player.heldSwordPoseTimer == 0 then
            player.heldSwordPoseAngle = nil
            player.swordComboStep = 0
            player.swordComboLastTime = nil
        end
    end
end

local function getShieldComboStep(player, comboWindow)
    local now = love.timer.getTime()
    if not player.shieldComboLastTime or now - player.shieldComboLastTime > comboWindow then
        player.shieldComboStep = 0
    end

    player.shieldComboStep = (player.shieldComboStep or 0) + 1
    if player.shieldComboStep > 3 then
        player.shieldComboStep = 1
    end
    player.shieldComboLastTime = now

    return player.shieldComboStep
end

local function getShieldChargeLevel(player)
    local points = player.shieldChargePoints or 0
    if points >= 7 then return 3 end
    if points >= 4 then return 2 end
    if points >= 1 then return 1 end
    return 0
end

local function addShieldCharge(player, amount)
    player.shieldChargePoints = math.min(9, (player.shieldChargePoints or 0) + amount)
end

local function facePlayerToAngle(player, angle, duration)
    if not player.animations then return end

    local dx = math.cos(angle)
    local dy = math.sin(angle)
    if math.abs(dx) > 0.05 then
        player.visualDirectionX = dx > 0 and 1 or -1
    end

    if math.abs(dx) > math.abs(dy) then
        player.attackAnim = dx > 0 and player.animations.right or player.animations.left
        player.facing = dx > 0 and "right" or "left"
    else
        player.attackAnim = dy > 0 and player.animations.down or player.animations.up
        player.facing = dy > 0 and "down" or "up"
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
    player.attackVisualDistance = player.currentWeapon == "sword" and 0 or 8
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
    shieldImage = love.graphics.newImage("sprites/weapons/shield_4_160x160.png")
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
    -- Cambiar solo este valor para probar variantes visuales de espada.
    -- Opciones: "fullbody_pack", "modular_pose_slash", "modular_pose_sword_only",
    -- "modular_legacy_swing_slash", "modular_sword_only", "modular_slash_only",
    -- "modular_pack_swing".
    visualPreset = "modular_pose_slash",
    cooldown  = 0.35,
    damage    = 15,
    range     = 20, -- Que tan lejos del centro del personaje se crean los ataques
    length= 60,
    width = 18,
    recoilDistance = 8,
    attacks = {
        swing = {        
            duration  = 0.18,
            comboWindow = 0.55,
            timer      = 0,
            damage     = 20,
            arc = math.rad(90)     -- barrido total (90°)
            }
        }
}

function weapons.swordUsesPlayerSprites()
    return getSwordVisualPreset().usePlayerSprites
end

function weapons.sword.attacks.swing:execute(player, world)
    print(">> weapons.sword.swing: iniciando ataque")    

    -------- Instancia del collider --------
    local weapon = weapons.sword
    local swing = self
    local newSwing = {}
    newSwing.timer = 0
    newSwing.player = player
    newSwing.baseAngle = getAttackAngle(player)
    newSwing.comboStep = getSwordComboStep(player, swing.comboWindow)
    newSwing.comboDirection = newSwing.comboStep == 1 and 1 or -1
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
    player.heldSwordPoseAngle = newSwing.endAngle
    player.heldSwordPoseDelay = swordVisuals.poseSlash.swordDelay
    player.heldSwordPoseTimer = swing.duration + swing.comboWindow
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
    cooldown  = 0.28,
    damage    = 15,
    offset     = 50, -- Que tan lejos del centro del personaje se crean los ataques
    length= 30,
    width = 50,
    attacks = {
        bash = {
            duration = 0.12,
            comboWindow = 0.75,
            damage = 10,
            pushDistance = 36,
            pushDuration = 0.16,
            finalDamage = 16,
            finalPushDistance = 58,
            finalPushDuration = 0.24,
            length = 44,
            width = 38,
            finalLength = 62,
            finalWidth = 54,
            offset = 42
        },
        counter = {
            window = 0.35,
            cooldown = 0.45,
            duration = 0.18,
            damage = 30,
            pushDistance = 100,
            pushDuration = 0.22,
            length = 78,
            width = 58,
            range = 24,
            arc = math.rad(120)
        },
        guardDash = {
            duration = 0.56,
            damage = 4,
            pushDuration = 0.24,
            forwardPushDistance = 82,
            sidePushDistance = 86,
            immediateClearDistance = 28,
            length = 64,
            width = 72,
            offset = 46
        },
        chargedSlam = {
            holdTime = 0.35,
            duration = 0.18,
            cooldown = 0.55,
            baseDamage = 6,
            damagePerLevel = 12,
            baseRadius = 34,
            radiusPerLevel = 16,
            basePushDistance = 28,
            pushDistancePerLevel = 26,
            pushDuration = 0.20
        },
        block = {        
            duration  = 0.20,
            timer      = 0,
            damage     = 20,
            arc = math.rad(90)     -- barrido total (90°)
            }
        }
}


function weapons.shield.attacks.bash:execute(player, world)
    print(">> Shield bash")

    -------- Instancia del collider --------
    local attack = self
    local comboStep = getShieldComboStep(player, attack.comboWindow)
    local isFinalHit = comboStep == 3
    local angle = getAttackAngle(player)
    local length = isFinalHit and attack.finalLength or attack.length
    local width = isFinalHit and attack.finalWidth or attack.width
    local pushDistance = isFinalHit and attack.finalPushDistance or attack.pushDistance
    local pushDuration = isFinalHit and attack.finalPushDuration or attack.pushDuration
    local damage = isFinalHit and attack.finalDamage or attack.damage
    local newBash = {}

    newBash.timer = 0
    newBash.duration = attack.duration
    newBash.player = player
    newBash.angle = angle
    newBash.isFinalHit = isFinalHit
    newBash.hitEnemies = {}
    newBash.collider = world:newCollider("Rectangle", {player.x, player.y, length, width})
    newBash.collider:setType("dynamic")
    newBash.collider:setSensor(true)
    newBash.collider.identity = "PlayerShieldBash"
    newBash.dead = false

    facePlayerToAngle(player, angle, attack.duration)
    -- Placeholder visual: lunge del cuerpo sincronizado con el golpe de escudo.
    startPlayerAttackVisual(player, angle, attack.duration)

    function newBash.collider:enter(other, contact)
        if other.identity ~= "Enemy" then return end

        return function()
            local enemy = other.parent
            if not enemy or newBash.hitEnemies[enemy] then return end

            newBash.hitEnemies[enemy] = true
            if enemy.takeDamage then
                enemy:takeDamage(damage)
            else
                enemy.current_hp = math.max(0, enemy.current_hp - damage)
            end

            enemy.knockbackVx = math.cos(angle) * (pushDistance / pushDuration)
            enemy.knockbackVy = math.sin(angle) * (pushDistance / pushDuration)
            enemy.knockbackTimer = pushDuration
        end
    end

    -------- Update --------

    function newBash:update(dt)
        local currentBash = self

        currentBash.timer = currentBash.timer + dt
        if currentBash.timer >= attack.duration then
            currentBash.collider:destroy()
            currentBash.dead = true
            return
        end

        local cx = player.x + math.cos(currentBash.angle) * attack.offset
        local cy = player.y + math.sin(currentBash.angle) * attack.offset

        currentBash.collider:setPosition(cx, cy)
        currentBash.collider:setAngle(currentBash.angle)
    end

    table.insert(ActiveAttacks, newBash)
end


function weapons.shield.attacks.guardDash:execute(player, world, angle)
    local attack = self
    local newGuardDash = {}

    newGuardDash.timer = 0
    newGuardDash.duration = attack.duration
    newGuardDash.player = player
    newGuardDash.angle = angle
    newGuardDash.hitEnemies = {}
    newGuardDash.collider = world:newCollider("Rectangle", {player.x, player.y, attack.length, attack.width})
    newGuardDash.collider:setType("dynamic")
    newGuardDash.collider:setSensor(true)
    newGuardDash.collider.identity = "PlayerShieldGuardDash"
    newGuardDash.dead = false
    player.guardDashProtectTimer = attack.duration
    player.guardDashAngle = angle

    facePlayerToAngle(player, angle, attack.duration)

    function newGuardDash.collider:enter(other, contact)
        if other.identity == "EnemyBullet" then
            return function()
                if other.parent then
                    other.parent.dead = true
                end
                if not other:isDestroyed() then
                    other:destroy()
                end
            end
        end

        if other.identity ~= "Enemy" then return end

        return function()
            local enemy = other.parent
            if not enemy or newGuardDash.hitEnemies[enemy] then return end

            newGuardDash.hitEnemies[enemy] = true
            if enemy.takeDamage then
                enemy:takeDamage(attack.damage)
            else
                enemy.current_hp = math.max(0, enemy.current_hp - attack.damage)
            end

            local ex, ey = enemy.collider:getPosition()
            local hx, hy = newGuardDash.collider:getPosition()
            local sideX = -math.sin(angle)
            local sideY = math.cos(angle)
            local lateral = (ex - hx) * sideX + (ey - hy) * sideY
            local sideSign = lateral >= 0 and 1 or -1
            local sideStrength = math.min(1, math.abs(lateral) / (attack.width / 2))
            local pushX = math.cos(angle) * attack.forwardPushDistance +
                sideX * sideSign * attack.sidePushDistance * sideStrength
            local pushY = math.sin(angle) * attack.forwardPushDistance +
                sideY * sideSign * attack.sidePushDistance * sideStrength

            local pushLength = math.sqrt(pushX * pushX + pushY * pushY)
            if pushLength > 0 then
                enemy.collider:setPosition(
                    ex + (pushX / pushLength) * attack.immediateClearDistance,
                    ey + (pushY / pushLength) * attack.immediateClearDistance)
            end

            enemy.knockbackVx = pushX / attack.pushDuration
            enemy.knockbackVy = pushY / attack.pushDuration
            enemy.knockbackTimer = attack.pushDuration
        end
    end

    function newGuardDash:update(dt)
        self.timer = self.timer + dt
        if self.timer >= attack.duration then
            self.collider:destroy()
            self.dead = true
            return
        end

        local cx = player.x + math.cos(self.angle) * attack.offset
        local cy = player.y + math.sin(self.angle) * attack.offset
        self.collider:setPosition(cx, cy)
        self.collider:setAngle(self.angle)
    end

    table.insert(ActiveAttacks, newGuardDash)
end


function weapons.shield.attacks.chargedSlam:execute(player, world)
    local attack = self
    local level = getShieldChargeLevel(player)
    local radius = attack.baseRadius + attack.radiusPerLevel * level
    local damage = attack.baseDamage + attack.damagePerLevel * level
    local pushDistance = attack.basePushDistance + attack.pushDistancePerLevel * level
    local angle = getAttackAngle(player)
    local newSlam = {}

    player.shieldChargePoints = 0
    newSlam.timer = 0
    newSlam.duration = attack.duration
    newSlam.player = player
    newSlam.angle = angle
    newSlam.chargeLevel = level
    newSlam.radius = radius
    newSlam.hitEnemies = {}
    newSlam.collider = world:newCollider("Circle", {player.x, player.y, radius})
    newSlam.collider:setType("dynamic")
    newSlam.collider:setSensor(true)
    newSlam.collider.identity = "PlayerShieldChargedSlam"
    newSlam.dead = false

    facePlayerToAngle(player, angle, attack.duration)
    startPlayerAttackVisual(player, angle, attack.duration)

    function newSlam.collider:enter(other, contact)
        if other.identity == "EnemyBullet" then
            return function()
                if other.parent then
                    other.parent.dead = true
                end
                if not other:isDestroyed() then
                    other:destroy()
                end
            end
        end

        if other.identity ~= "Enemy" then return end

        return function()
            local enemy = other.parent
            if not enemy or newSlam.hitEnemies[enemy] then return end

            newSlam.hitEnemies[enemy] = true
            if enemy.takeDamage then
                enemy:takeDamage(damage)
            else
                enemy.current_hp = math.max(0, enemy.current_hp - damage)
            end

            local ex, ey = enemy.collider:getPosition()
            local dx = ex - player.x
            local dy = ey - player.y
            local length = math.sqrt(dx * dx + dy * dy)
            if length == 0 then
                dx, dy, length = math.cos(angle), math.sin(angle), 1
            end

            enemy.knockbackVx = (dx / length) * (pushDistance / attack.pushDuration)
            enemy.knockbackVy = (dy / length) * (pushDistance / attack.pushDuration)
            enemy.knockbackTimer = attack.pushDuration
        end
    end

    function newSlam:update(dt)
        self.timer = self.timer + dt
        if self.timer >= attack.duration then
            self.collider:destroy()
            self.dead = true
            return
        end

        self.collider:setPosition(player.x, player.y)
    end

    table.insert(ActiveAttacks, newSlam)
end


function weapons.shield.attacks.counter:execute(player, world)
    print(">> Shield counter")

    -------- Instancia del collider --------
    local attack = self
    local newCounter = {}
    newCounter.timer = 0
    newCounter.duration = attack.duration
    newCounter.player = player
    newCounter.baseAngle = getAttackAngle(player)
    newCounter.angle = newCounter.baseAngle
    newCounter.startAngle = newCounter.baseAngle - attack.arc / 2
    newCounter.endAngle = newCounter.baseAngle + attack.arc / 2
    newCounter.hitEnemies = {}
    newCounter.collider = world:newCollider("Rectangle", {player.x, player.y, attack.length, attack.width})
    newCounter.collider:setType("dynamic")
    newCounter.collider:setSensor(true)
    newCounter.collider.identity = "PlayerShieldCounter"
    newCounter.dead = false

    facePlayerToAngle(player, newCounter.baseAngle, attack.duration)
    -- Placeholder visual: lunge del cuerpo sincronizado con el contraataque.
    startPlayerAttackVisual(player, newCounter.baseAngle, attack.duration)

    function newCounter.collider:enter(other, contact)
        if other.identity ~= "Enemy" then return end

        return function()
            local enemy = other.parent
            if not enemy or newCounter.hitEnemies[enemy] then return end

            newCounter.hitEnemies[enemy] = true
            if enemy.takeDamage then
                enemy:takeDamage(attack.damage)
            else
                enemy.current_hp = math.max(0, enemy.current_hp - attack.damage)
            end

            enemy.knockbackVx = math.cos(newCounter.baseAngle) * (attack.pushDistance / attack.pushDuration)
            enemy.knockbackVy = math.sin(newCounter.baseAngle) * (attack.pushDistance / attack.pushDuration)
            enemy.knockbackTimer = attack.pushDuration
        end
    end

    -------- Update --------

    function newCounter:update(dt)
        local currentCounter = self
        currentCounter.timer = currentCounter.timer + dt

        if currentCounter.timer >= attack.duration then
            currentCounter.collider:destroy()
            currentCounter.dead = true
            return
        end

        local progress = currentCounter.timer / attack.duration
        currentCounter.angle = currentCounter.startAngle +
            progress * (currentCounter.endAngle - currentCounter.startAngle)
        local cx = player.x + math.cos(currentCounter.angle) * ((attack.length / 2) + attack.range)
        local cy = player.y + math.sin(currentCounter.angle) * ((attack.length / 2) + attack.range)

        currentCounter.collider:setPosition(cx, cy)
        currentCounter.collider:setAngle(currentCounter.angle)
    end

    table.insert(ActiveAttacks, newCounter)
end



function weapons.shield.attacks.block:execute(player, world)
    print(">> Bloqueando")    

    -------- Instancia del collider --------
    local weapon = weapons.shield
    local newBlock = {}
    newBlock.player = player
    newBlock.angle = getAttackAngle(player)
    newBlock.blockRecoilTimer = 0
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
    if other.identity ~= "PlayerBullet" and other.identity ~= "EnemyBullet" then return end

    newBlock.blockRecoilTimer = shieldVisual.blockRecoilDuration

    -- El escudo destruye proyectiles enemigos.
    if other.identity == "EnemyBullet" then
        return function()
            addShieldCharge(player, 1)
            player.shieldCounterTimer = weapons.shield.attacks.counter.window
            if other.parent then
                other.parent.dead = true
            end
            if not other:isDestroyed() then
                other:destroy()
            end
        end
    end

    -- Por ahora, el escudo solo refleja proyectiles aliados.
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
        currentBlock.blockRecoilTimer = math.max(0, currentBlock.blockRecoilTimer - dt)

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
    if player1 then
        player1.guardDashProtectTimer = math.max(0, (player1.guardDashProtectTimer or 0) - dt)
    end
    if player2 then
        player2.guardDashProtectTimer = math.max(0, (player2.guardDashProtectTimer or 0) - dt)
    end

    for i = #ActiveAttacks, 1, -1 do
        if not ActiveAttacks[i].dead and not ActiveAttacks[i].collider:isDestroyed() then
            ActiveAttacks[i]:update(dt)
        end
        if ActiveAttacks[i].dead then
            print(">> weapons.update: removiendo collider muerto")
            table.remove(ActiveAttacks, i)
        end
    end

    updateHeldSwordPose(player1, dt)
    updateHeldSwordPose(player2, dt)

    for i = #bulletImpactEffects, 1, -1 do
        local effect = bulletImpactEffects[i]
        effect.timer = effect.timer + dt

        if effect.timer >= bulletImpactVisual.duration then
            table.remove(bulletImpactEffects, i)
        end
    end
end

local function drawShieldVisual(attack)
    if not shieldImage or not attack.player then return end
    if attack.player.shieldSprites then return end

    local distance = shieldVisual.blockDistance
    if attack.collider.identity == "PlayerShieldBash" then
        local progress = math.min(attack.timer / attack.duration, 1)
        local forwardProgress = progress < 0.5 and progress / 0.5 or 1 - ((progress - 0.5) / 0.5)
        distance = shieldVisual.bashStartDistance +
            (shieldVisual.bashEndDistance - shieldVisual.bashStartDistance) * forwardProgress
    elseif attack.collider.identity == "PlayerShieldGuardDash" then
        distance = shieldVisual.bashEndDistance
    elseif attack.collider.identity == "PlayerShieldCounter" then
        distance = shieldCounterVisual.distance
    elseif attack.blockRecoilTimer and attack.blockRecoilTimer > 0 then
        local recoilProgress = attack.blockRecoilTimer / shieldVisual.blockRecoilDuration
        distance = distance - shieldVisual.blockRecoilDistance * recoilProgress
    end

    local x = attack.player.x + math.cos(attack.angle) * distance
    local y = attack.player.y + math.sin(attack.angle) * distance
    local scale = shieldVisual.scale
    if attack.collider.identity == "PlayerShieldCounter" then
        scale = shieldCounterVisual.scale
    elseif attack.collider.identity == "PlayerShieldGuardDash" then
        scale = shieldVisual.finalBashScale
    elseif attack.isFinalHit then
        scale = shieldVisual.finalBashScale
    end
    local scaleY = math.sin(attack.angle) < shieldVisual.upFlipThreshold
        and -scale or scale

    -- Placeholder: usamos la vista frontal del shield 4 para todas las direcciones.
    -- Solo se invierte verticalmente al apuntar hacia arriba.
    love.graphics.draw(
        shieldImage,
        x,
        y,
        0,
        scale,
        scaleY,
        shieldVisual.originX,
        shieldVisual.originY)
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
        if attack.collider.identity == "PlayerShieldChargedSlam" and not attack.dead and not attack.collider:isDestroyed() then
            local progress = math.min(attack.timer / shieldSlamVisual.duration, 1)
            local alpha = 0.45 * (1 - progress)

            love.graphics.setColor(0.45, 0.85, 1, alpha)
            love.graphics.circle("fill", attack.player.x, attack.player.y, attack.radius * progress)
            love.graphics.setColor(1, 1, 1, 1)
        end

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
            local mode = getSwordVisualPreset().weaponMode

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
            elseif mode == "legacy_swing_slash" then
                local visual = swordVisuals.legacySwingSlash
                local slashFrame = getTimedFrame(
                    attack.timer,
                    visual.slashDelay,
                    visual.slashDuration,
                    visual.slashFrames)
                local scaleY = visual.slashScaleY * attack.comboDirection

                -- Legacy ajustado: la espada sigue el swing, pero el slash queda fijo.
                -- El delay evita que el efecto visual se adelante a la espada.
                if slashFrame then
                    local slashX = attack.player.x + math.cos(attack.baseAngle) * visual.slashDistance
                    local slashY = attack.player.y + math.sin(attack.baseAngle) * visual.slashDistance

                    love.graphics.draw(
                        swordSlashImage,
                        swordSlashQuads[slashFrame],
                        slashX,
                        slashY,
                        attack.baseAngle + visual.slashAngleOffset,
                        visual.slashScaleX,
                        scaleY,
                        visual.slashOriginX,
                        visual.slashOriginY)
                end

                love.graphics.draw(
                    swordImage,
                    x,
                    y,
                    angle + visual.swordAngleOffset,
                    visual.swordScale,
                    visual.swordScale,
                    swordImage:getWidth() / 2,
                    swordImage:getHeight() / 2)
            elseif mode == "pose_slash" or mode == "pose_sword_only" then
                local visual = swordVisuals.poseSlash
                -- La espada modular persistente se dibuja desde main.lua.
                -- Durante el swing, este bloque solo dibuja el efecto slash.

                if mode == "pose_slash" then
                    local slashFrame = getTimedFrame(
                        attack.timer,
                        visual.slashDelay,
                        visual.slashDuration,
                        visual.slashFrames)

                    if slashFrame then
                        local slashX = attack.player.x + math.cos(attack.baseAngle) * visual.slashDistance
                        local slashY = attack.player.y + math.sin(attack.baseAngle) * visual.slashDistance
                        local scaleY = visual.slashScaleY * attack.comboDirection

                        love.graphics.draw(
                            swordSlashImage,
                            swordSlashQuads[slashFrame],
                            slashX,
                            slashY,
                            attack.baseAngle + visual.slashAngleOffset,
                            visual.slashScaleX,
                            scaleY,
                            visual.slashOriginX,
                            visual.slashOriginY)
                    end
                end
            elseif mode == "pack" then
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
            elseif mode == "primitive" then
                love.graphics.draw(
                    swordImage,
                    x,
                    y,
                    angle + math.pi / 2,
                    heldSwordVisual.scale,
                    heldSwordVisual.scale,
                    swordImage:getWidth() / 2,
                    swordImage:getHeight() / 2)
            end
        end
    end
end

function weapons.drawPlayerOverlays()
    if not shieldImage then return end

    for _, attack in ipairs(ActiveAttacks) do
        if (attack.collider.identity == "PlayerShield"
            or attack.collider.identity == "PlayerShieldBash"
            or attack.collider.identity == "PlayerShieldCounter"
            or attack.collider.identity == "PlayerShieldGuardDash")
            and not attack.dead and not attack.collider:isDestroyed() then
            drawShieldVisual(attack)
        end
    end
end

function weapons.drawHeldWeapon(player, offsetX, offsetY, attackAngle)
    if player.currentWeapon ~= "sword" or not swordImage then return end
    if weapons.swordUsesPlayerSprites() then return end

    local aimX = attackAngle and math.cos(attackAngle) or 0
    if (player.heldSwordPoseTimer or 0) > 0 then
        if (player.heldSwordPoseDelay or 0) > 0 then return end

        local visual = swordVisuals.poseSlash
        love.graphics.draw(
            swordImage,
            player.x + math.cos(player.heldSwordPoseAngle) * visual.swordDistance,
            player.y + math.sin(player.heldSwordPoseAngle) * visual.swordDistance,
            player.heldSwordPoseAngle + visual.swordAngleOffset,
            visual.swordScale,
            visual.swordScale,
            swordImage:getWidth() / 2,
            swordImage:getHeight() / 2)
        return
    end

    local angle = aimX * heldSwordVisual.maxTilt
    local sideAmount = math.max(-1, math.min(1, angle / heldSwordVisual.maxTilt))

    love.graphics.draw(
        swordImage,
        player.x + (offsetX or 0) + sideAmount * heldSwordVisual.distanceX,
        player.y + (offsetY or 0) + heldSwordVisual.distanceY,
        angle,
        heldSwordVisual.scale,
        heldSwordVisual.scale,
        heldSwordVisual.originX,
        heldSwordVisual.originY)
end

function weapons.heldWeaponDrawsBehind(player, attackAngle)
    if player.currentWeapon ~= "sword" then return false end
    local angle = (player.heldSwordPoseTimer or 0) > 0
        and (player.heldSwordPoseAngle or attackAngle)
        or attackAngle
    if not angle then return false end
    return math.sin(angle) < heldSwordVisual.behindAngleY
end

return weapons
