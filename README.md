# Configurador de Nuvio Desktop

Replica tu configuración de Nuvio (addons en español + TorBox + plugins Latam) en otro equipo Windows.

## Contenido

| Archivo | Para qué |
|---|---|
| `EJECUTAR.bat` | **Doble clic aquí.** Lanza todo. |
| `Instalar-NuvioConfig.ps1` | El script real (puedes ejecutarlo con parámetros) |
| `nuvio_plugins.properties` | Los 53 scrapers del repo "Addon Latam Plugin" |

## Uso rápido

1. Copia esta carpeta al PC de destino (USB, carpeta compartida, etc.)
2. **Abre Nuvio una vez** y ciérralo (para que cree la carpeta de datos)
3. Doble clic en **`EJECUTAR.bat`**
4. Pega la clave de TorBox cuando la pida (o pulsa Enter para omitirla)
5. Abre Nuvio y comprueba

## Qué configura

**Addons (17, sin TPB Adult):**

| Tipo | Addons |
|---|---|
| Catálogos | catalog.nuvio.tv *(apagado)*, Cinemeta v3, Netflix Catalog, OnAirCatalogs (anime) |
| Subtítulos | OpenSubtitles V3 |
| Streams + TorBox | Torrentio (MejorTorrent + WolfMax4K), Cometa, Comet, OnePace, MediaFusion |
| Streams directos | Xperience, AIOStreams, AnimeSub, StremioFC, Pelis Addon, Spanish Links, Peerflix |

Los estados (activado/apagado) replican exactamente tu perfil: 16 activos, `catalog.nuvio.tv` apagado.

**Plugins:** repositorio `Addon Latam Plugin` v2.2.0 con 53 scrapers (2 activos: AnimeAV1, Henaojara)

**Ajustes en español:**
- Idioma de audio preferido: `es` (Castellano)
- Metadatos TMDB en `es`
- Ratings MDBList activados
- P2P activado
- Modo de imagen: Stretch

**Claves incluidas:** TorBox, TMDB (JWT) y MDBList. Si el equipo ya tiene una
clave propia de TMDB o MDBList, el script **conserva la existente** en lugar de
sobrescribirla.

## Opciones avanzadas

```powershell
# Sin TorBox (solo P2P)
.\Instalar-NuvioConfig.ps1 -SinTorBox

# Solo addons, sin plugins
.\Instalar-NuvioConfig.ps1 -SoloAddons

# Solo plugins
.\Instalar-NuvioConfig.ps1 -SoloPlugins

# Clave directa, sin preguntar
.\Instalar-NuvioConfig.ps1 -TorBoxApiKey "tu-clave-uuid"
```

## Qué NO hace

- ❌ No toca biblioteca, historial, progreso ni perfiles
- ❌ No incluye los addons TPB Adult
- ❌ No configura Trakt / Simkl (requieren login propio)
- ❌ No instala Nuvio: la app debe estar ya instalada

## Seguridad

El script **hace backup** de los archivos que va a reemplazar en:

```
%APPDATA%\Nuvio\_backup_AAAAMMDD-HHMMSS\
```

Si algo sale mal, copia esos archivos de vuelta.

⚠️ La clave de TorBox queda guardada en texto plano en `nuvio_addons.properties`.
Es lo mismo que hace Nuvio internamente, pero tenlo en cuenta si compartes el equipo.

## Si la política de PowerShell bloquea el script

El `.bat` ya lo resuelve con `-ExecutionPolicy Bypass`. Si aun así falla, ejecuta manualmente:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Instalar-NuvioConfig.ps1"
```
