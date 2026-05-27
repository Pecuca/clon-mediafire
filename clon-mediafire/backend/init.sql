-- 1. Crear tabla de catálogo: register_type
-- Habilitar generación de UUIDs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Crear tabla de catálogo: register_type (opcional)
CREATE TABLE IF NOT EXISTS register_type (
    register_type_id SERIAL PRIMARY KEY,
    register_type_na VARCHAR(100) NOT NULL
);

-- Insert fixed register types for uploads and downloads
INSERT INTO register_type (register_type_id, register_type_na)
VALUES
    (1, 'subida')
    ,(2, 'descarga')
ON CONFLICT (register_type_id) DO NOTHING;

-- 2. Crear tabla: user (coincide con src/users/user.entity.ts)
CREATE TABLE IF NOT EXISTS "user" (
    user_id SERIAL PRIMARY KEY,
    user_na VARCHAR(150) NOT NULL,
    user_mail VARCHAR(255) UNIQUE NOT NULL,
    user_pass VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reset_token VARCHAR(20) NULL,
    reset_token_expires TIMESTAMP WITH TIME ZONE NULL
);

-- 3. Crear tabla: directory (Estructura de carpetas) (coincide con src/directory/directory.entity.ts)
CREATE TABLE IF NOT EXISTS directory (
    directory_id SERIAL PRIMARY KEY,
    directory_name VARCHAR(255) NOT NULL,
    directory_parent INT NULL,
    user_id INT NOT NULL,
    CONSTRAINT fk_directory_user FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_directory_parent FOREIGN KEY (directory_parent) REFERENCES directory(directory_id) ON DELETE CASCADE
);

-- 4. Crear tabla: archive (Archivos encriptados) (coincide con src/archive/archive.entity.ts)
CREATE TABLE IF NOT EXISTS archive (
    archive_id SERIAL PRIMARY KEY,
    archive_na VARCHAR(255) NOT NULL,
    symmetric_key TEXT NOT NULL,
    hash TEXT NOT NULL,
    private_key TEXT NOT NULL,
    public_key TEXT NOT NULL,
    file_path TEXT NOT NULL,
    user_id INT NULL,
    directory_id INT NULL,
    share_token uuid UNIQUE,
    CONSTRAINT fk_archive_directory FOREIGN KEY (directory_id) REFERENCES directory(directory_id) ON DELETE CASCADE
);

-- 5. Crear tabla de auditoría/logs: register (opcional)
CREATE TABLE IF NOT EXISTS register (
    register_id SERIAL PRIMARY KEY,
    register_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    register_type_na VARCHAR(150),
    register_type_id INT NOT NULL,
    user_id INT NULL,
    archive_id INT NULL,
    archive_na VARCHAR(255) NULL,
    ip_address VARCHAR(45) NULL,
    success BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_register_type FOREIGN KEY (register_type_id) REFERENCES register_type(register_type_id),
    CONSTRAINT fk_register_user FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_register_archive FOREIGN KEY (archive_id) REFERENCES archive(archive_id) ON DELETE SET NULL
);