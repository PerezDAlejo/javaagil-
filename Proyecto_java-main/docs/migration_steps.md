# Guía de Migración de Base de Datos - Sistema Biblioteca

## Resumen

Esta guía detalla el proceso paso a paso para migrar la base de datos `biblioteca_proyecto_yava` desde el esquema actual hacia la versión mejorada con mejores prácticas de seguridad, integridad referencial y gestión de stock.

**⚠️ IMPORTANTE**: Esta migración modifica la estructura existente. Realizar backup completo antes de proceder.

## Esquema Actual vs. Propuesto

### Esquema Actual
- **usuarios**: `id, nombre, correo, clave, rol`
- **libros**: `id_libro, nombre, autor, editorial, paginas, isbn, categoria, fecha_publicacion, precio`
- **prestamos**: `id, id_usuario, id_libro, fecha_prestamo, fecha_devolucion NOT NULL`

### Mejoras Implementadas
- Contraseñas hasheadas (seguridad)
- Gestión de stock de libros
- Estados de préstamos (PENDIENTE, APROBADO, DEVUELTO, etc.)
- Sistema de tokens de recuperación
- Timestamps automáticos
- Restricciones de integridad
- Índices optimizados

---

## Pre-requisitos

### 1. Verificaciones Iniciales

```sql
-- Verificar versión de MySQL (requiere 8.0+)
SELECT VERSION();

-- Verificar espacio en disco disponible
SELECT 
    table_schema as 'Base de Datos',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) as 'Tamaño MB'
FROM information_schema.tables 
WHERE table_schema = 'biblioteca_proyecto_yava'
GROUP BY table_schema;

-- Contar registros existentes
SELECT 'usuarios' as tabla, COUNT(*) as registros FROM usuarios
UNION ALL
SELECT 'libros', COUNT(*) FROM libros  
UNION ALL
SELECT 'prestamos', COUNT(*) FROM prestamos;
```

### 2. Backup Completo

```bash
# Backup de la base de datos completa
mysqldump -u root -p biblioteca_proyecto_yava > backup_biblioteca_$(date +%Y%m%d_%H%M%S).sql

# Verificar que el backup se creó correctamente
ls -lh backup_biblioteca_*.sql
```

### 3. Verificar Duplicados en ISBN

```sql
-- Identificar ISBNs duplicados (deben resolverse antes de la migración)
SELECT isbn, COUNT(*) as duplicados 
FROM libros 
GROUP BY isbn 
HAVING COUNT(*) > 1;

-- Si existen duplicados, ejecutar:
-- UPDATE libros SET isbn = CONCAT(isbn, '-', id_libro) WHERE isbn IN (SELECT isbn FROM (SELECT isbn FROM libros GROUP BY isbn HAVING COUNT(*) > 1) as dups);
```

---

## Proceso de Migración

### Paso 1: Preparar la Migración

```sql
-- Conectar a la base de datos
USE biblioteca_proyecto_yava;

-- Configurar para la migración
SET FOREIGN_KEY_CHECKS = 0;
SET NAMES utf8mb4;

-- Iniciar transacción para rollback en caso de error
START TRANSACTION;
```

### Paso 2: Migrar Tabla USUARIOS

```sql
-- 2.1 Añadir nuevas columnas
ALTER TABLE usuarios 
ADD COLUMN password_hash VARCHAR(255) NULL COMMENT 'Hash seguro de la contraseña' AFTER clave,
ADD COLUMN activo BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado activo del usuario' AFTER rol,
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización';

-- 2.2 Modificar columnas existentes
ALTER TABLE usuarios 
MODIFY COLUMN nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo del usuario',
MODIFY COLUMN correo VARCHAR(150) NOT NULL COMMENT 'Email único del usuario',
MODIFY COLUMN clave VARCHAR(255) NULL COMMENT 'Contraseña en texto plano (DEPRECATED)',
MODIFY COLUMN rol ENUM('admin', 'usuario') NOT NULL DEFAULT 'usuario' COMMENT 'Rol del usuario';

-- 2.3 Añadir restricciones e índices
ALTER TABLE usuarios 
ADD CONSTRAINT uk_correo UNIQUE (correo),
ADD INDEX idx_usuarios_rol (rol),
ADD INDEX idx_usuarios_activo (activo);

-- 2.4 Actualizar motor y charset
ALTER TABLE usuarios 
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Usuarios del sistema de biblioteca';
```

### Paso 3: Migrar Tabla LIBROS

