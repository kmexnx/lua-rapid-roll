-- server/main.lua
-- Servidor WebSocket para Rapid Roll Multijugador

local socket = require("socket")
local json = require("dkjson") -- necesitas instalar esta biblioteca con LuaRocks

-- Configuración del servidor
local host = "*"
local port = 8080
local MAX_CLIENTS = 10

-- Estado del servidor
local server = nil
local clients = {}
local game_states = {}
local next_client_id = 1

-- Inicializar el servidor
function init_server()
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
    client.socket:send(frame)
end

-- Enviar un mensaje a todos los clientes excepto al emisor
function broadcast(sender_id, message)
    for id, client in pairs(clients) do
        if id ~= sender_id then
            send_to_client(client, message)
        end
    end
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
    local data = json.decode(message)
    if not data then
        print("Error al decodificar el mensaje JSON del cliente " .. client_id)
        return
    end
    
    if data.type == "update" then
        -- Actualizar el estado del juego para este cliente
        game_states[client_id] = {
            score = data.score,
            player_x = data.player_x,
            player_y = data.player_y,
            game_speed = data.game_speed,
            timestamp = os.time()
        }
        
        -- Transmitir la actualización a otros clientes
        broadcast(client_id, {
            type = "player_update",
            client_id = client_id,
            score = data.score,
            player_x = data.player_x,
            player_y = data.player_y,
            game_speed = data.game_speed
        })
    elseif data.type == "game_over" then
        -- Notificar a otros clientes que este jugador ha perdido
        broadcast(client_id, {
            type = "player_game_over",
            client_id = client_id,
            final_score = data.score
        })
    elseif data.type == "get_leaderboard" then
        -- Enviar tabla de puntuaciones al cliente
        local leaderboard = {}
        for id, state in pairs(game_states) do
            table.insert(leaderboard, {
                client_id = id,
                score = state.score
            })
        end
        
        -- Ordenar por puntuación
        table.sort(leaderboard, function(a, b) return a.score > b.score end)
        
        send_to_client(clients[client_id], {
            type = "leaderboard",
            leaderboard = leaderboard
        })
    end
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

-- Ciclo principal del servidor
function server_loop()
    if not server then
        print("El servidor no está inicializado")
        return
    end
    
    while true do
        -- Aceptar nuevas conexiones
        local client_socket = server:accept()
        if client_socket then
            client_socket:settimeout(0)
            
            local client = {
                socket = client_socket,
                buffer = "",
                handshake_complete = false,
                id = next_client_id
            }
            
            clients[next_client_id] = client
            print("Nuevo cliente conectado: " .. next_client_id)
            next_client_id = next_client_id + 1
        end
        
        -- Procesar datos de los clientes
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
                        message = "Bienvenido al servidor de Rapid Roll"
                    })
                    
                    -- Notificar a otros clientes sobre el nuevo jugador
                    broadcast(id, {
                        type = "player_joined",
                        client_id = id
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
                    print("Cliente " .. id .. " desconectado")
                    client.socket:close()
                    clients[id] = nil
                    game_states[id] = nil
                    
                    -- Notificar a otros clientes sobre la desconexión
                    broadcast(id, {
                        type = "player_left",
                        client_id = id
                    })
                else
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
                            print("Cliente " .. id .. " solicitó cierre")
                            client.socket:close()
                            clients[id] = nil
                            game_states[id] = nil
                            
                            -- Notificar a otros clientes sobre la desconexión
                            broadcast(id, {
                                type = "player_left",
                                client_id = id
                            })
                            break
                        end
                        
                        -- Eliminar el frame procesado del buffer
                        client.buffer = client.buffer:sub(frame.next_offset + 1)
                    end
                end
            end
        end
        
        -- Pequeña pausa para no saturar la CPU
        socket.sleep(0.01)
    end
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
    if server then
        -- Aceptar nuevas conexiones
        local client_socket = server:accept()
        if client_socket then
            client_socket:settimeout(0)
            
            local client = {
                socket = client_socket,
                buffer = "",
                handshake_complete = false,
                id = next_client_id
            }
            
            clients[next_client_id] = client
            print("Nuevo cliente conectado: " .. next_client_id)
            next_client_id = next_client_id + 1
        end
        
        -- Procesar datos de los clientes
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
                        message = "Bienvenido al servidor de Rapid Roll"
                    })
                    
                    -- Notificar a otros clientes sobre el nuevo jugador
                    broadcast(id, {
                        type = "player_joined",
                        client_id = id
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
                    print("Cliente " .. id .. " desconectado")
                    client.socket:close()
                    clients[id] = nil
                    game_states[id] = nil
                    
                    -- Notificar a otros clientes sobre la desconexión
                    broadcast(id, {
                        type = "player_left",
                        client_id = id
                    })
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
                            print("Cliente " .. id .. " solicitó cierre")
                            client.socket:close()
                            clients[id] = nil
                            game_states[id] = nil
                            
                            -- Notificar a otros clientes sobre la desconexión
                            broadcast(id, {
                                type = "player_left",
                                client_id = id
                            })
                            break
                        end
                        
                        -- Eliminar el frame procesado del buffer
                        client.buffer = client.buffer:sub(frame.next_offset + 1)
                    end
                end
            end
        end
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Servidor WebSocket de Rapid Roll", 20, 20)
    love.graphics.print("Escuchando en puerto: " .. port, 20, 50)
    love.graphics.print("Clientes conectados: " .. table.maxn(clients), 20, 80)
    
    -- Mostrar lista de clientes
    love.graphics.print("Clientes:", 20, 120)
    local y = 150
    for id, _ in pairs(clients) do
        love.graphics.print("Cliente ID: " .. id, 40, y)
        if game_states[id] then
            love.graphics.print("Puntuación: " .. (game_states[id].score or 0), 180, y)
        end
        y = y + 25
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