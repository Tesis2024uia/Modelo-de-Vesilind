globals [
  sedimentLayer
  sampleInterval
  timeStep
  heightMax
  sedimentRate  ;; Velocidad de sedimentación en m/h (calculada)
  concentration  ;; Concentración en g/L (convertida a número desde el input)
  sedimentV0  ;; Velocidad inicial en m/h
  sedimentK  ;; Constante de Vesilind en L/g
  maxFlocSize
  adhesionProbability
  ivl_real  ;; Índice Volumétrico de Lodos en mL/g
  mantleHeight  ;; Altura actual del manto de lodo en escala gráfica ( 0 a 480)
  vesilindMantleHeight ;; Manto de lodo basado en Vesilind
  alturaRecalculadaH30 ;; Monitor para mostrar la altura recalculada
  sedimentationData ;; Lista para almacenar (timeStep, vesilindMantleHeight)

  ;; Nuevas variables añadidas
  minError  ;; Error mínimo encontrado
  ivl_sim  ;; IVL experimental
  height_simulated  ;; Altura simulada acumulada
  log_height_time  ;; Registro de altura acumulada vs tiempo
  AlturaTakacs    ;; Altura calculada con el modelo de Takács
  AlturaCorre

]

turtles-own [
  reachedBottom
  settlingRate
  flocSize
]

patches-own [
  sedimentDepth
]

to calculateSedimentRate
  ;; Calcula la tasa de sedimentación basada en la fórmula de Vesilind
  set sedimentRate sedimentV0 * exp(-1 * sedimentK * concentration)
end



to calculateIVLSimulated
  ;; Altura simulada basada en Vesilind
  let simulatedHeight heightMax - (sedimentV0 * exp(-1 * sedimentK * concentration) * (maxTime / 60))

  ;; Evitar alturas negativas
  if simulatedHeight < 0 [ set simulatedHeight 0 ]

  ;; IVL simulado en mL/g
  set ivl_sim (simulatedHeight * 1000) / concentration
end

to accumulateMantle
  set log_height_time []
  let delta_t 5
  let currentHeight heightMax
  repeat 6 [
    let sedimentation sedimentV0 * exp(-1 * sedimentK * concentration) * (delta_t / 60)
    set currentHeight currentHeight - sedimentation
    if currentHeight < 0 [ set currentHeight 0 ]
    set log_height_time lput (list timeStep currentHeight) log_height_time
    set mantleHeight currentHeight * 400  ;; Escalar para la gráfica
    tick
  ]
  show (word "Registro de alturas: " log_height_time)
end

to setup
  clear-all

  ;; Variables ajustables
  set sedimentV0 VelocidadInicial  ;; Velocidad inicial en m/h
  set sedimentK ConstanteVesilind ;; Constante de Vesilind en L/g
  set mantleHeight 0  ;; El manto comienza en la base (y = 0)
  set vesilindMantleHeight 0  ;; Inicializa el nuevo manto en 0
  set sedimentationData [] ;; Inicializa la lista de datos de sedimentación
  set ivl_real 80  ;; Valor experimental del IVL
  set log_height_time []  ;; Inicializa el registro

  ;; Validar y convertir concentración
  ifelse is-number? read-from-string InputConcentracion [
    set concentration read-from-string InputConcentracion
  ] [
    user-message "Error: La concentración debe ser un número. Corrige el valor ingresado."
    stop
  ]

  if concentration <= 0 [
    user-message "Error: La concentración debe ser mayor que 0."
    stop
  ]

  set sampleInterval 1 ;; Actualiza cada minuto (tick)
  set maxTime 30  ;; Duración del ensayo en minuto
  set heightMax 0.48  ;; Altura máxima en metros (convertida de cm a m)
  set maxFlocSize 30  ;; Tamaño máximo del flóculo
  set adhesionProbability 0.1  ;; Probabilidad de adhesión (10%)

  ;; Configuración inicial de la capa de sedimento
  set sedimentLayer heightMax
  calculateSedimentRate  ;; Calcula sedimentRate con la concentración proporcionada

  ;; Configuración inicial de parches
  ask patches [
    set pcolor blue
  ]

  ;; Crear bacterias (partículas) proporcional a la concentración
  let numParticles concentration * 5000
  create-turtles numParticles [
    set color brown
    set shape "circle"  ;; Asegura que las tortugas sean redondas
    set size random-normal 1.4 0.4  ;; Tamaño duplicado (antes era 0.7)
    set size max list size 0.2      ;; Tamaño mínimo ajustado al doble (antes era 0.1)
    set settlingRate sedimentRate * random-float 0.9  ;; Usa velocidad inicial variada
    set flocSize 1
    setxy random-xcor random-ycor  ;; Coloca las partículas
    set reachedBottom false
  ]

  ;; Añadir un nuevo gráfico para la concentración
  set-current-plot "Concentración vs Tiempo"
  clear-plot

  set alturaRecalculadaH30 heightMax - (sedimentV0 * exp(-1 * sedimentK * concentration) * maxTime / 60)

  reset-ticks
