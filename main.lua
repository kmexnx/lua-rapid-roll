-- Rapid Roll en Lua con LÖVE y gráficos SCUM
-- Autor: Claude

local sock = require("sock") -- Incluir el módulo de WebSockets
-- local json = require("dkjson") -- Para codificar/decodificar mensajes JSON

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

-- Variables para multijugador
local websocket = nil
local client_id = nil
local opponents = {} -- Lista de oponentes
local leaderboard = {} -- Tabla de clasificación
local is_multiplayer = false -- Modo multijugador activado/desactivado
local server_host = "localhost"
local server_port = 8080
local update_timer = 0
local update_interval = 0.1 -- Enviar actualizaciones cada 0.1 segundos
local connection_status = "Desconectado"
local connection_error = nil
local show_multiplayer_menu = false

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

-- Conectar al servidor WebSocket
function connect_to_server()
    if websocket then return end
    
    connection_status = "Conectando..."
    connection_error = nil
    
    -- Intentar la conexión
    local ws, err = sock.connect(server_host, server_port)
    
    if not ws then
        connection_status = "Error de conexión"
        connection_error = err
        print("Error al conectar al servidor WebSocket: " .. tostring(err))
        return false
    end
    
    websocket = ws
    is_multiplayer = true
    connection_status = "Conectado"
    print("Conectado al servidor WebSocket")
    return true
end

-- Desconectar del servidor WebSocket
function disconnect_from_server()
    if not websocket then return end
    
    websocket:close()
    websocket = nil
    is_multiplayer = false
    opponents = {}
    leaderboard = {}
    client_id = nil
    connection_status = "Desconectado"
    print("Desconectado del servidor WebSocket")
end

-- Manejar mensajes del servidor
function handle_server_messages()
    if not websocket then return end
    
    local message, err = websocket:receive()
    if err then
        print("Error al recibir mensaje del servidor: " .. tostring(err))
        -- Si hay un error, podríamos desconectar e intentar reconectar
        disconnect_from_server()
        return
    end
    
    if message then
        local data = json.decode(message)
        if not data then
            print("Error al decodificar mensaje JSON del servidor")
            return
        end
        
        if data.type == "welcome" then
            -- Mensaje de bienvenida, almacenar nuestro ID
            client_id = data.client_id
            print("ID de cliente asignado: " .. client_id)
            
            -- Solicitar la tabla de clasificación
            send_to_server({
                type = "get_leaderboard"
            })
            
        elseif data.type == "player_update" then
            -- Actualización de otro jugador
            local opponent_id = data.client_id
            
            -- Actualizar o crear el oponente
            opponents[opponent_id] = opponents[opponent_id] or {
                x = data.player_x,
                y = data.player_y,
                width = player.width,
                height = player.height,
                score = data.score,
                game_speed = data.game_speed
            }
            
            -- Actualizar la posición y puntuación
            opponents[opponent_id].x = data.player_x
            opponents[opponent_id].y = data.player_y
            opponents[opponent_id].score = data.score
            opponents[opponent_id].game_speed = data.game_speed
            
        elseif data.type == "player_joined" then
            -- Nuevo jugador unido
            print("Jugador " .. data.client_id .. " se ha unido")
            
        elseif data.type == "player_left" then
            -- Jugador desconectado
            print("Jugador " .. data.client_id .. " se ha desconectado")
            opponents[data.client_id] = nil
            
        elseif data.type == "player_game_over" then
            -- Otro jugador ha perdido
            print("Jugador " .. data.client_id .. " ha perdido con puntuación " .. data.final_score)
            
            -- Actualizar su estado si aún lo tenemos en la lista
            if opponents[data.client_id] then
                opponents[data.client_id].game_over = true
                opponents[data.client_id].final_score = data.final_score
            end
            
        elseif data.type == "leaderboard" then
            -- Actualizar tabla de clasificación
            leaderboard = data.leaderboard
        end
    end
end

-- Enviar mensaje al servidor
function send_to_server(message)
    if not websocket or not is_multiplayer then return end
    
    local ok, err = websocket:send(json.encode(message))
    if not ok then
        print("Error al enviar mensaje al servidor: " .. tostring(err))
        disconnect_from_server()
    end
end

-- Enviar actualización de estado al servidor
function send_game_update()
    if not websocket or not is_multiplayer or gameOver then return end
    
    send_to_server({
        type = "update",
        player_x = player.x,
        player_y = player.y,
        score = score,
        game_speed = gameSpeed
    })
end

-- Notificar al servidor cuando perdemos
function send_game_over()
    if not websocket or not is_multiplayer then return end
    
    send_to_server({
        type = "game_over",
        score = score
    })
end

