-- server/main.lua
-- Servidor WebSocket para Rapid Roll Multijugador

local socket = require("socket")
local json = require("dkjson") -- necesitas instalar esta biblioteca con LuaRocks

-- Configuración del servidor
local host = "*"
local port = _G.SERVER_PORT or 8080
local MAX_CLIENTS = 10
local VERSION = "1.0.0"

-- Estado del servidor
local server = nil
local clients = {}
local game_states = {}
local next_client_id = 1
local game_rooms = {}
local next_room_id = 1

-- Estructura para las salas de juego
local function create_room(name, host_id)
    local room = {
        id = next_room_id,
        name = name or "Sala " .. next_room_id,
        host_id = host_id,
        players = {host_id},
        status = "waiting", -- waiting, playing, finished
        max_players = 4,
        created_at = os.time(),
        game_seed = math.random(1, 999999), -- Semilla para generar plataformas idénticas
        platforms = {}, -- Plataformas compartidas
        items = {} -- Ítems compartidos
    }
    
    game_rooms[next_room_id] = room
    next_room_id = next_room_id + 1
    return room
end

-- Inicializar el servidor
function init_server()
    math.randomseed(os.time()) -- Inicializar generador de números aleatorios
    
    server = socket.tcp()
    server:settimeout(0)
    server:setoption("reuseaddr", true)
    
    local success, err = server:bind(host, port)
    if not success then
        print("Error al vincular el servidor: " .. err)
        return false
    end
    
    success, err = server:listen(5)
    if not success then
        print("Error al iniciar la escucha del servidor: " .. err)
        return false
    end
    
    print("Servidor WebSocket iniciado en " .. host .. ":" .. port)
    return true
end

-- Enviar un mensaje a un cliente
function send_to_client(client, message)
    local encoded = json.encode(message)
    local len = #encoded
    local frame = string.char(0x81) -- Text frame, FIN bit set
    
    -- Set payload length
    if len <= 125 then
        frame = frame .. string.char(len)
    elseif len <= 65535 then
        frame = frame .. string.char(126, math.floor(len / 256), len % 256)
    else
        frame = frame .. string.char(127)
        local bytes = {}
        for i = 8, 1, -1 do
            bytes[i] = len % 256
            len = math.floor(len / 256)
        end
        for i = 1, 8 do
            frame = frame .. string.char(bytes[i])
        end
    end
    
    frame = frame .. encoded
    local success, err = client.socket:send(frame)
    if not success then
        print("Error al enviar mensaje a cliente " .. client.id .. ": " .. tostring(err))
    end
    return success
end

-- Enviar un mensaje a todos los clientes excepto al emisor
function broadcast(sender_id, message)
    for id, client in pairs(clients) do
        if id ~= sender_id then
            send_to_client(client, message)
        end
    end
end

-- Enviar un mensaje a todos los jugadores en una sala
function broadcast_to_room(room_id, sender_id, message)
    local room = game_rooms[room_id]
    if not room then return false end
    
    for _, player_id in ipairs(room.players) do
        if player_id ~= sender_id and clients[player_id] then
            send_to_client(clients[player_id], message)
        end
    end
    return true
end

