# Implementation Plan

Last updated: 2026-07-08

## 1. Revision general

### 1.1 Objetivo

Revisar el estado actual del codigo antes de implementar nuevos sistemas, con foco en entender movimiento, jugadores, armas, enemigos, colisiones, mapas y dependencias.

### 1.2 Verificacion

Identificar comportamiento actual, responsabilidades por archivo y problemas evidentes sin refactorizar de entrada.

## 2. Refinamiento de ataques existentes

### 2.1 Objetivo

Mejorar la sensacion visual y jugable de espada, escudo y rifle antes de agregar nuevos tipos de ataques o armas.

### 2.2 Verificacion

Cada ataque deberia ser legible, responder bien al input y tener un efecto jugable claro.

## 3. Inputs

### 3.1 Estado actual

Teclado compartido.

### 3.2 Objetivo cercano

Soportar controles/gamepads para comodidad, sin desplazar el teclado compartido como input actual.

## Technical Direction

- Mantener cambios pequenos y verificables.
- Preferir claridad sobre arquitectura generica.
- Validar primero movimiento, ataques basicos, colisiones, enemigos simples, vida/dano e interaccion entre jugadores.
- Evitar networking y sistemas grandes hasta que el combate local basico funcione bien.
- No agregar mas armas hasta que las actuales tengan una calidad base aceptable.
