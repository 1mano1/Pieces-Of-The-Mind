# Instrucciones — Pieces of the Mind v6

## ✅ El problema estaba en escena_demencia.gd
El script de la demencia se ejecutaba al mismo tiempo que la cinemática de intro
y activaba el DemenciaRect desde el principio. Ya está corregido — ahora
solo actúa cuando el trigger del comedor lo llama explícitamente.

---

## Qué tienes que hacer en el editor (solo una vez)

### Ya hecho por ti:
- ✅ CinematicaIntro conectado
- ✅ BarraTarea instanciada
- ✅ Area3D (trigger hija) con CollisionShape3D

### Lo que falta:

#### 1. Al nodo Area3D (trigger hija):
- Selecciónalo en el árbol
- Inspector → Script → asigna `Scripts/trigger_hija.gd`
- Inspector → `Barra Tareas Path` → arrastra el nodo `BarraTarea`

#### 2. Nodo EscenaDemencia:
- Agrega nodo hijo `Node` a la raíz, renómbralo `EscenaDemencia`
- Asígnale `Scripts/escena_demencia.gd`
- Inspector → `Jugador Path` → arrastra `Jugador`
- Inspector → `Personaje Terror Path` → déjalo vacío por ahora

#### 3. Trigger del comedor:
- Agrega `Area3D` con `CollisionShape3D` en la entrada del comedor
- Asígnale `Scripts/trigger_comedor.gd`
- Inspector → `Escena Demencia Path` → arrastra `EscenaDemencia`

#### 4. Audio (si no lo has hecho):
- Abre `jugador.tscn` → nodo `AudioRespiracion`
- Inspector → Stream → arrastra `Audio/agitación.mp3`

---

## Posición de inicio (cama)
En `Scripts/cinematica_intro.gd` línea ~14:
```
const POS_CAMA = Vector3(5.44, 0.91, 0.58)
```
Estos son tus valores actuales del Inspector. Si mueves la cama, actualiza aquí.

---

## Secuencia completa garantizada:
1. Jugador aparece en la cama
2. Audio de respiración
3. Parpadeos progresivos (ojos abriéndose)
4. Blur se quita
5. Diálogo 1
6. Mirar lados + levantarse
7. Diálogo 2
8. WASD aparece → presiona tecla → desaparece
9. Barra de tareas se desliza desde la derecha
10. Jugador camina libremente
11. [Al entrar al cuarto de la hija] → tarea se completa, barra sale
12. [Al entrar al comedor] → escena de demencia completa
