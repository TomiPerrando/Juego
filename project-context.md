# Project Context (L0)

Last updated: 2026-07-08

L1 files by section:
- General Context: `context/general-context-l1.md`
- Latest Decisions: `context/decisions-l1.md`
- Current Scope: `context/current-scope-l1.md`
- Current Plan: `context/current-plan-l1.md`
- Product Plan (L1): `context/product-plan.md`
- Implementation Plan (L2 technical, mandatory): `context/implementation-plan.md`
- Current Status: `context/current-status-l1.md`
- Open Questions: `context/open-questions-l1.md`
- Combat Ideas: `context/combat-ideas-l1.md`

## General Context

Juego 2D top-down action RPG cooperativo local para dos jugadores en una misma PC, desarrollado en Lua con LOVE2D. El objetivo final es que la cooperacion no sea una opcion agregada, sino el centro del diseno: combate, exploracion, roles, habilidades y coordinacion deben estar pensados para que jugar de a dos sea mecanicamente interesante. El proyecto tambien es de aprendizaje, por lo que el codigo debe priorizar claridad, pasos pequenos y comportamiento entendible antes que arquitectura sofisticada. La estetica confirmada es pixel art y el formato jugable apunta a arenas/salas de dungeon con camara compartida.

## Latest Decisions (max 5)

- [2026-07-08] Acotar el alcance actual a cooperativo local en una PC, sin online por ahora.
- [2026-07-08] Usar camara compartida para ambos jugadores.
- [2026-07-08] Usar arenas/salas de dungeon como formato principal: entrar, vencer enemigos y pasar a la siguiente sala.
- [2026-07-08] Basar el moveset en el arma equipada; los jugadores no quedan limitados a un rol fijo.
- [2026-07-08] Confirmar `rifle` como nombre oficial del arma; `pistola` fue alias/confusion previa.

## Current Scope

- Working on now: registrar contexto inicial y preparar una revision general del estado actual del codigo.
- In scope now: cooperativo local, camara compartida, pixel art, arenas/salas de dungeon, armas actuales y refinamiento de ataques basicos.
- Out of scope now: networking, nuevas armas antes de refinar las existentes, sistemas RPG grandes, inventario complejo, mundo enorme, quests extensas y arquitectura avanzada.

## Current Plan

- Plan exists: confirmed high-level plan.
- 1. V1 cooperativo local
  - 1.1 Dos jugadores en la misma PC con controles separados.
  - 1.2 Camara compartida.
- 2. Refinamiento de combate base
  - 2.1 Revision general del codigo y comportamiento actual.
  - 2.2 Refinar espada, escudo y rifle antes de agregar mas armas.
- 3. Loop de salas
  - 3.1 Entrar a una sala, vencer enemigos y pasar a la siguiente.
  - 3.2 Progresion RPG/roguelike todavia no definida.
- A futuro (max 3): soporte de control/gamepad; progresion ligera; combos cooperativos.
- Product plan source: `context/product-plan.md` (`x.x` required, `x.x.x` optional for complex tasks).
- Implementation plan source: `context/implementation-plan.md` (mandatory technical detail for `x.x` and `x.x.x`).

## Current Status

- Last implemented: V1 con dos entidades de jugador controladas con distintas teclas y ataques basicos suficientes para primera iteracion: espada, escudo y rifle.
- In progress: registrar contexto del proyecto.
- Next: revision general; despues refinar la sensacion visual y jugable de los ataques existentes.

## Open Questions (confirmed only)

- Sistema de progresion: puede ser skill tree, roguelike, mejoras de armas, una mezcla u otra opcion.
