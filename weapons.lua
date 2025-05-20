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
            --startAngle = player:getAngleToMouse() - weapon.attacks.swing.arc/2,
            --endAngle   = player:getAngleToMouse() + weapon.attacks.swing.arc/2,
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
    newSwing.collider = world:newCollider("Rectangle", {player.x+100 , player.y+100, weapon.length, weapon.width})
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

        --ángulo y posición intermedios
        local currentAngle = currentSwing.startAngle + t * (currentSwing.endAngle - currentSwing.startAngle)
        local cx = player.x + math.cos(currentAngle) * (currentSwing.length/2)
        local cy = player.y  + math.sin(currentAngle) * (currentSwing.length/2)

        currentSwing.collider:setPosition(cx, cy)
        currentSwing.collider:setAngle(currentAngle)
    end

    table.insert(ActiveAttacks, newSwing)
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
