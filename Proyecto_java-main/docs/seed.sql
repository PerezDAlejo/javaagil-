-- =========================================
-- Datos de prueba para biblioteca_proyecto_yava
-- Incluye usuarios, libros, préstamos y tokens de ejemplo
-- =========================================

-- Configuración inicial
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================================
-- DATOS DE USUARIOS
-- Incluye admin y usuarios de prueba
-- =========================================

-- Limpiar datos existentes (solo para desarrollo)
-- DELETE FROM tokens_recuperacion;
-- DELETE FROM prestamos;
-- DELETE FROM usuarios;
-- DELETE FROM libros;

-- Usuarios de ejemplo con contraseñas hasheadas
INSERT INTO usuarios (id, nombre, correo, clave, password_hash, rol, activo, created_at) VALUES
(1, 'Administrador Sistema', 'admin@biblioteca.com', 'admin123', 
 SHA2('admin123', 256), -- TODO: Reemplazar con bcrypt/argon2 en producción
 'admin', TRUE, NOW() - INTERVAL 30 DAY),

(2, 'Juan Carlos Pérez', 'juan.perez@estudiante.com', 'usuario123',
 SHA2('usuario123', 256), -- Hash SHA256 temporal
 'usuario', TRUE, NOW() - INTERVAL 15 DAY),

(3, 'María Elena González', 'maria.gonzalez@estudiante.com', 'usuario456',
 SHA2('usuario456', 256), -- Hash SHA256 temporal  
 'usuario', TRUE, NOW() - INTERVAL 10 DAY),

(4, 'Luis Fernando Castro', 'luis.castro@estudiante.com', 'mipassword',
 SHA2('mipassword', 256), -- Hash SHA256 temporal
 'usuario', FALSE, NOW() - INTERVAL 5 DAY); -- Usuario inactivo

-- =========================================
-- DATOS DE LIBROS
-- Catálogo diverso con diferentes categorías y stock
-- =========================================

INSERT INTO libros (id_libro, nombre, autor, editorial, paginas, isbn, categoria, fecha_publicacion, precio, stock_total, stock_disponible, activo, created_at) VALUES
(1, 'Cien Años de Soledad', 'Gabriel García Márquez', 'Editorial Sudamericana', 471, '978-84-376-0494-7', 'Literatura', '1967-06-05', 25000.00, 3, 2, TRUE, NOW() - INTERVAL 60 DAY),

(2, 'El Principito', 'Antoine de Saint-Exupéry', 'Planeta', 96, '978-84-08-04729-4', 'Infantil', '1943-04-06', 18000.00, 5, 5, TRUE, NOW() - INTERVAL 45 DAY),

(3, 'Don Quijote de la Mancha', 'Miguel de Cervantes', 'Cátedra', 1200, '978-84-376-2188-3', 'Literatura Clásica', '1605-01-16', 35000.00, 2, 1, TRUE, NOW() - INTERVAL 90 DAY),

(4, 'Introducción a la Programación en Java', 'Deitel & Deitel', 'Pearson Education', 1152, '978-607-32-4186-9', 'Tecnología', '2017-01-15', 89000.00, 4, 3, TRUE, NOW() - INTERVAL 30 DAY),

(5, 'Base de Datos: Fundamentos y Diseño', 'Ramez Elmasri', 'Addison Wesley', 1024, '978-84-7829-085-6', 'Tecnología', '2016-03-20', 95000.00, 2, 0, TRUE, NOW() - INTERVAL 20 DAY),

(6, 'Historia Universal Contemporánea', 'Carlos Martínez Shaw', 'Ariel Historia', 680, '978-84-344-1392-1', 'Historia', '2018-09-10', 42000.00, 1, 1, FALSE, NOW() - INTERVAL 10 DAY); -- Libro inactivo

-- =========================================
-- DATOS DE PRÉSTAMOS
-- Ejemplos de diferentes estados de préstamos
-- =========================================

