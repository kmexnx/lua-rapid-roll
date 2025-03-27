-- Configuración para el servidor WebSocket de Rapid Roll
function love.conf(t)
    t.title = "Rapid Roll - Servidor WebSocket"    -- Título de la ventana
    t.version = "11.3"                            -- Versión de LÖVE
    t.window.width = 500                          -- Ancho de la ventana
    t.window.height = 400                         -- Alto de la ventana
    t.window.resizable = true                     -- Permitir redimensionar la ventana
    t.console = true                              -- Activar consola de depuración en Windows
    
    -- Para mayor compatibilidad
    t.window.vsync = 1                            -- Activar vsync
    t.modules.audio = false                       -- Deshabilitar módulos no necesarios para el servidor
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.thread = true                       -- Habilitar el módulo de hilos
    t.modules.keyboard = true                     -- Habilitar el módulo de teclado
    t.modules.mouse = true                        -- Habilitar el módulo de ratón
    t.modules.graphics = true                     -- Habilitar el módulo de gráficos
    t.modules.timer = true                        -- Habilitar el módulo de temporizador
    t.modules.window = true                       -- Habilitar el módulo de ventana
end
