# Utilidades de desarrollo

Scripts para hablar con el televisor desde el ordenador mientras se desarrolla.
No forman parte de la app.

- `validar_tv.py`: comprueba el protocolo contra un televisor real (información del
  dispositivo, envío de teclas) y escribe `config.json` con su IP, modelo y MAC.

`config.json` está excluido del repositorio porque contiene datos de una red concreta.
Copia `config.example.json` si necesitas la estructura.

```sh
python3 -m venv .venv && .venv/bin/pip install samsungtvws
.venv/bin/python tools/validar_tv.py 192.168.1.10
```