INSERT INTO prestamos (id, id_usuario, id_libro, fecha_prestamo, fecha_devolucion_esperada, fecha_devolucion_real, estado, observaciones, created_at) VALUES
-- Préstamo devuelto exitosamente
(1, 2, 1, NOW() - INTERVAL 20 DAY, DATE(NOW() - INTERVAL 6 DAY), NOW() - INTERVAL 5 DAY, 'DEVUELTO', 
 'Libro devuelto en buen estado', NOW() - INTERVAL 20 DAY),

-- Préstamo actualmente aprobado (libro prestado)
(2, 3, 4, NOW() - INTERVAL 10 DAY, DATE(NOW() + INTERVAL 4 DAY), NULL, 'APROBADO', 
 'Estudiante de sistemas, préstamo académico', NOW() - INTERVAL 10 DAY),

-- Préstamo pendiente de aprobación
(3, 2, 2, NOW() - INTERVAL 2 DAY, DATE(NOW() + INTERVAL 12 DAY), NULL, 'PENDIENTE', 
 'Solicitud pendiente de validación', NOW() - INTERVAL 2 DAY),

-- Préstamo vencido (no devuelto a tiempo)
(4, 3, 5, NOW() - INTERVAL 25 DAY, DATE(NOW() - INTERVAL 11 DAY), NULL, 'APROBADO', 
 'ALERTA: Préstamo vencido, contactar usuario', NOW() - INTERVAL 25 DAY),

-- Préstamo cancelado
(5, 4, 3, NOW() - INTERVAL 7 DAY, DATE(NOW() + INTERVAL 7 DAY), NULL, 'CANCELADO', 
 'Usuario canceló solicitud', NOW() - INTERVAL 7 DAY);

-- =========================================
-- DATOS DE TOKENS DE RECUPERACIÓN
-- Ejemplos para testing del sistema de recuperación
-- =========================================

INSERT INTO tokens_recuperacion (id, id_usuario, token, fecha_expiracion, usado, ip_solicitud, created_at) VALUES
-- Token válido y no usado (para testing)
(1, 2, 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0', 
 NOW() + INTERVAL 2 HOUR, FALSE, '192.168.1.100', NOW() - INTERVAL 30 MINUTE),

-- Token expirado
(2, 3, 'z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4j3i2h1g0', 
 NOW() - INTERVAL 1 HOUR, FALSE, '192.168.1.101', NOW() - INTERVAL 3 HOUR),

-- Token usado (ya no válido)
(3, 2, 'expired1234567890abcdef1234567890abcdef12345', 
 NOW() + INTERVAL 1 HOUR, TRUE, '192.168.1.102', NOW() - INTERVAL 1 DAY);

-- =========================================
-- VERIFICACIONES DE INTEGRIDAD
-- =========================================

-- Verificar que los datos se insertaron correctamente
SELECT 'Verificación de datos insertados:' as mensaje;

SELECT 'usuarios' as tabla, COUNT(*) as registros FROM usuarios
UNION ALL
SELECT 'libros', COUNT(*) FROM libros
UNION ALL  
SELECT 'prestamos', COUNT(*) FROM prestamos
UNION ALL
SELECT 'tokens_recuperacion', COUNT(*) FROM tokens_recuperacion;

-- Verificar stock disponible vs préstamos activos
SELECT 
    l.nombre as libro,
    l.stock_total,
    l.stock_disponible,
    COUNT(p.id) as prestamos_activos
FROM libros l
LEFT JOIN prestamos p ON l.id_libro = p.id_libro AND p.estado = 'APROBADO'
GROUP BY l.id_libro, l.nombre, l.stock_total, l.stock_disponible;

-- Verificar relaciones de préstamos
SELECT 
    p.id as prestamo_id,
    u.nombre as usuario,
    l.nombre as libro,
    p.estado,
    p.fecha_prestamo,
    p.fecha_devolucion_esperada,
    CASE 
        WHEN p.estado = 'APROBADO' AND p.fecha_devolucion_esperada < CURDATE() THEN 'VENCIDO'
        ELSE p.estado
    END as estado_real
