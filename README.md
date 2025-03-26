# Rapid Roll - SCUM Edition

Un juego Rapid Roll implementado en Lua con gráficos de estilo SCUM (ASCII/minimalista) donde la velocidad aumenta conforme el jugador acumula más puntos.

## Descripción

Este juego es una recreación del clásico "Rapid Roll" que estaba presente en los teléfonos Nokia antiguos. El jugador controla un cuadrado que debe mantenerse sobre plataformas en movimiento para no caer. A medida que aumenta la puntuación, la velocidad del juego también aumenta, haciendo que sea cada vez más difícil.

## Características

- Gráficos minimalistas de estilo SCUM (ASCII art en tiempo real)
- Sistema de puntuación
- Dificultad progresiva - El juego se acelera conforme aumenta la puntuación
- Controles simples e intuitivos
- Diferentes tipos de plataformas para añadir variedad y desafío

## Tipos de plataformas

- **Plataformas normales (verdes)**: Plataformas estándar que proporcionan una base estable.
- **Plataformas especiales (azules)**: Más pequeñas que las normales, lo que las hace más difíciles de aterrizar.
- **Plataformas en movimiento (rojas)**: Se mueven horizontalmente, lo que supone un desafío adicional al intentar mantenerse sobre ellas.

## Requisitos

Para ejecutar este juego, necesitarás:

1. [LÖVE2D](https://love2d.org/) (versión 11.3 recomendada)

## Instalación

### Opción 1: Clonar el repositorio

```bash
git clone https://github.com/kmexnx/lua-rapid-roll.git
cd lua-rapid-roll
```

### Opción 2: Descargar como ZIP

1. Haz clic en el botón "Code" en la parte superior de esta página
2. Selecciona "Download ZIP"
3. Descomprime el archivo descargado

## Cómo ejecutar el juego

### En Windows

1. Instala LÖVE2D desde [love2d.org](https://love2d.org/)
2. Arrastra la carpeta del juego al ejecutable `love.exe` o
3. Desde la línea de comandos:
   ```
   "C:\Program Files\LOVE\love.exe" ruta\a\la\carpeta\lua-rapid-roll
   ```

### En macOS

1. Instala LÖVE2D desde [love2d.org](https://love2d.org/)
2. Desde la terminal:
   ```
   /Applications/love.app/Contents/MacOS/love ruta/a/la/carpeta/lua-rapid-roll
   ```

### En Linux

1. Instala LÖVE2D desde tu gestor de paquetes o desde [love2d.org](https://love2d.org/)
2. Desde la terminal:
   ```
   love ruta/a/la/carpeta/lua-rapid-roll
   ```

## Controles

- **Flecha Izquierda** o **A**: Mover jugador a la izquierda
- **Flecha Derecha** o **D**: Mover jugador a la derecha
- **R**: Reiniciar juego después de perder
- **Escape**: Salir del juego

## Reglas del juego

1. Controla el cuadrado (jugador) y evita caer fuera de la pantalla
2. Mantente sobre las plataformas en movimiento
3. Por cada plataforma que sale de la pantalla, ganas 1 punto
4. Cada 10 puntos, la velocidad del juego aumenta
5. ¡El juego termina cuando caes fuera de la pantalla!

## Créditos

Desarrollado con LÖVE2D [https://love2d.org/](https://love2d.org/)

## Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.