-- Actualizar estado del juego
function love.update(dt)
    -- Procesar mensajes del servidor si estamos en modo multijugador
    if is_multiplayer and websocket then
        handle_server_messages()
        
        -- Enviar actualizaciones periódicamente
        update_timer = update_timer + dt
        if update_timer >= update_interval then
            send_game_update()
            update_timer = 0
        end
    end
    
    if gameOver then
        if love.keyboard.isDown('r') then
            resetGame()
        end
        return
    end
    
    -- No actualizar el juego si estamos en el menú multijugador
    if show_multiplayer_menu then
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
            if not player.falling and player.y + player.height == platform.y then
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
        if is_multiplayer then
            send_game_over()
        end
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
    
    -- Dibujar oponentes si estamos en modo multijugador
    if is_multiplayer then
        for id, opponent in pairs(opponents) do
            if id ~= client_id and not opponent.game_over then
                -- Dibujar oponente con color distintivo (semi-transparente)
                love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
                love.graphics.rectangle("fill", opponent.x, opponent.y, opponent.width, opponent.height)
                
                -- Dibujar "cara" del oponente
                love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
                love.graphics.rectangle("fill", opponent.x + 10, opponent.y + 10, 5, 5) -- Ojo izquierdo
                love.graphics.rectangle("fill", opponent.x + 25, opponent.y + 10, 5, 5) -- Ojo derecho
                love.graphics.rectangle("fill", opponent.x + 10, opponent.y + 25, 20, 5) -- Boca
                
                -- Mostrar puntuación del oponente sobre su cabeza
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.print(tostring(opponent.score), opponent.x, opponent.y - 15)
            end
        end
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
    
    -- Mostrar información de multijugador
    if is_multiplayer then
        love.graphics.print("Multijugador: " .. connection_status, 10, 50)
        love.graphics.print("ID: " .. (client_id or "N/A"), 10, 70)
        
        -- Mostrar tabla de clasificación
        love.graphics.print("Clasificación:", 10, 100)
        local yPos = 120
        local playersShown = 0
        
        -- Ordenar jugadores por puntuación
        local sortedPlayers = {}
        
        -- Añadir jugador actual
        table.insert(sortedPlayers, {
            id = "Tú",
            score = score
        })
        
        -- Añadir oponentes
        for id, opponent in pairs(opponents) do
            table.insert(sortedPlayers, {
                id = "Jugador " .. id,
                score = opponent.score
            })
        end
        
        -- Ordenar por puntuación
        table.sort(sortedPlayers, function(a, b) return a.score > b.score end)
        
        -- Mostrar top 5
        for i, player in ipairs(sortedPlayers) do
            if playersShown < 5 then
                love.graphics.print(i .. ". " .. player.id .. ": " .. player.score, 20, yPos)
                yPos = yPos + 20
                playersShown = playersShown + 1
            end
        end
    end
    
    -- Mensaje de game over
    if gameOver then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("GAME OVER!\nPress 'R' to restart", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
    end
    
    -- Dibujar menú multijugador si está activo
    if show_multiplayer_menu then
        drawMultiplayerMenu()
    end
    
    -- Mostrar instrucciones para el menú multijugador
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Presiona 'M' para menú multijugador", 10, love.graphics.getHeight() - 20)
end

-- Dibujar menú de multijugador
function drawMultiplayerMenu()
    -- Fondo semitransparente
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Título
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("MENÚ MULTIJUGADOR", 0, 100, love.graphics.getWidth(), "center")
    
    -- Mostrar estado de conexión
    love.graphics.printf("Estado: " .. connection_status, 0, 140, love.graphics.getWidth(), "center")
    
    -- Mostrar opciones
    local yPos = 200
    local options = {}
    
    if not is_multiplayer then
        options[1] = "1. Conectar al servidor"
    else
        options[1] = "1. Desconectar del servidor"
    end
    
    options[2] = "2. Cambiar host: " .. server_host
    options[3] = "3. Cambiar puerto: " .. server_port
    options[4] = "4. Volver al juego"
    
    for i, option in ipairs(options) do
        love.graphics.printf(option, 50, yPos, love.graphics.getWidth() - 100, "left")
        yPos = yPos + 40
    end
    
    -- Mostrar error de conexión si existe
    if connection_error then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("Error: " .. connection_error, 50, 380, love.graphics.getWidth() - 100, "center")
    end
    
    -- Instrucciones
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Presiona el número correspondiente para seleccionar una opción", 0, 450, love.graphics.getWidth(), "center")
    love.graphics.printf("Presiona 'ESC' para volver al juego", 0, 470, love.graphics.getWidth(), "center")
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
    player.falling = true


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
        if show_multiplayer_menu then
            show_multiplayer_menu = false
        else
            love.event.quit()
        end
    elseif key == 'r' and gameOver then
        resetGame()
    elseif key == 'm' then
        -- Mostrar/ocultar menú multijugador
        show_multiplayer_menu = not show_multiplayer_menu
    end
    
    -- Manejo de opciones del menú multijugador
    if show_multiplayer_menu then
        if key == '1' then
            if not is_multiplayer then
                connect_to_server()
            else
                disconnect_from_server()
            end
        elseif key == '2' then
            -- Cambiar host (solo para demo, en una implementación real debería usar un input de texto)
            local hosts = {"localhost", "127.0.0.1", "ws.example.com"}
            local currentIndex = 1
            for i, host in ipairs(hosts) do
                if host == server_host then
                    currentIndex = i
                    break
                end
            end
            server_host = hosts[(currentIndex % #hosts) + 1]
        elseif key == '3' then
            -- Cambiar puerto (solo para demo)
            local ports = {8080, 8081, 8082, 9000}
            local currentIndex = 1
            for i, port in ipairs(ports) do
                if port == server_port then
                    currentIndex = i
                    break
                end
            end
            server_port = ports[(currentIndex % #ports) + 1]
        elseif key == '4' then
            show_multiplayer_menu = false
        end
    end
end