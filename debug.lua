-- debug.lua - Archivo para diagnosticar problemas de carga de módulos

-- Función para imprimir información sobre un módulo
function debug_module(name)
    print("Intentando cargar módulo: " .. name)
    local success, result = pcall(function() return require(name) end)
    if success then
        print("Éxito al cargar " .. name)
        return true
    else
        print("Error al cargar " .. name .. ": " .. tostring(result))
        return false
    end
end

-- Función principal
function love.load()
    print("Iniciando diagnóstico de módulos...")
    
    -- Verificar módulos estándar de Lua
    debug_module("socket")
    debug_module("dkjson")
    
    -- Verificar módulo sock.lua
    local sock_result = debug_module("sock")
    
    -- Verificar búsqueda de archivos
    local files = love.filesystem.getDirectoryItems("")
    print("\nArchivos en el directorio raíz:")
    for _, file in ipairs(files) do
        print("- " .. file)
    end
    
    -- Información adicional
    print("\nInformación del sistema:")
    print("LÖVE versión: " .. love.getVersion())
    print("OS: " .. love.system.getOS())
    print("Ruta de trabajo: " .. love.filesystem.getWorkingDirectory())
    print("Ruta base de LÖVE: " .. love.filesystem.getSourceBaseDirectory())
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Ver la consola para información de diagnóstico", 20, 20)
    love.graphics.print("Presiona ESC para salir", 20, 50)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
