local weapons = {}

----------------------------------------------------------------
--------  Lista interna de hitboxes activos de espada  --------
----------------------------------------------------------------
local ActiveSwings = {}     -- la gestiona este módulo

----------------------------------------------------------------
--------  Espada  ---------------------------------------------
----------------------------------------------------------------
weapons.sword = {
    cooldown  = 0.35,
    damage    = 15,
    range     = 60,
    thickness = 18,
    arc       = math.rad(90)     -- barrido total (90°)
}

function weapons.sword.attack(player, world)
    print(">> weapons.sword.attack: iniciando swing")    

    ------------------------------------------------------------
    -- 1. Datos iniciales
    ------------------------------------------------------------
    local weapon = weapons.sword
    local swing = {
        totalTime  = 0.20,
        timer      = 0,
        damage     = 20,
        startAngle = player:getAngleToMouse() - weapon.arc/2,
        endAngle   = player:getAngleToMouse() + weapon.arc/2,
        length     = weapon.range,
        thickness  = weapon.thickness
    }

    ------------------------------------------------------------
    -- 2. Collider rectangular centrado en el jugador
    ------------------------------------------------------------
    swing.collider = world:newCollider("Rectangle", {
        player.x + 100 , player.y+ 100,
        swing.length, swing.thickness})
    swing.collider:setType("kinematic")
    swing.collider:setSensor(true)
    swing.collider.identity = "PlayerSword"
    print("Collider creado en:", player.x, player.y)

    -- callback de impacto
    function swing.collider:enter(other)
        print(">> swing.collider:enter con", other.identity)
        if other.identity == "Enemy" then
            print("parent es", other.parent)
            other.parent.current_hp =
                math.max(0, other.parent.current_hp - swing.damage)
            print("Enemigo HP ahora:", other.parent.current_hp)
        end
    end

    ------------------------------------------------------------
    -- 3. Método update propio
    ------------------------------------------------------------
    function swing:update(dt)
        -- avanzar tiempo
        self.timer = self.timer + dt
        local t = self.timer / self.totalTime

        -- destruir al terminar
        if t >= 1 then
            print(">> swing: tiempo cumplido, destruyendo collider")
            self.collider:destroy()
            self.dead = true
            return
        end

        -- ángulo y posición intermedios
        local curAngle = self.startAngle + t * (self.endAngle - self.startAngle)
        local cx = player.x+100 + math.cos(curAngle) * (self.length/2)
        local cy = player.y+100  + math.sin(curAngle) * (self.length/2)

        self.collider:setPosition(cx, cy)
        self.collider:setAngle(curAngle)
    end

    table.insert(ActiveSwings, swing)
    print(">> swing agregado, ActiveSwings =", #ActiveSwings)
end

----------------------------------------------------------------
--------  Llamada de mantenimiento desde el juego  ------------
----------------------------------------------------------------
function weapons.update(dt)
    for i = #ActiveSwings, 1, -1 do
        local s = ActiveSwings[i]
        s:update(dt)
        if s.dead then
            print(">> weapons.update: removiendo swing muerto")
            table.remove(ActiveSwings, i)
        end
    end
end

return weapons
