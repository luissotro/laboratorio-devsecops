# =========================================================================
# Etapa 1: compilar la aplicación (WAR) y descargar el driver JDBC con Maven
# =========================================================================
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build
COPY app/pom.xml ./pom.xml
COPY app/src ./src
RUN mvn -B -q -DskipTests package

# Driver JDBC de PostgreSQL: va en el classpath de Tomcat (el datasource lo define Tomcat, no la aplicación)
RUN mvn -B -q org.apache.maven.plugins:maven-dependency-plugin:3.8.1:copy \
      -Dartifact=org.postgresql:postgresql:42.7.7 \
      -DoutputDirectory=/build/drivers

# =========================================================================
# Etapa 2: Tomcat endurecido
# =========================================================================
FROM tomcat:10.1-jre21-temurin

LABEL org.opencontainers.image.source="https://github.com/luissotro/laboratorio-devsecops"

# Hardening 1: eliminar las aplicaciones por defecto (manager, host-manager, examples, docs)
RUN rm -rf /usr/local/tomcat/webapps/* /usr/local/tomcat/webapps.dist

# Hardening 2: eliminar los bits SUID/SGID del sistema de ficheros
RUN find / -xdev -perm /6000 -type f -exec chmod a-s {} \; || true

# Hardening 3: usuario sin privilegios (el contenedor oficial corre como root por defecto)
RUN groupadd --system --gid 10001 tomcat && \
    useradd --system --uid 10001 --gid tomcat --home-dir /usr/local/tomcat \
            --shell /usr/sbin/nologin tomcat

# Configuración propia de Tomcat:
#  - server.xml: puerto de apagado desactivado, sin versión en errores, etc.
#  - context.xml: datasource JNDI hacia PostgreSQL (los valores se leen de variables de entorno)
COPY tomcat/server.xml  /usr/local/tomcat/conf/server.xml
COPY tomcat/context.xml /usr/local/tomcat/conf/context.xml

# La configuración queda como solo lectura para el usuario tomcat.
# Se crea conf/Catalina/localhost para que Tomcat no intente crearlo al arrancar
# (el sistema de ficheros del contenedor es de solo lectura en tiempo de ejecución).
RUN mkdir -p /usr/local/tomcat/conf/Catalina/localhost && \
    chown -R root:tomcat /usr/local/tomcat/conf && \
    chmod 750 /usr/local/tomcat/conf /usr/local/tomcat/conf/Catalina /usr/local/tomcat/conf/Catalina/localhost && \
    find /usr/local/tomcat/conf -maxdepth 1 -type f -exec chmod 640 {} +

# Driver JDBC en el classpath de Tomcat
COPY --from=build --chown=root:tomcat --chmod=0644 /build/drivers/postgresql-42.7.7.jar /usr/local/tomcat/lib/postgresql.jar

# La aplicación, como ROOT.war (cuelga de "/")
COPY --from=build --chown=root:tomcat --chmod=0640 /build/target/ROOT.war /usr/local/tomcat/webapps/ROOT.war

# Lee la contraseña de la base de datos desde el secreto de Docker y la expone como variable de entorno
COPY --chown=root:root --chmod=0755 tomcat/entrypoint.sh /usr/local/bin/entrypoint.sh

# Directorios donde Tomcat necesita escribir
RUN chown -R tomcat:tomcat /usr/local/tomcat/logs /usr/local/tomcat/temp /usr/local/tomcat/work

# PROPERTY_SOURCE permite usar ${VARIABLE_DE_ENTORNO} en context.xml (host, puerto, usuario y contraseña)
ENV CATALINA_OPTS="-XX:MaxRAMPercentage=75 -Djava.security.egd=file:/dev/./urandom -Dfile.encoding=UTF-8 \
 -Dorg.apache.tomcat.util.digester.PROPERTY_SOURCE=org.apache.tomcat.util.digester.EnvironmentPropertySource,org.apache.tomcat.util.digester.SystemPropertySource"

USER tomcat

# Solo HTTP interno: el TLS lo termina Nginx. Este puerto no se publica al exterior.
EXPOSE 8080

# Comprueba /health sin necesitar curl ni wget (solo bash)
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s --retries=5 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/8080 && printf "GET /health HTTP/1.0\r\nHost: localhost\r\n\r\n" >&3 && head -n1 <&3 | grep -q " 200 "' || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["catalina.sh", "run"]
