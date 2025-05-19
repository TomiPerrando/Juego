local enemies = {}

function enemies.load(world)
    enemies.dummy = {
        x  = 1000,
        y  = 400,
        hp = 100,
        w  = 40,   -- ancho
        h  = 70    -- alto         ←  estas dos líneas faltaban
    }

    local d = enemies.dummy
    d.collider = world:newBSGRectangleCollider(d.x, d.y, d.w, d.h, 8)
    d.collider:setType('static')
    d.collider:setCollisionClass('Enemy')
end


return enemies