-- Decodificar un mensaje WebSocket
function decode_websocket_frame(data)
    if #data < 2 then return nil, "Datos insuficientes" end
    
    local byte1 = string.byte(data, 1)
    local byte2 = string.byte(data, 2)
    
    local fin = (byte1 & 0x80) == 0x80
    local opcode = byte1 & 0x0F
    local masked = (byte2 & 0x80) == 0x80
    local payload_len = byte2 & 0x7F
    
    local offset = 2
    
    -- Extended payload length
    if payload_len == 126 then
        if #data < 4 then return nil, "Datos insuficientes para tamaño extendido" end
        payload_len = (string.byte(data, 3) << 8) | string.byte(data, 4)
        offset = 4
    elseif payload_len == 127 then
        if #data < 10 then return nil, "Datos insuficientes para tamaño extendido" end
        payload_len = 0
        for i = 3, 10 do
            payload_len = (payload_len << 8) | string.byte(data, i)
        end
        offset = 10
    end
    
    -- Masking key
    local masking_key = nil
    if masked then
        if #data < offset + 4 then return nil, "Datos insuficientes para clave de máscara" end
        masking_key = data:sub(offset + 1, offset + 4)
        offset = offset + 4
    end
    
    -- Payload
    if #data < offset + payload_len then
        return nil, "Datos insuficientes para carga útil"
    end
    
    local payload = data:sub(offset + 1, offset + payload_len)
    
    -- Unmask payload if necessary
    if masked and masking_key then
        local unmasked = {}
        for i = 1, #payload do
            local j = ((i - 1) % 4) + 1
            unmasked[i] = string.char(string.byte(payload, i) ~ string.byte(masking_key, j))
        end
        payload = table.concat(unmasked)
    end
    
    return {
        fin = fin,
        opcode = opcode,
        payload = payload,
        next_offset = offset + payload_len
    }
end

-- Manejar un mensaje de un cliente
function handle_message(client_id, message)
    local data, pos, err = json.decode(message)
    if not data then
        print("Error al decodificar el mensaje JSON del cliente " .. client_id .. ": " .. tostring(err))
        return
    end
    
    -- Determinar el tipo de mensaje y procesarlo
    if data.type == "update" then
        -- Actualizar el estado del juego para este cliente
        game_states[client_id] = {
            score = data.score,
            player_x = data.player_x,
            player_y = data.player_y,
            game_speed = data.game_speed,
            timestamp = os.time()
        }
        
        -- Si el cliente está en una sala, transmitir la actualización a los demás jugadores de la sala
        local room_id = find_player_room(client_id)
        if room_id then
            broadcast_to_room(room_id, client_id, {
                type = "player_update",
                client_id = client_id,
                score = data.score,
                player_x = data.player_x,
                player_y = data.player_y,
                game_speed = data.game_speed
            })
        end
    elseif data.type == "game_over" then
        -- Notificar a otros clientes que este jugador ha perdido
        local room_id = find_player_room(client_id)
        if room_id then
            broadcast_to_room(room_id, client_id, {
                type = "player_game_over",
                client_id = client_id,
                final_score = data.score
            })
            
            -- Comprobar si es el último jugador y finalizar la sala si es necesario
            check_room_status(room_id)
        end
    elseif data.type == "create_room" then
        -- Crear una nueva sala
        local room = create_room(data.room_name, client_id)
        
        -- Notificar al cliente que la sala ha sido creada
        send_to_client(clients[client_id], {
            type = "room_created",
            room_id = room.id,
            room_name = room.name
        })
        
        -- Notificar a todos los clientes sobre la nueva sala
        broadcast(client_id, {
            type = "room_available",
            room_id = room.id,
            room_name = room.name,
            host_id = client_id,
            player_count = 1,
            max_players = room.max_players
        })
    elseif data.type == "join_room" then
        -- Unirse a una sala existente
        local room = game_rooms[data.room_id]
        if not room then
            send_to_client(clients[client_id], {
                type = "error",
                message = "La sala no existe"
            })
            return
        end
        
        if #room.players >= room.max_players then
            send_to_client(clients[client_id], {
                type = "error",
                message = "La sala está llena"
            })
            return
        end
        
        if room.status ~= "waiting" then
            send_to_client(clients[client_id], {
                type = "error",
                message = "La partida ya ha comenzado"
            })
            return
        end
        
        -- Añadir el jugador a la sala
        table.insert(room.players, client_id)
        
        -- Notificar al cliente que se ha unido a la sala
        send_to_client(clients[client_id], {
            type = "room_joined",
            room_id = room.id,
            room_name = room.name,
            players = room.players,
            host_id = room.host_id
        })
        
        -- Notificar a los demás jugadores de la sala
        broadcast_to_room(room.id, client_id, {
            type = "player_joined_room",
            client_id = client_id,
            room_id = room.id
        })
    elseif data.type == "leave_room" then
        -- Abandonar una sala
        local room_id = find_player_room(client_id)
        if room_id then
            remove_player_from_room(client_id, room_id)
        end
    elseif data.type == "start_game" then
        -- Iniciar la partida (solo el host puede hacerlo)
        local room_id = find_player_room(client_id)
        if not room_id then
            send_to_client(clients[client_id], {
                type = "error",
                message = "No estás en ninguna sala"
            })
            return
        end
        
        local room = game_rooms[room_id]
        if room.host_id ~= client_id then
            send_to_client(clients[client_id], {
                type = "error",
                message = "Solo el anfitrión puede iniciar la partida"
            })
            return
        end
        
        if #room.players < 2 then
            send_to_client(clients[client_id], {
                type = "error",
                message = "Se necesitan al menos 2 jugadores para iniciar"
            })
            return
        end
        
        -- Cambiar estado de la sala a "playing"
        room.status = "playing"
        
        -- Generar plataformas compartidas para todos los jugadores
        generate_shared_platforms(room)
        
        -- Notificar a todos los jugadores de la sala que la partida ha comenzado
        for _, player_id in ipairs(room.players) do
            if clients[player_id] then
                send_to_client(clients[player_id], {
                    type = "game_started",
                    room_id = room.id,
                    seed = room.game_seed,
                    platforms = room.platforms,
                    items = room.items
                })
            end
        end
    elseif data.type == "get_rooms" then
        -- Enviar la lista de salas disponibles
        local available_rooms = {}
        for id, room in pairs(game_rooms) do
            if room.status == "waiting" and #room.players < room.max_players then
                table.insert(available_rooms, {
                    id = room.id,
                    name = room.name,
                    player_count = #room.players,
                    max_players = room.max_players,
                    host_id = room.host_id
                })
            end
        end
        
        send_to_client(clients[client_id], {
            type = "room_list",
            rooms = available_rooms
        })
    elseif data.type == "chat" then
        -- Mensaje de chat
        local room_id = find_player_room(client_id)
        if room_id then
            broadcast_to_room(room_id, nil, {
                type = "chat_message",
                client_id = client_id,
                message = data.message
            })
        end
    elseif data.type == "ping" then
        -- Responder con un pong
        send_to_client(clients[client_id], {
            type = "pong",
            timestamp = os.time()
        })
    else
        print("Mensaje desconocido de cliente " .. client_id .. ": " .. message)
    end