FROM prestamos p
JOIN usuarios u ON p.id_usuario = u.id
JOIN libros l ON p.id_libro = l.id_libro;

-- Verificar tokens activos
SELECT 
    t.id,
    u.nombre as usuario,
    t.fecha_expiracion,
    t.usado,
    CASE 
        WHEN t.usado = TRUE THEN 'USADO'
        WHEN t.fecha_expiracion < NOW() THEN 'EXPIRADO'
        ELSE 'ACTIVO'
    END as estado_token
FROM tokens_recuperacion t
JOIN usuarios u ON t.id_usuario = u.id;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================
-- CONSULTAS ÚTILES PARA DESARROLLO
-- =========================================

/*
-- Consultas de ejemplo para usar durante desarrollo:

-- Buscar libros disponibles
SELECT * FROM v_libros_disponibles WHERE disponibilidad = 'DISPONIBLE';

-- Ver préstamos activos
SELECT * FROM v_prestamos_activos;

-- Simular aprobación de préstamo pendiente
UPDATE prestamos SET estado = 'APROBADO' WHERE estado = 'PENDIENTE' LIMIT 1;

-- Simular devolución de libro
UPDATE prestamos SET 
    estado = 'DEVUELTO', 
    fecha_devolucion_real = NOW() 
WHERE estado = 'APROBADO' AND id = 2;

-- Verificar usuarios con contraseñas hasheadas
SELECT id, nombre, correo, 
       CASE 
           WHEN password_hash IS NOT NULL THEN 'CON HASH' 
           ELSE 'SIN HASH' 
       END as seguridad
FROM usuarios;

-- Generar nuevo token de recuperación
INSERT INTO tokens_recuperacion (id_usuario, token, fecha_expiracion, ip_solicitud)
VALUES (2, MD5(CONCAT(NOW(), RAND())), NOW() + INTERVAL 2 HOUR, '127.0.0.1');

-- Limpiar tokens expirados
DELETE FROM tokens_recuperacion 
WHERE fecha_expiracion < NOW() OR usado = TRUE;
*/

-- =========================================
-- NOTAS IMPORTANTES
-- =========================================

/*
CREDENCIALES DE PRUEBA:
- Admin: admin@biblioteca.com / admin123
- Usuario: juan.perez@estudiante.com / usuario123
- Usuario: maria.gonzalez@estudiante.com / usuario456

CONTRASEÑAS:
- Actualmente usando SHA256 como demostración
- TODO: Implementar bcrypt o Argon2 en la aplicación Java
- Los hashes son: SHA2('contraseña', 256)

STOCK DE LIBROS:
- Cien Años de Soledad: 2/3 disponibles (1 prestado)
- El Principito: 5/5 disponibles
- Don Quijote: 1/2 disponibles (1 prestado)
- Java Programming: 3/4 disponibles (1 prestado)  
- Base de Datos: 0/2 disponibles (2 prestados - uno vencido)

ESTADOS DE PRÉSTAMOS:
- DEVUELTO: Préstamo completado exitosamente
- APROBADO: Libro actualmente prestado
- PENDIENTE: Solicitud esperando aprobación
- VENCIDO: Préstamo que pasó fecha límite (automático por trigger)
- CANCELADO: Solicitud cancelada

TOKENS DE RECUPERACIÓN:
- Token activo: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
- Expira en 2 horas desde la inserción
- IP de solicitud registrada para auditoría

PRUEBAS RECOMENDADAS:
1. Intentar préstamo de libro sin stock (debe fallar)
2. Aprobar préstamo pendiente (debe reducir stock)
3. Devolver libro prestado (debe aumentar stock)
4. Crear usuario con email duplicado (debe fallar)
5. Usar token de recuperación válido
6. Verificar expiración automática de tokens
*/