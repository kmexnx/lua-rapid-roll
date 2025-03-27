-- Rapid Roll - Monkey Island Edition
-- Autor: Claude

-- Función para crear un jugador nuevo
function createPlayer()
    return {
        x = love.graphics.getWidth() and love.graphics.getWidth() / 2 - 25 or 240,
        y = 100,
        width = 50,
        height = 60,
        speed = 300,
        falling = true,
        direction = "right", -- Dirección hacia la que mira el jugador
        animTimer = 0,       -- Temporizador para animación
        animFrame = 1,       -- Cuadro actual de animación
        isMoving = false     -- Si el jugador está moviéndose
    }
end

-- Variables globales
local player = createPlayer()
local platforms = {}
local score = 0
local gameOver = false
local gameSpeed = 1.0 -- Multiplicador de velocidad del juego
local speedIncreaseRate = 0.1 -- Aumenta la velocidad cada 10 puntos
local platformsToRemove = {}
local theme = "monkey"

-- Verificar colisión entre rectángulos
function checkRectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x1 + w1 > x2 and
           y1 < y2 + h2 and
           y1 + h1 > y2
end

-- Comprobar colisión entre jugador y plataforma
function checkPlatformCollision(a, b)
    -- Solo detecta colisión cuando el jugador está cayendo y su base está por encima de la plataforma
    return a and a.falling and
           a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y + a.height >= b.y and
           a.y + a.height <= b.y + b.height / 2
end

-- Configuración inicial
function love.load()
    -- Configurar la ventana
    love.window.setTitle("Monkey Roll - A Pirate Adventure")
    love.window.setMode(480, 720)
    
    -- Asegurarse de que player existe
    if not player then
        player = createPlayer()
    end
    
    -- Inicializar posición del jugador
    if player then
        player.x = love.graphics.getWidth() / 2 - player.width / 2
        player.y = 100
    end
    
    -- Inicializar plataformas
    resetGame()
end

-- Actualizar estado del juego
function love.update(dt)
    -- Asegurarse de que player existe
    if not player then
        player = createPlayer()
        resetGame()
        return
    end

    if gameOver then
        if love.keyboard.isDown('r') then
            resetGame()
        end
        return
    end
    
    -- Actualizar la animación del jugador
    player.animTimer = player.animTimer + dt
    if player.animTimer > 0.2 then
        player.animTimer = 0
        player.animFrame = player.animFrame % 2 + 1
    end
    
    -- Resetear flag de movimiento
    player.isMoving = false
    
    -- Aplicar el multiplicador de velocidad al deltatime
    local adjustedDt = dt * gameSpeed
    
    -- Mover jugador horizontalmente
    if love.keyboard.isDown('left') or love.keyboard.isDown('a') then
        player.x = player.x - player.speed * adjustedDt
        player.direction = "left"
        player.isMoving = true
    end
    if love.keyboard.isDown('right') or love.keyboard.isDown('d') then
        player.x = player.x + player.speed * adjustedDt
        player.direction = "right"
        player.isMoving = true
    end
    
    -- Limitar el movimiento horizontal del jugador
    if player.x < 0 then
        player.x = 0
    elseif player.x > love.graphics.getWidth() - player.width then
        player.x = love.graphics.getWidth() - player.width
    end
    
    -- Mover plataformas hacia arriba
    local baseSpeed = 100
    local platformSpeed = baseSpeed * gameSpeed
    
    -- Reset the removal list
    platformsToRemove = {}
    
    for i, platform in ipairs(platforms) do
        platform.y = platform.y - platformSpeed * adjustedDt
        
        -- Actualizar elementos especiales de la plataforma
        if platform.hasItem then
            platform.itemRotation = platform.itemRotation + dt * 2
        end
        
        -- Mover plataformas horizontalmente si son de tipo "moving"
        if platform.type == "moving" then
            -- Actualizar la posición X basada en la dirección y velocidad
            platform.x = platform.x + (platform.moveDir * platform.moveSpeed * adjustedDt)
            
            -- Comprobar límites y cambiar dirección si es necesario
            local minX = platform.originalX - platform.moveRange
            local maxX = platform.originalX + platform.moveRange
            
            if platform.x < minX then
                platform.x = minX
                platform.moveDir = 1  -- Cambiar dirección a derecha
            elseif platform.x > maxX then
                platform.x = maxX
                platform.moveDir = -1 -- Cambiar dirección a izquierda
            end
            
            -- Si el jugador está en esta plataforma, moverlo también
            if player and not player.falling and player.y + player.height <= platform.y + 10 and player.y + player.height >= platform.y - 10 then
                -- Ajustar posición del jugador con la plataforma
                player.x = player.x + (platform.moveDir * platform.moveSpeed * adjustedDt)
                
                -- Asegurarse de que el jugador no se salga de la pantalla
                if player.x < 0 then
                    player.x = 0
                elseif player.x > love.graphics.getWidth() - player.width then
                    player.x = love.graphics.getWidth() - player.width
                end
            end
        end
        
        -- Verificar colisión con ítems
        if player and platform.hasItem and not platform.itemCollected then
            local itemX = platform.x + platform.width/2 - 15
            local itemY = platform.y - 30
            
            if checkRectCollision(player.x, player.y, player.width, player.height, 
                                   itemX, itemY, 30, 30) then
                platform.itemCollected = true
                score = score + 5
            end
        end
        
        -- Marcar plataformas que salen de la pantalla para eliminarlas
        if platform.y + platform.height < 0 then
            table.insert(platformsToRemove, i)
        end
    end
    
    -- Eliminar plataformas en orden inverso para no afectar los índices
    for i = #platformsToRemove, 1, -1 do
        table.remove(platforms, platformsToRemove[i])
        
        -- Aumentar puntuación
        score = score + 1
        
        -- Aumentar velocidad del juego cada 10 puntos
        if score % 10 == 0 and score > 0 then
            gameSpeed = gameSpeed + speedIncreaseRate
        end
        
        -- Crear nueva plataforma en la parte inferior
        createPlatform(love.graphics.getHeight())
    end
    
    -- Aplicar gravedad al jugador
    if player.falling then
        player.y = player.y + 200 * adjustedDt
    end
    
    -- Comprobar colisiones entre jugador y plataformas
    if player then
        player.falling = true
        for _, platform in ipairs(platforms) do
            if checkPlatformCollision(player, platform) then
                player.falling = false
                player.y = platform.y - player.height
            end
        end
    end
    
    -- Comprobar si el jugador ha caído fuera de la pantalla
    if player and player.y > love.graphics.getHeight() then
        gameOver = true
    end
    
    -- Comprobar si el jugador ha subido demasiado
    if player and player.y < 0 then
        player.y = 0
    end
    
    -- Asegurar que siempre haya suficientes plataformas
    ensurePlatforms()