end
to updateSedimentLayer
  ;; Actualiza la capa de sedimento basada en la tasa de sedimentación
  let currentSedimentLayer sedimentLayer - (sedimentRate / 60 * sampleInterval) ;; Convertir velocidad a m/tick
  if currentSedimentLayer < 1 [
    set sedimentLayer 1
  ]
  set sedimentLayer currentSedimentLayer
end

to updateMantle
  ;; Incrementa la altura del manto de lodo basado en Sedimentacion30min
  let mantleIncrement Sedimentacion30min / maxTime
  set mantleHeight mantleHeight + (mantleIncrement * 400)  ;; Escala de 0 a 480 (gráfica)

  ;; Evita que el manto exceda Sedimentacion30min en escala gráfica
  if mantleHeight > 480 [
    set mantleHeight 0
  ]

  ;; Acumula bacterias en el fondo
  ask turtles [
    if reachedBottom [
      set ycor mantleHeight - 1  ;; Mueve las bacterias al nivel actual del fondo
    ]
  ]

  ;; Actualiza los parches para reflejar visualmente el manto
  ask patches [
    if pycor <= mantleHeight [
      set pcolor brown
    ]
  ]
end

to updateVesilindMantle
  ;; Calcula el incremento del manto según el modelo Vesilind
  let currentRate sedimentV0 * exp(-1 * sedimentK * concentration) ;; Velocidad de sedimentación actual
  let mantleIncrement (heightMax / maxTime) * currentRate          ;; Incremento proporcional al tiempo
  set vesilindMantleHeight vesilindMantleHeight + mantleIncrement  ;; Actualiza la altura del manto Vesilind

  ;; Evita que el manto exceda la altura máxima
  if vesilindMantleHeight > heightMax [
    set vesilindMantleHeight heightMax
  ]

  ;; Graficar la curva en tiempo real
  set-current-plot "Acumulación de Lodo" ;; Selecciona el gráfico
  plotxy timeStep vesilindMantleHeight      ;; Dibuja un punto (timeStep, altura Vesilind)
end

to saveSedimentationData
  ;; Guarda (timeStep, vesilindMantleHeight) en la lista
  set sedimentationData lput (list timeStep vesilindMantleHeight) sedimentationData
end

to updateConcentrationGraph
  ;; Calcula la concentración en función del tiempo usando la fórmula de Vesilind
  let currentConcentration concentration * exp(-1 * sedimentK * timeStep)

  ;; Graficar la concentración en tiempo real
  set-current-plot "Concentración vs Tiempo"
  plotxy timeStep currentConcentration