end

-- Encontrar la sala donde está un jugador
function find_player_room(player_id)
    for room_id, room in pairs(game_rooms) do
        for _, pid in ipairs(room.players) do
            if pid == player_id then
                return room_id
            end
        end
    end
    return nil
end

-- Eliminar un jugador de una sala
function remove_player_from_room(player_id, room_id)
    local room = game_rooms[room_id]
    if not room then return end
    
    -- Buscar y eliminar al jugador de la lista
    for i, pid in ipairs(room.players) do
        if pid == player_id then
            table.remove(room.players, i)
            break
        end
    end
    
    -- Notificar a los demás jugadores
    broadcast_to_room(room_id, player_id, {
        type = "player_left_room",
        client_id = player_id,
        room_id = room_id
    })
    
    -- Si la sala queda vacía, eliminarla
    if #room.players == 0 then
        game_rooms[room_id] = nil
        return
    end
    
    -- Si el jugador era el anfitrión, asignar un nuevo anfitrión
    if room.host_id == player_id and #room.players > 0 then
        room.host_id = room.players[1]
        
        -- Notificar a los jugadores sobre el nuevo anfitrión
        broadcast_to_room(room_id, nil, {
            type = "new_host",
            host_id = room.host_id,
            room_id = room_id
        })
    end
    
    -- Comprobar el estado de la sala
    check_room_status(room_id)
end

