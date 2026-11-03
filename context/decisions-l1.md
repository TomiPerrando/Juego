# Decisions (L1)

Last updated: 2026-07-11

- [2026-07-08] Usar LOVE2D como framework principal y Lua como lenguaje.
- [2026-07-08] Disenar el juego desde el inicio alrededor de dos jugadores cooperando, no como un modo agregado al final.
- [2026-07-08] Priorizar codigo simple, legible y entendible por encima de arquitectura sofisticada.
- [2026-07-08] Avanzar en pasos pequenos antes de crear sistemas RPG grandes.
- [2026-07-08] Mantener una convencion clara de comentarios con bloques `--------` para secciones principales y `----` para subsecciones.
- [2026-07-08] Acotar el alcance actual a cooperativo local en una PC, sin online por ahora.
- [2026-07-08] Usar camara compartida para ambos jugadores.
- [2026-07-08] Confirmar pixel art como estetica del proyecto.
- [2026-07-08] Usar arenas/salas de dungeon como formato principal: entrar, vencer enemigos y pasar a la siguiente sala.
- [2026-07-08] Dejar abierto el sistema de progresion: skill tree, roguelike, mejoras de armas, mezcla u otra opcion.
- [2026-07-08] Basar el moveset en el arma equipada; los jugadores no quedan limitados a un rol fijo.
- [2026-07-08] Priorizar teclado compartido ahora y sumar soporte de controles/gamepads pronto por comodidad.
- [2026-07-08] Hacer una revision general antes de la siguiente etapa de implementacion.
- [2026-07-08] Refinar espada, escudo y rifle antes de agregar nuevos tipos de ataques o armas.
- [2026-07-08] Confirmar `rifle` como nombre oficial del arma; `pistola` fue alias/confusion previa.
- [2026-07-10] Usar `Shield 4` del shield pack como sprite visual del escudo tanto para ataques como para bloqueos. Falta resolver una variante visual desde atras para cuando el personaje mira hacia arriba.
- [2026-07-10] Usar el beholder de `Tiny Enemies Vol1` como enemigo estacionario de prueba que dispara proyectiles en direccion fija para validar el bloqueo del escudo.
- [2026-07-10] El escudo solo refleja proyectiles aliados por ahora; cuando bloquea proyectiles enemigos, esos proyectiles se rompen.
- [2026-07-10] El escudo puede ejecutar un contraataque potente de barrido justo despues de bloquear un proyectil enemigo. Los parries quedan diferidos para mas adelante.
- [2026-07-11] El dash no debe ser necesariamente un boton generico igual para todas las armas. Puede formar parte del kit de cada arma, con peculiaridades adaptadas a su estilo; por ejemplo, el escudo puede modificar el dash hacia una accion defensiva/de control.

## Rationale

El proyecto combina desarrollo de juego, aprendizaje de Lua y aprendizaje de LOVE2D. Por eso, las decisiones favorecen ciclos cortos y codigo facil de leer sobre sistemas genericos o altamente configurables. La prioridad inmediata de combate es calidad de sensacion y claridad visual/jugable antes de amplitud de contenido.
