local weapons = {}
local ActiveAttacks = {}     -- la gestiona este módulo

-------- Tabla principal --------

weapons.sword = {
    cooldown  = 0.35,
    damage    = 15,
    range     = 20, -- Que tan lejos del centro del personaje se crean los ataques
    length= 60,
    width = 18,
    attacks = {
        swing = {        
            duration  = 0.20,
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
    newSwing.startAngle = player:getAngleToMouse() - weapon.attacks.swing.arc/2
    newSwing.endAngle   = player:getAngleToMouse() + weapon.attacks.swing.arc/2
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
    cooldown  = 0.1,
    damage    = 1,
    offset     = 20, -- Que tan lejos del centro del personaje se crean los ataques
    range = 300,
    bullet_size = 10,
    attacks = {
        shot = {        
            duration  = 4,
            timer      = 0,
            damage     = 10,
            bullet_speed = 2000
            }
        }
}

function weapons.rifle.attacks.shot:execute(player, world)
    print(">> weapons.sword.swing: iniciando ataque")    

    -------- Instancia del collider --------
    local weapon = weapons.rifle
    local shot = self
    local newShot = {}
    newShot.timer = 0
    newShot.angle = player:getAngleToMouse()
    newShot.collider = world:newCollider("Circle", {player.x , player.y, weapon.bullet_size})
    newShot.collider:setType("kinematic")
    newShot.collider:setSensor(true)
    newShot.collider.identity = "PlayerBullet"
    newShot.dead = false
    print("Collider creado en:", player.x, player.y)
    newShot.collider:setLinearVelocity(math.cos(newShot.angle)*200, math.sin(newShot.angle)*200)

    -- callback de impacto
    function newShot.collider:enter(other, contact)
        
        print(">> swing.collider:enter with", other.identity)
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

----------------------------------------------------------------
--------  Llamada de mantenimiento desde el juego  ------------
----------------------------------------------------------------
function weapons.update(dt)
    for i = #ActiveAttacks, 1, -1 do
        print(ActiveAttacks[i])
        ActiveAttacks[i]:update(dt)
        if ActiveAttacks[i].dead then
            print(">> weapons.update: removiendo swing muerto")
            table.remove(ActiveAttacks, i)
        end
    end
end

return weapons
