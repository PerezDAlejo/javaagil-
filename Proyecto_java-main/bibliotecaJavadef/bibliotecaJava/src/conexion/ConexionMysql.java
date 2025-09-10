
package conexion;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.DriverManager;

public class ConexionMysql {
    
    public static Connection conectar() {
        Connection conn = null;
        try {
            conn=DriverManager.getConnection("jdbc:mysql://localhost:3306/biblioteca_proyecto_yava", "root", "1234");
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return conn;
        }
}