```sql
-- 3.1 Añadir nuevas columnas para gestión de stock
ALTER TABLE libros 
ADD COLUMN stock_total INT NOT NULL DEFAULT 1 COMMENT 'Stock total disponible' AFTER precio,
ADD COLUMN stock_disponible INT NOT NULL DEFAULT 1 COMMENT 'Stock actualmente disponible' AFTER stock_total,
ADD COLUMN activo BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Libro activo en el catálogo',
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización';

-- 3.2 Modificar columnas existentes
ALTER TABLE libros 
MODIFY COLUMN nombre VARCHAR(200) NOT NULL COMMENT 'Título del libro',
MODIFY COLUMN autor VARCHAR(150) NOT NULL COMMENT 'Autor del libro',
MODIFY COLUMN editorial VARCHAR(100) NOT NULL COMMENT 'Editorial',
MODIFY COLUMN paginas INT NOT NULL COMMENT 'Número de páginas',
MODIFY COLUMN isbn VARCHAR(20) NOT NULL COMMENT 'ISBN único del libro',
MODIFY COLUMN categoria VARCHAR(50) NOT NULL COMMENT 'Categoría/género del libro',
MODIFY COLUMN fecha_publicacion DATE NULL COMMENT 'Fecha de publicación',
MODIFY COLUMN precio DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Precio del libro';

-- 3.3 Añadir restricciones e índices (después de limpiar duplicados)
ALTER TABLE libros 
ADD CONSTRAINT uk_isbn UNIQUE (isbn),
ADD CONSTRAINT chk_disponibles CHECK (stock_disponible >= 0 AND stock_disponible <= stock_total),
ADD CONSTRAINT chk_stock_positivo CHECK (stock_total >= 0),
ADD CONSTRAINT chk_precio_positivo CHECK (precio >= 0);

ALTER TABLE libros 
ADD INDEX idx_libros_autor (autor),
ADD INDEX idx_libros_categoria (categoria),
ADD INDEX idx_libros_activo (activo),
ADD INDEX idx_libros_disponible (stock_disponible);

-- 3.4 Actualizar motor y charset
ALTER TABLE libros 
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Catálogo de libros de la biblioteca';
```

### Paso 4: Migrar Tabla PRESTAMOS

```sql
-- 4.1 Añadir nuevas columnas
ALTER TABLE prestamos 
ADD COLUMN fecha_devolucion_esperada DATE NOT NULL DEFAULT (DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY)) COMMENT 'Fecha esperada de devolución' AFTER fecha_prestamo,
ADD COLUMN fecha_devolucion_real TIMESTAMP NULL COMMENT 'Fecha real de devolución' AFTER fecha_devolucion_esperada,
ADD COLUMN estado ENUM('PENDIENTE', 'APROBADO', 'DEVUELTO', 'VENCIDO', 'CANCELADO') NOT NULL DEFAULT 'DEVUELTO' COMMENT 'Estado actual del préstamo' AFTER fecha_devolucion_real,
ADD COLUMN observaciones TEXT NULL COMMENT 'Observaciones adicionales',
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización';

-- 4.2 Migrar datos existentes
-- Actualizar fecha_devolucion_real basada en la columna existente fecha_devolucion
UPDATE prestamos SET 
    fecha_devolucion_real = fecha_devolucion,
    fecha_devolucion_esperada = DATE_ADD(DATE(fecha_prestamo), INTERVAL 14 DAY),
    estado = 'DEVUELTO'
WHERE fecha_devolucion IS NOT NULL;

-- 4.3 Modificar columnas existentes
ALTER TABLE prestamos 
MODIFY COLUMN fecha_prestamo TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de inicio del préstamo';

-- 4.4 Eliminar columna antigua (CUIDADO: esto elimina datos)
-- ALTER TABLE prestamos DROP COLUMN fecha_devolucion;

-- 4.5 Añadir restricciones de integridad
ALTER TABLE prestamos 
ADD CONSTRAINT fk_prestamo_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE RESTRICT ON UPDATE CASCADE,
ADD CONSTRAINT fk_prestamo_libro FOREIGN KEY (id_libro) REFERENCES libros(id_libro) ON DELETE RESTRICT ON UPDATE CASCADE,
ADD CONSTRAINT chk_fechas_prestamo CHECK (fecha_devolucion_esperada >= DATE(fecha_prestamo));

-- 4.6 Añadir índices
ALTER TABLE prestamos 
ADD INDEX idx_prestamos_usuario_estado (id_usuario, estado),
ADD INDEX idx_prestamos_libro_estado (id_libro, estado),
ADD INDEX idx_prestamos_fecha (fecha_prestamo),
ADD INDEX idx_prestamos_vencimiento (fecha_devolucion_esperada, estado);

-- 4.7 Actualizar motor y charset
ALTER TABLE prestamos 
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Gestión de préstamos de libros';
```