end
to calculateAlturaTakacs



  ;; Velocidad efectiva considerando compresión

  if concentration > compressionCritical [

  ]

  ;; Calcular la Altura Takács
  set AlturaTakacs alturaRecalculadaH30 - (sedimentV0 * exp(-1 * sedimentK * concentration / compressionCritical ) * timeStep / 60)
  set AlturaCorre heightMax - (sedimentV0 * exp(-1 * sedimentK * concentration / compressionCritical ) * timeStep / 60)
  if AlturaTakacs < 0 [ set AlturaTakacs 0 ]  ;; Evitar valores negativos
end
to go
  if timeStep >= maxTime [
    stop
  ]

  if timeStep mod sampleInterval = 0 [
    updateSedimentLayer
    updateMantle
    updateVesilindMantle
    updateConcentrationGraph ;; Actualiza el gráfico de concentración
    saveSedimentationData ;; Guarda los datos en cada intervalo
    set alturaRecalculadaH30 heightMax - (sedimentV0 * exp(-1 * sedimentK * concentration) * timeStep / 60)
    takeSample


    ;; Calcular alturas actualizadas
    calculateIVLSimulated
    calculateAlturaTakacs]
  ask turtles [
    flocculate
    moveDown
  ]
  wait 0.3 ;; Pausa entre ticks para hacer la simulación visualmente más lenta
  tick
  set timeStep timeStep + 1
end

to flocculate
  if not reachedBottom [
    let nearbyTurtles turtles-on neighbors
    let closeNeighbors nearbyTurtles with [distance myself < 1]
    if any? closeNeighbors [
      let target one-of closeNeighbors
      if random-float 1 < adhesionProbability [
        ;; Fusiona tamaños si ambos están dentro del tamaño máximo
        if (flocSize + [flocSize] of target) <= maxFlocSize [
          set flocSize flocSize + [flocSize] of target
          ask target [ die ]
          set size sqrt(flocSize) * 0.5  ;; Cambia el tamaño visual
        ]
      ]
    ]
  ]
end

to moveDown
  if not reachedBottom [
    set heading 180  ;; Mueve las partículas hacia abajo
    ;; Calcula el tiempo restante como una proporción del máximo tiempo
    let timeRemaining maxTime - timeStep
    let timeFactor ( exp (timeRemaining /  maxTime))  ;; Factor de desaceleración

    ;; Calcula la velocidad ajustada en relación a la altura del manto y el tiempo restante
    let adjustedRate settlingRate * sqrt(flocSize) * timeFactor
    if adjustedRate < 0.0001 [ set adjustedRate 0.0001 ]  ;; Velocidad mínima
    fd adjustedRate

    ;; Restringe el movimiento al rango del lodo
    if ycor <= mantleHeight [
      set reachedBottom true
    ]
  ]

  ;; Fija el flóculo en el fondo
  if reachedBottom [
    set ycor mantleHeight - 1
  ]
end

to calcularIVL_real
  ;; Cálculo del volumen sedimentado en mL/L
  let volumenSedimentado (Sedimentacion30min * 2086)  ;; Convertir altura final en metros a mL/L

  ;; Usar la concentración (MLSS) calculada por Vesilind
  let mlss concentration

  ;; Validar que MLSS no sea cero para evitar divisiones por cero
  if mlss > 0 [
    set ivl_real volumenSedimentado / mlss
    show (word "El IVL calculado es: " ivl_real " mL/g")
  ]
end
to
  clear
  set sedimentV0 1.5
  set sedimentK 0.5
  set Sedimentacion30min 0.2  ;; Altura experimental inicial en metros
  set timeStep 0
  set alturaRecalculadaH30 heightMax - (sedimentV0 * exp(-1 * sedimentK * concentration) * maxTime / 60)
  reset-ticks
end


to takeSample
  show (word "Acumulación de lodo en " timeStep " minutos: " mantleHeight)
  show (word "Altura del manto Vesilind en " timeStep " minutos: " vesilindMantleHeight " m ")
  show (word "Velocidad de sedimentación: " sedimentRate " m/h")
