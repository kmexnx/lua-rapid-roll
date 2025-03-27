# Monkey Roll - A Pirate Adventure

Un juego inspirado en Rapid Roll y Monkey Island, donde controlas a un pirata que debe mantenerse a flote sobre plataformas en movimiento. La velocidad aumenta conforme el jugador acumula más puntos.

## Descripción

Este juego es una reimaginación del clásico "Rapid Roll" con un tema inspirado en "The Secret of Monkey Island" de LucasArts. El jugador controla a un pirata que debe mantenerse sobre tablas, barriles y botes flotantes para no caer al agua. A medida que aumenta la puntuación, la velocidad del juego también aumenta, haciendo que sea cada vez más difícil.

## Características

- Gráficos con estilo pirata inspirados en Monkey Island
- Sistema de puntuación con piezas de oro
- Dificultad progresiva - El juego se acelera conforme aumenta la puntuación
- Controles simples e intuitivos
- Diferentes tipos de plataformas flotantes:
  - Tablas de madera (normales)
  - Barriles (especiales, más pequeños)
  - Botes (en movimiento horizontal)
- Coleccionables: monedas de oro y calaveras
- Efectos de sonido y música temática (si se agregan los archivos de audio)

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

- **Flecha Izquierda** o **A**: Mover pirata a la izquierda
- **Flecha Derecha** o **D**: Mover pirata a la derecha
- **R**: Reiniciar juego después de perder
- **Escape**: Salir del juego

## Reglas del juego

1. Controla al pirata y evita caer al agua
2. Mantente sobre las plataformas flotantes
3. Por cada plataforma que sale de la pantalla, ganas 1 pieza de oro
4. Recoge monedas de oro para obtener 5 piezas extra
5. Cada 10 piezas, la velocidad del juego aumenta
6. ¡El juego termina cuando caes al agua!

## Personalización

El juego puede personalizarse añadiendo imágenes y sonidos propios:

### Imágenes
Coloca los siguientes archivos en el directorio `images/`:
- `guybrush_right.png` y `guybrush_left.png`: Sprites del pirata
- `plank.png`, `barrel.png`, `rowboat.png`: Sprites de plataformas
- `sea_background.png`: Fondo del océano
- `coin.png` y `skull.png`: Coleccionables

### Sonidos
Coloca los siguientes archivos en el directorio `sounds/`:
- `jump.wav`: Sonido al saltar sobre una plataforma
- `splash.wav`: Sonido al caer al agua
- `coin.wav`: Sonido al recoger una moneda
- `gameover.wav`: Melodía de fin de juego
- `pirate_theme.mp3`: Música de fondo

Si no se encuentran estos archivos, el juego utilizará gráficos simples basados en formas geométricas con temática pirata.

## Estructura del proyecto

```
lua-rapid-roll/
├── main.lua          # Archivo principal del juego
├── conf.lua          # Configuración del juego
├── images/           # Directorio para sprites y gráficos
│   └── README.txt    # Información sobre los archivos de imagen necesarios
├── sounds/           # Directorio para efectos de sonido y música
│   └── README.txt    # Información sobre los archivos de sonido necesarios
├── LICENSE           # Archivo de licencia MIT
└── README.md         # Este archivo
```

## Notas sobre la inspiración en SCUMM/Monkey Island

Este juego es un homenaje a las aventuras gráficas clásicas desarrolladas con el motor SCUMM (Script Creation Utility for Maniac Mansion) de LucasArts, particularmente a "The Secret of Monkey Island". Mientras que el gameplay sigue siendo el de un juego de acción vertical, los elementos visuales, personajes y la estética general se inspiran en el universo pirata de Monkey Island.

Si te gusta este juego y quieres experimentar las auténticas aventuras gráficas SCUMM, te recomendamos:
- Probar los juegos originales de Monkey Island a través de [ScummVM](https://www.scummvm.org/)
- Explorar otros títulos clásicos de LucasArts como Day of the Tentacle, Sam & Max Hit the Road o Full Throttle

## Créditos

- Desarrollado con LÖVE2D [https://love2d.org/](https://love2d.org/)
- Inspirado en The Secret of Monkey Island de LucasArts
- Mecánica basada en el clásico juego Rapid Roll

## Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.