### Paso 5: Crear Tabla TOKENS_RECUPERACION

```sql
CREATE TABLE tokens_recuperacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL COMMENT 'Usuario propietario del token',
    token VARCHAR(255) NOT NULL COMMENT 'Token único de recuperación',
    fecha_expiracion TIMESTAMP NOT NULL COMMENT 'Fecha de expiración del token',
    usado BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Indica si el token ya fue utilizado',
    ip_solicitud VARCHAR(45) NULL COMMENT 'IP desde donde se solicitó',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    
    CONSTRAINT fk_token_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uk_token UNIQUE (token),
    
    INDEX idx_token_usuario (id_usuario),
    INDEX idx_token_expiracion (fecha_expiracion),
    INDEX idx_token_usado (usado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Tokens para recuperación de contraseñas';
```

### Paso 6: Crear Triggers y Vistas

```sql
-- 6.1 Triggers para gestión automática de stock
DELIMITER $$
CREATE TRIGGER tr_prestamo_aprobar
    AFTER UPDATE ON prestamos
    FOR EACH ROW
BEGIN
    IF OLD.estado != 'APROBADO' AND NEW.estado = 'APROBADO' THEN
        UPDATE libros 
        SET stock_disponible = stock_disponible - 1 
        WHERE id_libro = NEW.id_libro AND stock_disponible > 0;
    END IF;
    
    IF OLD.estado != 'DEVUELTO' AND NEW.estado = 'DEVUELTO' THEN
        UPDATE libros 
        SET stock_disponible = stock_disponible + 1 
        WHERE id_libro = NEW.id_libro;
    END IF;
END$$

CREATE TRIGGER tr_token_limpieza
    BEFORE INSERT ON tokens_recuperacion
    FOR EACH ROW
BEGIN
    DELETE FROM tokens_recuperacion 
    WHERE id_usuario = NEW.id_usuario 
    AND (fecha_expiracion < NOW() OR usado = TRUE);
END$$
DELIMITER ;

-- 6.2 Vistas útiles
CREATE VIEW v_libros_disponibles AS
SELECT 
    l.id_libro, l.nombre, l.autor, l.editorial, l.categoria,
    l.stock_total, l.stock_disponible,
    CASE WHEN l.stock_disponible > 0 THEN 'DISPONIBLE' ELSE 'AGOTADO' END as disponibilidad
FROM libros l WHERE l.activo = TRUE;

CREATE VIEW v_prestamos_activos AS
SELECT 
    p.id, u.nombre as usuario, u.correo, l.nombre as libro, l.autor,
    p.fecha_prestamo, p.fecha_devolucion_esperada, p.estado,
    CASE WHEN p.fecha_devolucion_esperada < CURDATE() AND p.estado IN ('APROBADO', 'PENDIENTE') 
         THEN 'VENCIDO' ELSE p.estado END as estado_actual
FROM prestamos p
JOIN usuarios u ON p.id_usuario = u.id
JOIN libros l ON p.id_libro = l.id_libro
WHERE p.estado IN ('PENDIENTE', 'APROBADO');
```

### Paso 7: Ajustes de Datos Post-Migración

```sql
-- 7.1 Inicializar stock para libros existentes
UPDATE libros SET 
    stock_total = 1, 
    stock_disponible = CASE 
        WHEN id_libro IN (SELECT id_libro FROM prestamos WHERE estado = 'APROBADO') THEN 0 
        ELSE 1 
    END
WHERE stock_total IS NULL OR stock_disponible IS NULL;

-- 7.2 Normalizar roles de usuario
UPDATE usuarios SET rol = 'usuario' WHERE rol NOT IN ('admin', 'usuario');
UPDATE usuarios SET rol = 'admin' WHERE correo IN ('admin@biblioteca.com'); -- Ajustar según necesidad

-- 7.3 Generar hashes para contraseñas existentes (ejemplo con SHA256)
-- NOTA: En producción usar bcrypt o Argon2
UPDATE usuarios SET password_hash = SHA2(clave, 256) WHERE clave IS NOT NULL AND password_hash IS NULL;
```