-- Comprobar el estado de una sala y actualizarlo si es necesario
function check_room_status(room_id)
    local room = game_rooms[room_id]
    if not room then return end
    
    -- Si la sala está en partida, comprobar cuántos jugadores siguen activos
    if room.status == "playing" then
        local active_players = 0
        for _, player_id in ipairs(room.players) do
            if game_states[player_id] and not game_states[player_id].game_over then
                active_players = active_players + 1
            end
        end
        
        -- Si solo queda un jugador activo, declararlo ganador
        if active_players <= 1 then
            local winner_id = nil
            for _, player_id in ipairs(room.players) do
                if game_states[player_id] and not game_states[player_id].game_over then
                    winner_id = player_id
                    break
                end
            end
            
            room.status = "finished"
            
            -- Notificar a todos los jugadores de la sala
            for _, player_id in ipairs(room.players) do
                if clients[player_id] then
                    send_to_client(clients[player_id], {
                        type = "game_finished",
                        room_id = room_id,
                        winner_id = winner_id
                    })
                end
            end
        end
    end
end

-- Generar plataformas compartidas para una sala
function generate_shared_platforms(room)
    -- Reiniciar el generador de números aleatorios con la semilla de la sala
    local old_seed = math.randomseed(room.game_seed)
    
    -- Generar plataformas
    room.platforms = {}
    for i = 1, 20 do -- Generar 20 plataformas iniciales
        local platform = {
            id = i,
            x = math.random(10, 400),
            y = i * 100, -- Distribuir verticalmente
            width = math.random(70, 150),
            height = 20,
            type = math.random(1, 100) <= 70 and "normal" or (math.random(1, 100) <= 50 and "special" or "moving"),
        }
        
        -- Propiedades adicionales según el tipo
        if platform.type == "moving" then
            platform.move_dir = math.random(0, 1) == 0 and -1 or 1
            platform.move_speed = math.random(30, 70)
            platform.move_range = math.random(30, 80)
            platform.original_x = platform.x
        end
        
        -- Ítems
        if math.random(1, 100) <= 20 then -- 20% de probabilidad de tener un ítem
            local item = {
                type = math.random(1, 100) <= 70 and "coin" or "skull",
                x = platform.x + platform.width / 2,
                y = platform.y - 30,
                platform_id = i,
                collected = false
            }
            table.insert(room.items, item)
        end
        
        table.insert(room.platforms, platform)
    end
    
    -- Restaurar la semilla original
    math.randomseed(old_seed)
end

-- Manejar el handshake inicial de WebSocket
function handle_websocket_handshake(client)
    local request = ""
    while true do
        local line, err = client.socket:receive("*l")
        if err then return false, "Error al recibir línea: " .. err end
        if line == "" then break end
        request = request .. line .. "\r\n"
    end
    
    -- Extraer la clave Sec-WebSocket-Key
    local key = request:match("Sec-WebSocket-Key: ([A-Za-z0-9+/=]+)")
    if not key then
        return false, "No se encontró la clave Sec-WebSocket-Key"
    end
    
    -- Calcular respuesta de acuerdo al protocolo WebSocket
    local magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    local accept_key = socket.base64.encode(socket.md5.digest(key .. magic))
    
    -- Enviar respuesta
    local response = {
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Accept: " .. accept_key,
        "\r\n"
    }
    
    client.socket:send(table.concat(response, "\r\n"))
    return true
end

