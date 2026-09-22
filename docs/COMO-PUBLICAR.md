# Publicar la política de privacidad en GitHub Pages

`index.html` de esta carpeta es la misma política que está publicada como página de Claude,
pero como documento independiente. Sirve si algún día quieres la URL en un dominio propio.

1. Crea un repositorio en GitHub (puede ser público y vacío), por ejemplo `tv-remote`.
2. Sube esta carpeta `docs/` tal cual.
3. En el repositorio: **Settings › Pages**. En *Source* elige `Deploy from a branch`,
   rama `main` y carpeta `/docs`. Guarda.
4. A los pocos minutos la página queda en
   `https://TU-USUARIO.github.io/tv-remote/`.
5. Pega esa dirección en App Store Connect, en *App Privacy › Privacy Policy URL*.

Antes de publicar, cambia `CORREO@EJEMPLO.COM` y `EMAIL@EXAMPLE.COM` por tu correo de contacto
(están una vez en cada idioma).