---

## Verificación Post-Migración

### Consultas de Validación

```sql
-- Verificar estructura de tablas
DESCRIBE usuarios;
DESCRIBE libros;
DESCRIBE prestamos;
DESCRIBE tokens_recuperacion;

-- Verificar restricciones
SELECT 
    TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM information_schema.table_constraints 
WHERE table_schema = 'biblioteca_proyecto_yava';

-- Verificar datos migrados
SELECT 'Usuarios con hash' as descripcion, COUNT(*) as cantidad FROM usuarios WHERE password_hash IS NOT NULL
UNION ALL
SELECT 'Libros activos', COUNT(*) FROM libros WHERE activo = TRUE
UNION ALL
SELECT 'Préstamos migrados', COUNT(*) FROM prestamos WHERE estado IS NOT NULL;

-- Probar triggers
INSERT INTO prestamos (id_usuario, id_libro, fecha_devolucion_esperada, estado) 
VALUES (1, 1, DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'PENDIENTE');

UPDATE prestamos SET estado = 'APROBADO' WHERE id = LAST_INSERT_ID();
SELECT stock_disponible FROM libros WHERE id_libro = 1; -- Debe haber disminuido

UPDATE prestamos SET estado = 'DEVUELTO' WHERE id = LAST_INSERT_ID();
SELECT stock_disponible FROM libros WHERE id_libro = 1; -- Debe haber aumentado
```

### Pruebas Funcionales

```sql
-- Probar vistas
SELECT * FROM v_libros_disponibles LIMIT 5;
SELECT * FROM v_prestamos_activos LIMIT 5;

-- Probar restricciones
-- Esto debe fallar (violación de CHECK):
-- UPDATE libros SET stock_disponible = -1 WHERE id_libro = 1;

-- Esto debe fallar (violación de UNIQUE):
-- INSERT INTO usuarios (nombre, correo, rol) VALUES ('Test', (SELECT correo FROM usuarios LIMIT 1), 'usuario');
```

---

## Finalización y Rollback

### Confirmar Migración

```sql
-- Si todo está correcto, confirmar transacción
COMMIT;

-- Restaurar configuración
SET FOREIGN_KEY_CHECKS = 1;

-- Mensaje de éxito
SELECT 'Migración completada exitosamente' as resultado;
```

### Plan de Rollback (Si hay problemas)

```sql
-- En caso de error, hacer rollback
ROLLBACK;

-- Restaurar desde backup
-- mysql -u root -p biblioteca_proyecto_yava < backup_biblioteca_YYYYMMDD_HHMMSS.sql
```

---

## Tareas Futuras Recomendadas

### 1. Eliminación de Columna Clave (Después de validar aplicación)

```sql
-- SOLO después de actualizar la aplicación Java para usar password_hash
-- ALTER TABLE usuarios DROP COLUMN clave;
```

### 2. Mejoras Opcionales

```sql
-- Tabla de reservas para libros agotados
CREATE TABLE reservas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_libro INT NOT NULL,
    fecha_reserva TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('ACTIVA', 'NOTIFICADA', 'CANCELADA') DEFAULT 'ACTIVA',
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id),
    FOREIGN KEY (id_libro) REFERENCES libros(id_libro)
);

-- Índices FULLTEXT para búsqueda de libros
ALTER TABLE libros ADD FULLTEXT(nombre, autor, categoria);

-- Tabla de auditoría
CREATE TABLE auditoria (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tabla VARCHAR(50) NOT NULL,
    accion ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    id_registro INT NOT NULL,
    usuario VARCHAR(100),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    datos_anteriores JSON,
    datos_nuevos JSON
);
```

### 3. Optimizaciones de Rendimiento

```sql
-- Análisis de consultas lentas
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;

-- Estadísticas de tablas
ANALYZE TABLE usuarios, libros, prestamos, tokens_recuperacion;
```

---

## Notas Importantes

- **Backup**: Siempre tener backup antes de ejecutar
- **Transacciones**: Usar transacciones para operaciones críticas  
- **Validación**: Probar cada paso en entorno de desarrollo primero
- **Aplicación**: Actualizar código Java para usar nuevos campos
- **Monitoreo**: Vigilar rendimiento después de la migración
- **Documentación**: Mantener esta guía actualizada con cambios

---

**Tiempo estimado de migración**: 30-60 minutos dependiendo del volumen de datos.

**Contacto**: En caso de dudas durante la migración, consultar con el equipo de desarrollo antes de proceder.