package es.laboratorio.status;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.lang.management.ManagementFactory;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;

/**
 * Panel de estado: muestra información útil para diagnosticar un despliegue
 * (quién ejecuta el proceso, cómo llegó la petición, cuánto lleva en marcha).
 */
@WebServlet(name = "status", urlPatterns = {""})
public class StatusServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setStatus(HttpServletResponse.SC_OK);
        resp.setContentType("text/html");
        resp.setCharacterEncoding(StandardCharsets.UTF_8.name());
        resp.setHeader("Cache-Control", "no-store");

        try (PrintWriter out = resp.getWriter()) {
            out.println("<!DOCTYPE html>");
            out.println("<html lang=\"es\">");
            out.println("<head>");
            out.println("  <meta charset=\"UTF-8\">");
            out.println("  <title>Panel de estado</title>");
            out.println("  <link rel=\"stylesheet\" href=\"/style.css\">");
            out.println("</head>");
            out.println("<body>");
            out.println("  <h1>Panel de estado</h1>");
            out.println("  <p>Aplicaci&oacute;n Java en Tomcat, detr&aacute;s de Nginx.</p>");
            out.println("  <table>");
            row(out, "Servidor (contenedor)", hostName());
            row(out, "Java", "Java " + Runtime.version().feature());
            row(out, "Usuario del proceso", System.getProperty("user.name"));
            row(out, "Tiempo en marcha", uptime());
            row(out, "Hora del servidor (UTC)", Instant.now().toString());
            row(out, "Esquema de la petición", req.getScheme());
            row(out, "Conexión segura", String.valueOf(req.isSecure()));
            row(out, "IP del cliente (vista por Tomcat)", req.getRemoteAddr());
            out.println("  </table>");
            out.println("  <p><a href=\"/health\">/health</a></p>");
            out.println("</body>");
            out.println("</html>");
        }
    }

    private static void row(PrintWriter out, String label, String value) {
        out.println("    <tr><th>" + escape(label) + "</th><td>" + escape(value) + "</td></tr>");
    }

    private static String hostName() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (IOException e) {
            return "desconocido";
        }
    }

    private static String uptime() {
        Duration d = Duration.ofMillis(ManagementFactory.getRuntimeMXBean().getUptime());
        return String.format("%dh %02dm %02ds", d.toHours(), d.toMinutesPart(), d.toSecondsPart());
    }

    /** Escapa HTML para que ningún valor (por ejemplo, una cabecera) pueda inyectar código. */
    static String escape(String s) {
        if (s == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (char c : s.toCharArray()) {
            switch (c) {
                case '&' -> sb.append("&amp;");
                case '<' -> sb.append("&lt;");
                case '>' -> sb.append("&gt;");
                case '"' -> sb.append("&quot;");
                case '\'' -> sb.append("&#39;");
                default -> sb.append(c);
            }
        }
        return sb.toString();
    }
}
