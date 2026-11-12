package es.laboratorio.status;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.sql.DataSource;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * Comprueba la conexión con PostgreSQL a través del datasource JNDI que define Tomcat
 * (java:comp/env/jdbc/appdb). Las credenciales no están en el código: las configura Tomcat.
 */
@WebServlet(name = "db", urlPatterns = {"/db"})
public class DbServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private static final String JNDI_NAME = "java:comp/env/jdbc/appdb";
    private static final String SQL =
            "SELECT current_database(), current_user, "
            + "(SELECT valor FROM lab_info WHERE clave = 'mensaje')";

    private transient volatile DataSource dataSource;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("application/json");
        resp.setCharacterEncoding(StandardCharsets.UTF_8.name());
        resp.setHeader("Cache-Control", "no-store");

        long start = System.nanoTime();
        try (Connection con = dataSource().getConnection();
             Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(SQL)) {
            rs.next();
            long ms = (System.nanoTime() - start) / 1_000_000;
            String body = "{\"status\":\"UP\""
                    + ",\"database\":" + json(rs.getString(1))
                    + ",\"user\":" + json(rs.getString(2))
                    + ",\"message\":" + json(rs.getString(3))
                    + ",\"latencyMs\":" + ms + "}";
            resp.setStatus(HttpServletResponse.SC_OK);
            resp.getWriter().write(body);
        } catch (NamingException | SQLException e) {
            // El detalle del error va al log del servidor; al cliente solo se le dice que está caída.
            log("No se pudo consultar la base de datos", e);
            resp.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
            resp.getWriter().write("{\"status\":\"DOWN\"}");
        }
    }

    private DataSource dataSource() throws NamingException {
        DataSource ds = dataSource;
        if (ds == null) {
            ds = (DataSource) new InitialContext().lookup(JNDI_NAME);
            dataSource = ds;
        }
        return ds;
    }

    /** Valor como cadena JSON, con los caracteres especiales escapados. */
    static String json(String s) {
        if (s == null) {
            return "null";
        }
        StringBuilder sb = new StringBuilder(s.length() + 2).append('"');
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.append('"').toString();
    }
}