end

-- Asegurar que siempre haya un mínimo de plataformas
function ensurePlatforms()
    local minPlatforms = 7
    local screenHeight = love.graphics.getHeight()
    
    if #platforms < minPlatforms then
        local lastY = 0
        if #platforms > 0 then
            -- Encontrar la plataforma más baja
            for _, platform in ipairs(platforms) do
                if platform.y > lastY then
                    lastY = platform.y
                end
            end
        else
            lastY = screenHeight - 100
        end
        
        -- Añadir una nueva plataforma si no hay suficientes
        if lastY < screenHeight then
            createPlatform(screenHeight)
        end
    end
end

-- Dibujar elementos del juego
function love.draw()
    -- Verificar que player existe
    if not player then
        player = createPlayer()
        resetGame()
        return
    end

    -- Dibujar fondo
    love.graphics.setBackgroundColor(0.2, 0.4, 0.8) -- Color azul océano
    
    -- Asegurarnos que player existe antes de intentar dibujar plataformas
    if not player then return end
    
    -- Dibujar plataformas
    for _, platform in ipairs(platforms) do
        -- Color según tipo de plataforma
        if platform.type == "normal" then
            love.graphics.setColor(0.6, 0.4, 0.2) -- Marrón para tablas
        elseif platform.type == "special" then
            love.graphics.setColor(0.7, 0.6, 0.3) -- Dorado para barriles
        elseif platform.type == "moving" then
            love.graphics.setColor(0.5, 0.3, 0.2) -- Marrón oscuro para botes
        end
        love.graphics.rectangle("fill", platform.x, platform.y, platform.width, platform.height)
        
        -- Dibujar ítem si la plataforma lo tiene
        if platform.hasItem and not platform.itemCollected then
            if platform.itemType == "coin" then
                love.graphics.setColor(1, 0.8, 0)
                love.graphics.circle("fill", platform.x + platform.width/2, platform.y - 20, 10)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.circle("fill", platform.x + platform.width/2, platform.y - 20, 10)
            end
        end
    end
    
    -- Asegurarnos que player existe antes de intentar dibujarlo
    if not player then return end
    
    -- Dibujar jugador (modo simplificado sin imágenes)
    -- Cuerpo
    love.graphics.setColor(0.6, 0.1, 0.1) -- Rojo para el cuerpo
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    
    -- Cara
    love.graphics.setColor(0.9, 0.8, 0.5) -- Color piel
    love.graphics.rectangle("fill", player.x + 10, player.y + 5, player.width - 20, 20)
    
    -- Ojos
    love.graphics.setColor(0, 0, 0)
    if player.direction == "right" then
        love.graphics.rectangle("fill", player.x + player.width - 20, player.y + 10, 5, 5)
        -- Parche de pirata
        love.graphics.rectangle("fill", player.x + 15, player.y + 8, 12, 10)
    else
        love.graphics.rectangle("fill", player.x + 15, player.y + 10, 5, 5)
        -- Parche de pirata
        love.graphics.rectangle("fill", player.x + player.width - 27, player.y + 8, 12, 10)
    end
    
    -- Boca
    love.graphics.rectangle("fill", player.x + 20, player.y + 20, 10, 3)
    
    -- Sombrero de pirata
    love.graphics.setColor(0.1, 0.1, 0.3) -- Azul oscuro
    love.graphics.rectangle("fill", player.x + 5, player.y, player.width - 10, 10)
    love.graphics.rectangle("fill", player.x + 15, player.y - 5, player.width - 30, 5)
    
    -- Mostrar puntuación con estilo de Monkey Island
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", 10, 10, 150, 40, 10, 10)
    love.graphics.setColor(0.6, 0.1, 0.1)
    love.graphics.rectangle("fill", 15, 15, 140, 30, 5, 5)
    love.graphics.setColor(1, 0.8, 0)
    love.graphics.print("Piezas: " .. score, 25, 20, 0, 1.5, 1.5)
    
    -- Mostrar velocidad del barco
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", love.graphics.getWidth() - 160, 10, 150, 40, 10, 10)
    love.graphics.setColor(0.1, 0.3, 0.6)
    love.graphics.rectangle("fill", love.graphics.getWidth() - 155, 15, 140, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Nudos: " .. string.format("%.1f", gameSpeed), love.graphics.getWidth() - 145, 20, 0, 1.5, 1.5)
    
    -- Mensaje de game over
    if gameOver then
        -- Fondo de pergamino
        love.graphics.setColor(0.9, 0.85, 0.7)
        love.graphics.rectangle("fill", 50, love.graphics.getHeight() / 2 - 100, love.graphics.getWidth() - 100, 200, 20, 20)
        -- Borde del pergamino
        love.graphics.setColor(0.6, 0.4, 0.2)
        love.graphics.rectangle("line", 55, love.graphics.getHeight() / 2 - 95, love.graphics.getWidth() - 110, 190, 15, 15)
        
        -- Texto de game over
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.printf("¡Camina la plancha, pirata!\nConseguiste " .. score .. " piezas de oro.\nPresiona 'R' para volver a embarcar.", 
                            70, love.graphics.getHeight() / 2 - 50, love.graphics.getWidth() - 140, "center")
    end
end

-- Reiniciar el juego
function resetGame()
    -- Reiniciar variables
    score = 0
    gameOver = false
    gameSpeed = 1.0
    
    -- Asegurarse de que player existe
    if not player then
        player = createPlayer()
    end
    
    -- Inicializar plataformas
    platforms = {}
    for i = 1, 7 do
        createPlatform(i * 100)
    end
    
    -- Reiniciar posición del jugador
    if player then
        player.y = 100
        player.x = love.graphics.getWidth() / 2 - player.width / 2
        player.falling = true
    end
end

-- Crear una nueva plataforma
function createPlatform(y)
    local screenWidth = love.graphics.getWidth()
    local platformTypes = {"normal", "normal", "normal", "special", "moving"}
    local platformType = platformTypes[love.math.random(1, #platformTypes)]
    
    local width = love.math.random(70, 150)
    if platformType == "special" then
        width = width * 0.7 -- Plataformas especiales son más pequeñas
    end
    
    local platform = {
        x = love.math.random(0, screenWidth - width),
        y = y,
        width = width,
        height = 20,
        type = platformType,
        moveDir = love.math.random(0, 1) == 0 and -1 or 1,
        moveSpeed = love.math.random(30, 70),
        hasItem = love.math.random() > 0.8, -- 20% de probabilidad de tener un ítem
        itemType = love.math.random() > 0.3 and "coin" or "skull",
        itemRotation = 0,
        itemCollected = false
    }
    
    -- Ajustar propiedades específicas del tipo
    if platformType == "moving" then
        -- Las plataformas en movimiento necesitan más propiedades
        platform.originalX = platform.x
        platform.moveRange = love.math.random(30, 80)
    end
    
    table.insert(platforms, platform)
    return platform
end

-- Manejo de teclas
function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'r' and gameOver then
        resetGame()
    end
end