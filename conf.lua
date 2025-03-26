-- Configuración para el juego Rapid Roll en LÖVE
function love.conf(t)
    t.title = "Rapid Roll - SCUM Edition"    -- Título de la ventana
    t.version = "11.3"                        -- Versión de LÖVE
    t.window.width = 400                      -- Ancho de la ventana
    t.window.height = 600                     -- Alto de la ventana
    t.window.resizable = false                -- Permitir redimensionar la ventana
    t.console = false                         -- Activar consola de depuración en Windows
    
    -- Para mayor compatibilidad
    t.window.vsync = 1                        -- Activar vsync
    t.modules.audio = true                    -- Habilitar el módulo de audio
    t.modules.keyboard = true                 -- Habilitar el módulo de teclado
    t.modules.mouse = true                    -- Habilitar el módulo de ratón
    t.modules.graphics = true                 -- Habilitar el módulo de gráficos
    t.modules.timer = true                    -- Habilitar el módulo de temporizador
    t.modules.window = true                   -- Habilitar el módulo de ventana
end
