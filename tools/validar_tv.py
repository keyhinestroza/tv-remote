#!/usr/bin/env python3
"""Valida el protocolo de control remoto del Samsung Smart TV (Tizen) por red local."""

import json
import sys
import time

from samsungtvws import SamsungTVWS

IP = sys.argv[1] if len(sys.argv) > 1 else "192.168.1.6"

# Conexión segura (8002). El token se guarda en tv_token.txt tras autorizar en el TV.
tv = SamsungTVWS(host=IP, port=8002, token_file="tv_token.txt", name="RemotoKey", timeout=30)

# 1. Información del dispositivo por REST
info = tv.rest_device_info()
print(json.dumps(info, indent=2, ensure_ascii=False))

device = info.get("device", {})
model_name = device.get("modelName")
wifi_mac = device.get("wifiMac")
print(f"\nmodelName: {model_name}")
print(f"wifiMac:   {wifi_mac}")

# Algunos firmwares exponen la lista de teclas; la mayoría no.
teclas = info.get("supportedKeys") or device.get("supportedKeys")
print(f"Teclas soportadas: {teclas if teclas else 'el TV no las devuelve'}")

# 2. Envío de teclas (la primera vez el TV pide autorización en pantalla)
print("\nEnviando KEY_VOLUP... (acepta la autorización en el TV si aparece)")
tv.send_key("KEY_VOLUP")
time.sleep(1)
print("Enviando KEY_VOLDOWN...")
tv.send_key("KEY_VOLDOWN")
tv.close()

# 3. Configuración para la fase 2
with open("config.json", "w") as f:
    json.dump({"ip": IP, "modelName": model_name, "wifiMac": wifi_mac}, f, indent=2)
print("\nOK: config.json guardado.")
