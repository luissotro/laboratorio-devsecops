-- Se ejecuta una sola vez, al crear la base de datos (la imagen ya ha creado "appdb").
-- La contraseña del usuario de la aplicación se lee del secreto montado en el contenedor,
-- así que nunca aparece en el repositorio.
\set app_password `cat /run/secrets/db_app_password`

CREATE ROLE app LOGIN PASSWORD :'app_password'
    NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;

-- Mínimo privilegio: el usuario "app" solo puede conectarse y leer lo que se le concede.
REVOKE ALL ON DATABASE appdb FROM PUBLIC;
GRANT CONNECT ON DATABASE appdb TO app;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO app;

CREATE TABLE lab_info (
    clave text PRIMARY KEY,
    valor text NOT NULL
);
INSERT INTO lab_info (clave, valor) VALUES ('mensaje', 'Hola desde PostgreSQL');
GRANT SELECT ON lab_info TO app;
