local enemies = {}

---- Dummy ----

enemies.dummy = {}
enemies.dummy.w = 40
enemies.dummy.h = 70
enemies.dummy.hp = 100
enemies.dummy.speed = 0

enemies.list = {}

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
    new_enemy.width = enemyType.w * size_multiplier
    new_enemy.height = enemyType.h * size_multiplier
    new_enemy.hp = enemyType.hp * hp_multiplier
    new_enemy.current_hp = new_enemy.hp - initial_damage
    new_enemy.speed = enemyType.speed * speed_multiplier

    new_enemy.collider = world:newCollider("Rectangle",{new_enemy.x, new_enemy.y,new_enemy.width, new_enemy.height})
    new_enemy.collider:setType('dynamic')
    new_enemy.collider.identity = "Enemy"
    new_enemy.collider.parent   = new_enemy   

    table.insert(enemies.list, new_enemy)
end
return enemies
