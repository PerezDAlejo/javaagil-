-- =========================================
-- Schema de refactorización para biblioteca_proyecto_yava
-- Versión mejorada con mejores prácticas de seguridad y normalización
-- =========================================

-- Configuración de base de datos
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================
-- TABLA: usuarios
-- Gestión de usuarios del sistema con seguridad mejorada
-- =========================================
CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo del usuario',
    correo VARCHAR(150) NOT NULL COMMENT 'Email único del usuario',
    clave VARCHAR(255) NULL COMMENT 'Contraseña en texto plano (DEPRECATED - usar password_hash)',
    password_hash VARCHAR(255) NULL COMMENT 'Hash seguro de la contraseña (SHA256/bcrypt)',
    rol ENUM('admin', 'usuario') NOT NULL DEFAULT 'usuario' COMMENT 'Rol del usuario en el sistema',
    activo BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado activo del usuario',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    -- Índices y restricciones
    CONSTRAINT uk_correo UNIQUE (correo),
    INDEX idx_usuarios_rol (rol),
    INDEX idx_usuarios_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Usuarios del sistema de biblioteca';

-- =========================================
-- TABLA: libros
-- Catálogo de libros con gestión de stock
-- =========================================
CREATE TABLE libros (
    id_libro INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL COMMENT 'Título del libro',
    autor VARCHAR(150) NOT NULL COMMENT 'Autor del libro',
    editorial VARCHAR(100) NOT NULL COMMENT 'Editorial',
    paginas INT NOT NULL COMMENT 'Número de páginas',
    isbn VARCHAR(20) NOT NULL COMMENT 'ISBN único del libro',
    categoria VARCHAR(50) NOT NULL COMMENT 'Categoría/género del libro',
    fecha_publicacion DATE NULL COMMENT 'Fecha de publicación',
    precio DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Precio del libro',
    stock_total INT NOT NULL DEFAULT 1 COMMENT 'Stock total disponible',
    stock_disponible INT NOT NULL DEFAULT 1 COMMENT 'Stock actualmente disponible',
    activo BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Libro activo en el catálogo',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    -- Restricciones de integridad
    CONSTRAINT uk_isbn UNIQUE (isbn),
    CONSTRAINT chk_disponibles CHECK (stock_disponible >= 0 AND stock_disponible <= stock_total),
    CONSTRAINT chk_stock_positivo CHECK (stock_total >= 0),
    CONSTRAINT chk_precio_positivo CHECK (precio >= 0),
    
    -- Índices para consultas frecuentes
    INDEX idx_libros_autor (autor),
    INDEX idx_libros_categoria (categoria),
    INDEX idx_libros_activo (activo),
    INDEX idx_libros_disponible (stock_disponible)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Catálogo de libros de la biblioteca';

-- =========================================
-- TABLA: prestamos
-- Gestión de préstamos con estados y fechas mejoradas
-- =========================================
CREATE TABLE prestamos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL COMMENT 'Usuario que solicita el préstamo',
    id_libro INT NOT NULL COMMENT 'Libro prestado',
    fecha_prestamo TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de inicio del préstamo',
    fecha_devolucion_esperada DATE NOT NULL COMMENT 'Fecha esperada de devolución',
    fecha_devolucion_real TIMESTAMP NULL COMMENT 'Fecha real de devolución',
    estado ENUM('PENDIENTE', 'APROBADO', 'DEVUELTO', 'VENCIDO', 'CANCELADO') NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado actual del préstamo',
    observaciones TEXT NULL COMMENT 'Observaciones adicionales',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    -- Claves foráneas
    CONSTRAINT fk_prestamo_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_prestamo_libro FOREIGN KEY (id_libro) REFERENCES libros(id_libro) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Restricciones de negocio
    CONSTRAINT chk_fechas_prestamo CHECK (fecha_devolucion_esperada >= DATE(fecha_prestamo)),
    
    -- Índices para consultas frecuentes
    INDEX idx_prestamos_usuario_estado (id_usuario, estado),
    INDEX idx_prestamos_libro_estado (id_libro, estado),
    INDEX idx_prestamos_fecha (fecha_prestamo),
    INDEX idx_prestamos_vencimiento (fecha_devolucion_esperada, estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Gestión de préstamos de libros';

-- =========================================
-- TABLA: tokens_recuperacion
-- Tokens para recuperación de contraseñas
-- =========================================
CREATE TABLE tokens_recuperacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL COMMENT 'Usuario propietario del token',
    token VARCHAR(255) NOT NULL COMMENT 'Token único de recuperación',
    fecha_expiracion TIMESTAMP NOT NULL COMMENT 'Fecha de expiración del token',
    usado BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Indica si el token ya fue utilizado',
    ip_solicitud VARCHAR(45) NULL COMMENT 'IP desde donde se solicitó',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    
    -- Claves foráneas
    CONSTRAINT fk_token_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE CASCADE ON UPDATE CASCADE,
    
    -- Restricciones
    CONSTRAINT uk_token UNIQUE (token),
    
    -- Índices
    INDEX idx_token_usuario (id_usuario),
    INDEX idx_token_expiracion (fecha_expiracion),
    INDEX idx_token_usado (usado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Tokens para recuperación de contraseñas';

-- =========================================
-- TRIGGERS PARA GESTIÓN AUTOMÁTICA DE STOCK
-- =========================================

-- Trigger para actualizar stock al aprobar préstamo
DELIMITER $$
CREATE TRIGGER tr_prestamo_aprobar
    AFTER UPDATE ON prestamos
    FOR EACH ROW
BEGIN
    -- Si el estado cambió a APROBADO, reducir stock disponible
    IF OLD.estado != 'APROBADO' AND NEW.estado = 'APROBADO' THEN
        UPDATE libros 
        SET stock_disponible = stock_disponible - 1 
        WHERE id_libro = NEW.id_libro AND stock_disponible > 0;
    END IF;
    
    -- Si el estado cambió a DEVUELTO, aumentar stock disponible
    IF OLD.estado != 'DEVUELTO' AND NEW.estado = 'DEVUELTO' THEN
        UPDATE libros 
        SET stock_disponible = stock_disponible + 1 
        WHERE id_libro = NEW.id_libro;
    END IF;
END$$

-- Trigger para limpiar tokens expirados automáticamente
CREATE TRIGGER tr_token_limpieza
    BEFORE INSERT ON tokens_recuperacion
    FOR EACH ROW
BEGIN
    -- Eliminar tokens expirados del usuario antes de insertar uno nuevo
    DELETE FROM tokens_recuperacion 
    WHERE id_usuario = NEW.id_usuario 
    AND (fecha_expiracion < NOW() OR usado = TRUE);
END$$

DELIMITER ;

-- =========================================
-- VISTAS ÚTILES PARA CONSULTAS FRECUENTES
-- =========================================

-- Vista de libros disponibles
CREATE VIEW v_libros_disponibles AS
SELECT 
    l.id_libro,
    l.nombre,
    l.autor,
    l.editorial,
    l.categoria,
    l.stock_total,
    l.stock_disponible,
    CASE 
        WHEN l.stock_disponible > 0 THEN 'DISPONIBLE'
        ELSE 'AGOTADO'
    END as disponibilidad
FROM libros l
WHERE l.activo = TRUE;

-- Vista de préstamos activos
CREATE VIEW v_prestamos_activos AS
SELECT 
    p.id,
    u.nombre as usuario,
    u.correo,
    l.nombre as libro,
    l.autor,
    p.fecha_prestamo,
    p.fecha_devolucion_esperada,
    p.estado,
    CASE 
        WHEN p.fecha_devolucion_esperada < CURDATE() AND p.estado IN ('APROBADO', 'PENDIENTE') THEN 'VENCIDO'
        ELSE p.estado
    END as estado_actual
FROM prestamos p
JOIN usuarios u ON p.id_usuario = u.id
JOIN libros l ON p.id_libro = l.id_libro
WHERE p.estado IN ('PENDIENTE', 'APROBADO');

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================
-- COMENTARIOS FINALES
-- =========================================
/*
ESTRATEGIA DE ÍNDICES:
- uk_correo, uk_isbn, uk_token: Índices únicos para integridad
- idx_*_autor, idx_*_categoria: Índices para búsquedas frecuentes
- idx_prestamos_usuario_estado, idx_prestamos_libro_estado: Índices compuestos para consultas de préstamos
- idx_*_fecha: Índices para consultas temporales

RESTRICCIONES IMPORTANTES:
- fk_prestamo_usuario, fk_prestamo_libro: Integridad referencial
- chk_disponibles: Garantiza que stock disponible no exceda el total
- chk_fechas_prestamo: Fecha de devolución no puede ser anterior al préstamo

CONSIDERACIONES DE SEGURIDAD:
- password_hash reemplaza clave en texto plano
- tokens_recuperacion con expiración automática
- Logs de IP para auditoría de recuperación de contraseñas

FUTURAS MEJORAS OPCIONALES:
- Tabla de reservas para libros agotados
- Sistema de multas por retraso
- Auditoría completa de cambios
- Índices FULLTEXT para búsqueda de texto
*/