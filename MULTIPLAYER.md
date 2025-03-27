# Guía de Multijugador para Rapid Roll

Esta guía te ayudará a configurar y solucionar problemas con el modo multijugador de Rapid Roll.

## Requisitos

Para el modo multijugador, necesitas:

1. [LÖVE2D](https://love2d.org/) (versión 11.3 recomendada)
2. [dkjson](https://github.com/LuaDist/dkjson) - Biblioteca JSON para Lua
3. [luasocket](https://github.com/diegonehab/luasocket) - Biblioteca de sockets para Lua

## Instalación de dependencias

### En macOS (con Homebrew)

```bash
brew install luarocks
luarocks install dkjson
luarocks install luasocket
```

### En Windows

```bash
# Instalar LuaRocks (después de instalar LÖVE)
# Luego ejecutar:
luarocks install dkjson
luarocks install luasocket
```

### En Linux

```bash
sudo apt-get install luarocks
sudo luarocks install dkjson
sudo luarocks install luasocket
```

## Diagnóstico de problemas

Si tienes problemas con el modo multijugador, puedes ejecutar los siguientes archivos de diagnóstico:

1. `debug.lua` - Comprueba la instalación y carga de módulos:
   ```bash
   love /ruta/a/lua-rapid-roll/debug.lua
   ```

2. `multiplayer_test.lua` - Prueba específicamente la funcionalidad multijugador:
   ```bash
   love /ruta/a/lua-rapid-roll/ multiplayer_test.lua
   ```

## Problemas comunes

### Error al cargar módulos

Si ves errores como:
```
module 'sock' not found
module 'dkjson' not found
```

Asegúrate de que:
- Has instalado dkjson y luasocket como se describe arriba
- Las bibliotecas están en tu ruta de búsqueda de Lua

### Error al iniciar el servidor

Recuerda que el servidor y el cliente son aplicaciones separadas:

```bash
# Iniciar el servidor (en una terminal)
love /ruta/a/lua-rapid-roll/server

# Iniciar el juego (en otra terminal)
love /ruta/a/lua-rapid-roll
```

### La tecla 'M' no muestra el menú multijugador

Asegúrate de que:
- Estás jugando al juego principal (no al servidor)
- No estás en estado de Game Over
- Las dependencias están correctamente instaladas

## Solución alternativa: Copiar bibliotecas localmente

Si sigue habiendo problemas para encontrar los módulos, prueba copiando las bibliotecas directamente en la carpeta del juego:

1. Encuentra dónde están instaladas tus bibliotecas Lua:
   ```bash
   # En Unix/macOS
   find / -name "dkjson.lua" 2>/dev/null
   find / -name "socket" 2>/dev/null
   
   # En Windows (desde PowerShell)
   Get-ChildItem -Path C:\ -Filter "dkjson.lua" -Recurse -ErrorAction SilentlyContinue
   Get-ChildItem -Path C:\ -Filter "socket" -Recurse -ErrorAction SilentlyContinue
   ```

2. Copia esos archivos a la carpeta de tu juego:
   ```bash
   cp /ruta/a/dkjson.lua /ruta/a/lua-rapid-roll/
   cp -r /ruta/a/socket /ruta/a/lua-rapid-roll/
   ```

## Prueba la conectividad del servidor

Para comprobar que el servidor está funcionando correctamente:

1. Inicia el servidor: `love /ruta/a/lua-rapid-roll/server`
2. Abre un navegador web
3. Navega a: `http://localhost:8080`

Deberías ver un mensaje de error en el navegador (ya que no es una conexión WebSocket propiamente), pero esto confirma que el servidor está escuchando.

## Conexión entre diferentes computadoras

Para jugar en red con otras computadoras:

1. El servidor debe estar en un computador con una IP accesible para todos los jugadores
2. Utiliza la IP del servidor en lugar de "localhost" en el menú multijugador
3. Asegúrate de que el firewall permite conexiones al puerto 8080

## Contacto y soporte

Si sigues teniendo problemas, puedes:
1. Abrir un issue en el repositorio GitHub: https://github.com/kmexnx/lua-rapid-roll/issues
2. Consulta la documentación de LÖVE2D: https://love2d.org/wiki/Main_Page