-- Procesar conexiones y datos de clientes
function process_clients()
    -- Aceptar nuevas conexiones
    local client_socket = server:accept()
    if client_socket then
        client_socket:settimeout(0)
        
        local client = {
            socket = client_socket,
            buffer = "",
            handshake_complete = false,
            id = next_client_id,
            last_ping = os.time(),
            username = "Jugador " .. next_client_id
        }
        
        clients[next_client_id] = client
        print("Nuevo cliente conectado: " .. next_client_id)
        next_client_id = next_client_id + 1
    end
    
    -- Procesar datos de los clientes existentes
    for id, client in pairs(clients) do
        -- Si el handshake no está completo, intentarlo primero
        if not client.handshake_complete then
            local success, err = handle_websocket_handshake(client)
            if success then
                client.handshake_complete = true
                print("Handshake completado para el cliente " .. id)
                
                -- Enviar mensaje de bienvenida y asignar ID
                send_to_client(client, {
                    type = "welcome",
                    client_id = id,
                    message = "Bienvenido al servidor de Rapid Roll",
                    version = VERSION
                })
            elseif err then
                print("Error en handshake para cliente " .. id .. ": " .. err)
                client.socket:close()
                clients[id] = nil
            end
        else
            -- Recibir datos del cliente
            local data, err, partial = client.socket:receive("*a")
            if err == "closed" then
                handle_client_disconnect(id)
            elseif err ~= "timeout" then
                if data then
                    client.buffer = client.buffer .. data
                elseif partial then
                    client.buffer = client.buffer .. partial
                end
                
                -- Procesar mensajes completos en el buffer
                while #client.buffer > 0 do
                    local frame, err = decode_websocket_frame(client.buffer)
                    if not frame then
                        if err ~= "Datos insuficientes" then
                            print("Error decodificando frame para cliente " .. id .. ": " .. err)
                        end
                        break
                    end
                    
                    if frame.opcode == 0x1 then  -- Text frame
                        handle_message(id, frame.payload)
                    elseif frame.opcode == 0x8 then  -- Close frame
                        handle_client_disconnect(id)
                        break
                    end
                    
                    -- Eliminar el frame procesado del buffer
                    client.buffer = client.buffer:sub(frame.next_offset + 1)
                end
            end
        end
    end
end

-- Manejar la desconexión de un cliente
function handle_client_disconnect(client_id)
    local client = clients[client_id]
    if not client then return end
    
    print("Cliente " .. client_id .. " desconectado")
    
    -- Cerrar socket
    client.socket:close()
    
    -- Eliminar de cualquier sala en la que esté
    local room_id = find_player_room(client_id)
    if room_id then
        remove_player_from_room(client_id, room_id)
    end
    
    -- Eliminar estado del juego
    game_states[client_id] = nil
    
    -- Eliminar cliente
    clients[client_id] = nil
    
    -- Notificar a otros clientes
    broadcast(client_id, {
        type = "player_disconnected",
        client_id = client_id
    })
end

-- Función principal
function love.load()
    if init_server() then
        print("Servidor iniciado. Presiona Ctrl+C para detener.")
    else
        print("Error al inicializar el servidor")
        love.event.quit()
    end
end

function love.update(dt)
    -- Procesar clientes
    if server then
        process_clients()
    end
    
    -- Comprobar conexiones inactivas (cada 30 segundos)
    local current_time = os.time()
    if current_time % 30 == 0 then
        for id, client in pairs(clients) do
            if client.handshake_complete and current_time - client.last_ping > 120 then
                -- Timeout después de 2 minutos sin actividad
                print("Timeout para cliente " .. id)
                handle_client_disconnect(id)
            end
        end
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Servidor WebSocket de Rapid Roll", 20, 20)
    love.graphics.print("Versión: " .. VERSION, 20, 40)
    love.graphics.print("Escuchando en puerto: " .. port, 20, 60)
    love.graphics.print("Clientes conectados: " .. table.maxn(clients), 20, 80)
    
    -- Mostrar lista de clientes
    love.graphics.print("Clientes:", 20, 120)
    local y = 140
    for id, client in pairs(clients) do
        love.graphics.print("Cliente ID: " .. id, 40, y)
        if game_states[id] then
            love.graphics.print("Puntuación: " .. (game_states[id].score or 0), 180, y)
        end
        y = y + 20
    end
    
    -- Mostrar salas
    y = y + 20
    love.graphics.print("Salas:", 20, y)
    y = y + 20
    for id, room in pairs(game_rooms) do
        love.graphics.print("Sala ID: " .. id .. " - " .. room.name .. " (" .. #room.players .. "/" .. room.max_players .. ")", 40, y)
        love.graphics.print("Estado: " .. room.status, 300, y)
        y = y + 20
    end
    
    -- Instrucciones
    love.graphics.print("Presiona Escape para salir", 20, love.graphics.getHeight() - 30)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

-- Cerrar todas las conexiones al salir
function love.quit()
    if server then
        for id, client in pairs(clients) do
            client.socket:close()
        end
        server:close()
        print("Servidor detenido")
    end
    return false
end
