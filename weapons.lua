local weapons = {}
ActiveAttacks = {}     -- la gestiona este módulo

-------- Sword --------

weapons.sword = {
    cooldown  = 0.35,
    damage    = 15,
    range     = 40, -- Que tan lejos del centro del personaje se crean los ataques
    length = 60,
    width = 18,
    attacks = {
        swing = {        
            duration  = 0.2,
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
    newSwing.startAngle = getAngleToMouse(player) - weapon.attacks.swing.arc/2
    newSwing.endAngle   = getAngleToMouse(player) + weapon.attacks.swing.arc/2
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
            other.parent.current_hp =
                math.max(0, other.parent.current_hp - swing.damage)
            print("Enemigo HP ahora:", other.parent.current_hp)
        end
    end

    -------- Update --------
    
    function newSwing:update(dt)
        -- avanzar tiempo
        local currentSwing = self
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
        local cx = player.x + math.cos(currentAngle) * (weapon.length/2)
        local cy = player.y  + math.sin(currentAngle) * (weapon.length/2)

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
    bullet_size = 8,
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
    newShot.angle = getAngleToMouse(player)
    newShot.collider = world:newCollider("Circle", {player.x , player.y, weapon.bullet_size})
    newShot.collider:setType("kinematic")
    newShot.collider:setSensor(true)
    newShot.collider.identity = "PlayerBullet"
    newShot.dead = false
    print("Collider creado en:", player.x, player.y)
    newShot.collider:setLinearVelocity(math.cos(newShot.angle)*shot.bullet_speed, math.sin(newShot.angle)*shot.bullet_speed)

    -- callback de impacto
    function newShot.collider:enter(other, contact)
        
        print(">> shot.collider:enter with", other.identity)
        if other.identity == "Enemy" then
            print("parent es", other.parent)
            other.parent.current_hp =
                math.max(0, other.parent.current_hp - shot.damage)
            print("Enemigo HP ahora:", other.parent.current_hp)
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

        -- ángulo y posición intermedios
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
    newBlock.angle = getAngleToMouse(player)
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
        currentBlock.angle = getAngleToMouse(player)  

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
end

return weapons
