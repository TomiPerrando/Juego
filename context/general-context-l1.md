# General Context (L1)

Last updated: 2026-07-08

## Project Intent

El proyecto es un top-down action RPG cooperativo local para dos jugadores hecho en Lua con LOVE2D. El alcance actual esta acotado a una sola PC. La idea principal es evitar un RPG generico con cooperativo agregado y, en cambio, disenar desde el inicio alrededor de la interaccion entre ambos jugadores.

La experiencia buscada es que los jugadores sobrevivan, peleen, exploren y progresen usando herramientas que se combinen entre si. El foco no es solo pegar o esquivar, sino ver lo que hizo el otro jugador, reaccionar y crear una accion mas fuerte o mas interesante entre ambos. La camara es compartida y la estetica confirmada es pixel art.

## Gameplay Direction

El nucleo del gameplay apunta a combate cooperativo con sinergias. Las habilidades individuales deberian ser simples de entender, pero ganar profundidad cuando se cruzan con las acciones del otro jugador.

El formato principal confirmado es de arenas/salas de dungeon: entrar a una sala, vencer enemigos y pasar a la siguiente. El sistema de progresion sigue abierto y puede tomar forma de skill tree, roguelike, mejoras de armas, mezcla de sistemas u otra opcion.

Por ahora el diseno de personajes es basado en armas: el moveset cambia segun el arma equipada, sin limitar al jugador a un rol fijo. La primera iteracion ya cuenta con espada, escudo y rifle como ataques basicos a refinar.

Las ideas de armas, sinergias y combos se registran separadas en `context/combat-ideas-l1.md`, distinguiendo ideas generales/de un arma de interacciones entre armas y ataques combinados.

## Cooperative Interaction Types

Dos familias de cooperacion estan en discusion:

- Sinergias naturales: interacciones dinamicas que ocurren cuando acciones compatibles se cruzan durante el combate, sin ritual estricto.
- Combos coordinados: tecnicas dobles mas intencionales, posiblemente activadas con boton o combinacion especifica y cierta coordinacion temporal.

## Development Philosophy

El proyecto tambien es de aprendizaje. Como el equipo no parte de experiencia fuerte en game development ni Lua, la prioridad tecnica es claridad.

Regla general:
- Primero que funcione.
- Despues que se entienda.
- Recien despues que se refine.

Evitar:
- Sistemas grandes antes de tener combate basico divertido.
- Abstracciones prematuras.
- Mezclar innecesariamente logica visual y logica de gameplay.
- Agregar complejidad por si acaso.
- Agregar mas armas antes de que espada, escudo y rifle se sientan bien visual y jugablemente.

## Comment Convention

Convencion deseada para navegabilidad:

```lua
--------
-- Secciones principales
--------

----
-- Subsecciones
----
```
