-- Rapid Roll en Lua con LÖVE y gráficos SCUM
-- Autor: Claude

-- Variables globales
local player = {
    x = 0,
    y = 0,
    width = 40,
    height = 40,
    speed = 300,
    falling = true
}

local platforms = {}
local score = 0
local gameOver = false
local gameSpeed = 1.0 -- Multiplicador de velocidad del juego
local speedIncreaseRate = 0.1 -- Aumenta la velocidad cada 10 puntos
local platformsToRemove = {}

-- Configuración inicial
function love.load()
    love.window.setTitle("Rapid Roll - SCUM Edition")
    love.window.setMode(400, 600)
    
    -- Inicializar posición del jugador
    player.x = love.graphics.getWidth() / 2 - player.width / 2
    player.y = 100
    
    -- Inicializar plataformas
    resetGame()
end

-- Actualizar estado del juego
function love.update(dt)
    if gameOver then
        if love.keyboard.isDown('r') then
            resetGame()
        end
        return
    end
    
    -- Aplicar el multiplicador de velocidad al deltatime
    local adjustedDt = dt * gameSpeed
    
    -- Mover jugador horizontalmente
    if love.keyboard.isDown('left') or love.keyboard.isDown('a') then
        player.x = player.x - player.speed * adjustedDt
    end
    if love.keyboard.isDown('right') or love.keyboard.isDown('d') then
        player.x = player.x + player.speed * adjustedDt
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
        if score % 10 == 0 then
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
    player.falling = true
    for _, platform in ipairs(platforms) do
        if checkCollision(player, platform) then
            player.falling = false
            player.y = platform.y - player.height
        end
    end
    
    -- Comprobar si el jugador ha caído fuera de la pantalla
    if player.y > love.graphics.getHeight() then
        gameOver = true
    end
    
    -- Comprobar si el jugador ha subido demasiado
    if player.y < 0 then
        player.y = 0
    end
    
    -- Asegurar que siempre haya suficientes plataformas
    ensurePlatforms()
end

-- Asegurar que siempre haya un mínimo de plataformas
function ensurePlatforms()
    local minPlatforms = 5
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
    -- Dibujar fondo
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    
    -- Dibujar plataformas
    for _, platform in ipairs(platforms) do
        -- Plataformas normales son verdes
        if platform.type == "normal" then
            love.graphics.setColor(0.2, 0.7, 0.3)
        -- Plataformas especiales son azules
        elseif platform.type == "special" then
            love.graphics.setColor(0.2, 0.3, 0.7)
        -- Plataformas en movimiento son rojas
        elseif platform.type == "moving" then
            love.graphics.setColor(0.7, 0.3, 0.2)
        end
        
        love.graphics.rectangle("fill", platform.x, platform.y, platform.width, platform.height)
    end
    
    -- Dibujar jugador (estilo SCUM con caracteres ASCII)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    
    -- Dibujar "cara" del jugador estilo SCUM
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", player.x + 10, player.y + 10, 5, 5) -- Ojo izquierdo
    love.graphics.rectangle("fill", player.x + 25, player.y + 10, 5, 5) -- Ojo derecho
    love.graphics.rectangle("fill", player.x + 10, player.y + 25, 20, 5) -- Boca
    
    -- Mostrar puntuación
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Speed: " .. string.format("%.1f", gameSpeed) .. "x", 10, 30)
    
    -- Mensaje de game over
    if gameOver then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("GAME OVER!\nPress 'R' to restart", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
    end
end

-- Reiniciar el juego
function resetGame()
    -- Reiniciar variables
    score = 0
    gameOver = false
    gameSpeed = 1.0
    
    -- Inicializar plataformas
    platforms = {}
    for i = 1, 5 do
        createPlatform(i * 120)
    end
    
    -- Reiniciar posición del jugador
    player.y = 100
    player.x = love.graphics.getWidth() / 2 - player.width / 2
    player.falling = true
end

-- Crear una nueva plataforma
function createPlatform(y)
    local screenWidth = love.graphics.getWidth()
    local platformTypes = {"normal", "normal", "normal", "special", "moving"}
    local platformType = platformTypes[love.math.random(1, #platformTypes)]
    
    local platform = {
        x = love.math.random(0, screenWidth - 100),
        y = y,
        width = love.math.random(70, 150),
        height = 20,
        type = platformType,
        moveDir = love.math.random(0, 1) == 0 and -1 or 1,
        moveSpeed = love.math.random(30, 70)
    }
    
    -- Ajustar propiedades específicas del tipo
    if platform.type == "special" then
        -- Las plataformas especiales son más cortas
        platform.width = platform.width * 0.7
    elseif platform.type == "moving" then
        -- Las plataformas en movimiento necesitan más propiedades
        platform.originalX = platform.x
        platform.moveRange = love.math.random(30, 80)
    end
    
    table.insert(platforms, platform)
end

-- Comprobar colisión entre jugador y plataforma
function checkCollision(a, b)
    -- Solo detecta colisión cuando el jugador está cayendo y su base está por encima de la plataforma
    return a.falling and
           a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y + a.height >= b.y and
           a.y + a.height <= b.y + b.height / 2
end

-- Manejo de teclas
function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'r' and gameOver then
        resetGame()
    end
end