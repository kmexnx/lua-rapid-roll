-- server.lua
-- Script principal para iniciar el servidor WebSocket para Rapid Roll Multijugador

-- Este script es solo un lanzador para el servidor
-- Ejecuta este archivo con LÖVE para iniciar el servidor WebSocket
-- Ejemplo: love server.lua

-- Parámetros de línea de comandos
local args = {...}
local port = tonumber(args[1]) or 8080 -- Puerto por defecto: 8080

-- Al ejecutar este archivo directamente con LÖVE, se cargará el server/main.lua
-- Pero configuramos primero la variable de puerto
_G.SERVER_PORT = port

print("Iniciando servidor WebSocket en puerto " .. port)
print("Presiona Ctrl+C para detener el servidor")

-- El archivo server/main.lua se cargará automáticamente por LÖVE
