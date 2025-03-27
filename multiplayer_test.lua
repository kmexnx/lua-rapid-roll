-- multiplayer_test.lua - Versión simplificada para probar el menú multijugador

local sock = nil
local json = nil

-- Variables para multijugador
local websocket = nil
local is_multiplayer = false
local server_host = "localhost"
local server_port = 8080
local connection_status = "Desconectado"
local connection_error = nil
local show_multiplayer_menu = false

-- Función para cargar módulos de forma segura
function safe_require(module_name)
    local success, result = pcall(function() return require(module_name) end)
    if success then
        print("Cargado módulo: " .. module_name)
        return result
    else
        print("Error al cargar módulo: " .. module_name .. " - " .. tostring(result))
        return nil
    end
end

-- Configuración inicial
function love.load()
    love.window.setTitle("Rapid Roll - Test Multijugador")
    love.window.setMode(400, 600)
    
    -- Intentar cargar los módulos necesarios
    sock = safe_require("sock")
    json = safe_require("dkjson")
    
    print("Presiona 'M' para mostrar el menú multijugador")
    print("Presiona 'ESC' para salir")
end

-- Conectar al servidor WebSocket
function connect_to_server()
    if websocket or not sock then return end
    
    connection_status = "Conectando..."
    connection_error = nil
    
    -- Intentar la conexión
    print("Intentando conectar a " .. server_host .. ":" .. server_port)
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
    connection_status = "Desconectado"
    print("Desconectado del servidor WebSocket")
end

-- Actualizar estado del juego
function love.update(dt)
    if websocket then
        local message, err = websocket:receive()
        if err then
            print("Error al recibir mensaje del servidor: " .. tostring(err))
            -- Si hay un error, podríamos desconectar e intentar reconectar
            disconnect_from_server()
            return
        end
        
        if message then
            if json then
                local data = json.decode(message)
                if data then
                    print("Mensaje recibido: " .. json.encode(data))
                else
                    print("Error al decodificar mensaje JSON del servidor")
                end
            else
                print("Mensaje recibido (no se puede decodificar sin json): " .. message)
            end
        end
    end
end

-- Dibujar elementos del juego
function love.draw()
    -- Dibujar fondo
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    
    -- Mostrar estado de conexión
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Estado: " .. connection_status, 10, 20)
    
    if connection_error then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.print("Error: " .. connection_error, 10, 40)
    end
    
    -- Instrucciones
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Presiona 'M' para " .. (show_multiplayer_menu and "ocultar" or "mostrar") .. " menú multijugador", 10, love.graphics.getHeight() - 50)
    love.graphics.print("Presiona 'ESC' para salir", 10, love.graphics.getHeight() - 30)
    
    -- Dibujar menú multijugador si está activo
    if show_multiplayer_menu then
        drawMultiplayerMenu()
    end
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
        options[1] = "1. Conectar al servidor (" .. server_host .. ":" .. server_port .. ")"
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

-- Manejo de teclas
function love.keypressed(key)
    print("Tecla presionada: " .. key)
    
    if key == 'escape' then
        if show_multiplayer_menu then
            show_multiplayer_menu = false
        else
            love.event.quit()
        end
    elseif key == 'm' then
        -- Mostrar/ocultar menú multijugador
        show_multiplayer_menu = not show_multiplayer_menu
        print("Menú multijugador: " .. (show_multiplayer_menu and "Mostrado" or "Oculto"))
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
            -- Cambiar host
            local hosts = {"localhost", "127.0.0.1", "ws.example.com"}
            local currentIndex = 1
            for i, host in ipairs(hosts) do
                if host == server_host then
                    currentIndex = i
                    break
                end
            end
            server_host = hosts[(currentIndex % #hosts) + 1]
            print("Host cambiado a: " .. server_host)
        elseif key == '3' then
            -- Cambiar puerto
            local ports = {8080, 8081, 8082, 9000}
            local currentIndex = 1
            for i, port in ipairs(ports) do
                if port == server_port then
                    currentIndex = i
                    break
                end
            end
            server_port = ports[(currentIndex % #ports) + 1]
            print("Puerto cambiado a: " .. server_port)
        elseif key == '4' then
            show_multiplayer_menu = false
            print("Menú multijugador: Oculto")
        end
    end
end

-- Función para cerrar conexiones al salir
function love.quit()
    if websocket then
        websocket:close()
        print("Conexión WebSocket cerrada")
    end
    return false
end
