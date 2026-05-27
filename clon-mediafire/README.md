# Proyecto Final - Clon de Mediafire (Flutter + NestJS)

Este repositorio contiene tanto el frontend como el backend de la aplicación.

## Requisitos previos
- Docker y Docker Compose
- Flutter SDK (Windows/Android)

## Cómo iniciar el backend (Servidor y Base de Datos)
1. Abre una terminal y ve a la carpeta `backend`
2. Ejecuta el siguiente comando para levantar la base de datos PostgreSQL y el servidor NestJS:
   ```bash
   docker-compose up -d
   ```
3. El backend estará corriendo en `http://localhost:3000`.

## Cómo iniciar el frontend (Aplicación Flutter)
1. Abre **otra** terminal y ve a la carpeta `frontend`.
2. Descarga las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta la aplicación de Windows:
   ```bash
   flutter run -d windows
   ```
   *(También puedes correrlo en Android o Web cambiando el dispositivo).*

¡Listo! Ya puedes crear tu cuenta, iniciar sesión y empezar a subir o compartir archivos.