end
@#$#@#$#@
GRAPHICS-WINDOW
365
78
475
489
-1
-1
2.0
1
10
1
1
1
0
0
0
1
-40
10
0
200
0
0
1
ticks
30.0

BUTTON
42
153
108
186
SETUP
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
126
154
198
187
INICIAR
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
38
298
288
331
VelocidadInicial
VelocidadInicial
0.001
12
0.716
0.001
1
NIL
HORIZONTAL

SLIDER
39
335
288
368
ConstanteVesilind
ConstanteVesilind
0.002
7
0.2113
0.0001
1
NIL
HORIZONTAL

SLIDER
39
413
289
446
maxTime
maxTime
1
30
30.0
0.001
1
NIL
HORIZONTAL

SLIDER
38
455
210
488
Sedimentacion30min
Sedimentacion30min
0.01
0.48
0.15
0.01
1
NIL
HORIZONTAL

BUTTON
41
197
119
230
IVL Real
calcularIVL_real
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
42
84
265
144
InputConcentracion
3.66
1
0
String

MONITOR
533
84
711
133
Velocidad de Sedimentación
sedimentRate
3
1
12

MONITOR
731
86
821
131
IVL Simulado
ivl_sim
2
1
11

PLOT
535
148
735
298
Concentración vs Tiempo
Tiempo (minutos)
Concentración (g/L)
0.0
30.0
0.0
5.0
true
false
"" ""
PENS
"Concentración" 1.0 0 -7500403 true "" ""

PLOT
536
317
736
467
Acumulación de Lodo
Tiempo (minutos)
Altura del Manto (m)
0.0
30.0
0.0
0.5
true
false
"" ""
PENS
"Altura del Manto" 1.0 0 -7500403 true "" ""

PLOT
753
149
913
466
Altura del Manto
Tiempo (minutos)
Altura (m)
0.0
30.0
0.0
0.48
true
false
"" ""
PENS
"Altura Simulada" 1.0 0 -16777216 true "" "plotxy timeStep alturaRecalculadaH30"

TEXTBOX
274
10
882
67
Simulador de Vesilind
38
0.0
1

TEXTBOX
45
374
195
400
Constante de Vesilind entre 0.29 m³/kg y 0.47 m³/kg.
10
0.0
1

TEXTBOX
953
129
1275
594
\nIVL \n\n1.\tFloculación Deficiente (Mal Desempeño):\no\tIVL > 150 mL/g.\no\tProblemas comunes:\n\tFlóculos livianos.\n\tMala sedimentación.\n\tSobrecarga hidráulica o biológica.\n\n2.\tOperación Óptima:\no\tIVL: 80 - 120 mL/g.\no\tIndica:\n\tFlóculos compactos.\n\tBuena sedimentación.\n\tRelación adecuada F/M (carga orgánica).\n\n3.\tLodo Muy Compacto (Sobremaduración):\no\tIVL < 30 mL/g.\no\tProblemas:\n\tFlóculos muy densos.\n\tPosibles problemas de flotación y deshidratación.\n
12
0.0
1

TEXTBOX
41
491
279
517
Se debe ajustar al valor de Altura de Vesilind
10
0.0
1

TEXTBOX
214
491
364
509
NIL
10
0.0
1

MONITOR
832
86
920
131
IVL Real
ivl_real
2
1
11

BUTTON
131
197
232
230
IVL Simulado
calculateIVLSimulated
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
39
507
211
540
compressionCritical
compressionCritical
1
8
6.93
0.01
1
NIL
HORIZONTAL

MONITOR
928
87
1005
132
AlturaCorre
AlturaCorre
3
1
11

MONITOR
1016
87
1088
132
Altura Real
Sedimentacion30min
3
1
11

MONITOR
1101
87
1234
132
Altura sin compresión
alturaRecalculadaH30
3
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
