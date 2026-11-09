<#
.SYNOPSIS
    Replica la configuracion de Nuvio Desktop (addons ES + TorBox + plugins Latam)
    en otro equipo Windows.

.DESCRIPTION
    Copia nuvio_addons.properties, nuvio_plugins.properties y los ajustes de
    idioma/reproductor a %APPDATA%\Nuvio, respaldando antes lo que hubiera.

    NO incluye los addons TPB Adult (excluidos a proposito).
    NO toca biblioteca, historial, progreso ni perfiles.

.PARAMETER TorBoxApiKey
    Clave de TorBox. Si se omite, se pide por teclado.

.PARAMETER SinTorBox
    Instala todo pero sin clave de TorBox (addons gratis / P2P).

.PARAMETER SoloAddons
    Instala solo addons, sin plugins.

.PARAMETER SoloPlugins
    Instala solo plugins, sin addons.

.PARAMETER Destino
    Ruta de datos de Nuvio. Por defecto %APPDATA%\Nuvio

.EXAMPLE
    .\Instalar-NuvioConfig.ps1
    .\Instalar-NuvioConfig.ps1 -TorBoxApiKey "fab288a8-..." 
    .\Instalar-NuvioConfig.ps1 -SinTorBox -SoloAddons
#>

[CmdletBinding()]
param(
    [string]$TorBoxApiKey,
    [switch]$SinTorBox,
    [switch]$SoloAddons,
    [switch]$SoloPlugins,
    [string]$Destino
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Destino) { $Destino = Join-Path $env:APPDATA 'Nuvio' }

function Write-Paso  { param($m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    [OK] $m" -ForegroundColor Green }
function Write-Aviso { param($m) Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host "    [X]  $m" -ForegroundColor Red }

Write-Host @"
==============================================================
   CONFIGURADOR DE NUVIO DESKTOP  -  Perfil: ZORO (es)
==============================================================
   Destino: $Destino
==============================================================
"@ -ForegroundColor White

# ---------------------------------------------------------------- 0. Comprobaciones
Write-Paso "Comprobando entorno"

if (-not (Test-Path $Destino)) {
    Write-Err "No existe la carpeta de datos de Nuvio: $Destino"
    Write-Aviso "Abre Nuvio al menos una vez en este equipo y vuelve a ejecutar."
    exit 1
}
Write-Ok "Carpeta de datos encontrada"

$proc = Get-Process -Name 'Nuvio' -ErrorAction SilentlyContinue
if ($proc) {
    Write-Aviso "Nuvio esta en ejecucion. Cierralo para que los cambios se apliquen."
    $r = Read-Host "    Cerrar Nuvio ahora? (s/N)"
    if ($r -eq 's') {
        $proc | Stop-Process -Force
        Start-Sleep -Seconds 2
        Write-Ok "Nuvio cerrado"
    } else {
        Write-Err "Cancelado: cierra Nuvio manualmente y reintenta."
        exit 1
    }
}

# ---------------------------------------------------------------- 1. TorBox
if (-not $SinTorBox -and -not $TorBoxApiKey) {
    Write-Paso "Clave de TorBox"
    Write-Host "    Pega tu API key de TorBox (Enter vacio = omitir)" -ForegroundColor Gray
    $TorBoxApiKey = (Read-Host "    API key").Trim()
    if (-not $TorBoxApiKey) { $SinTorBox = $true }
}

if ($TorBoxApiKey) {
    if ($TorBoxApiKey -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        Write-Aviso "La clave no tiene formato UUID de TorBox. Se usara igualmente."
    } else {
        Write-Ok "Clave TorBox valida: $($TorBoxApiKey.Substring(0,8))...$($TorBoxApiKey.Substring($TorBoxApiKey.Length-4))"
    }
} else {
    Write-Aviso "Instalando SIN TorBox (solo P2P / enlaces directos)"
}

# ---------------------------------------------------------------- 2. Backup
Write-Paso "Copia de seguridad de la configuracion actual"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $Destino "_backup_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$ficheros = @(
    'nuvio_addons.properties',
    'nuvio_plugins.properties',
    'nuvio_player_settings.properties',
    'nuvio_player_track_preferences.properties',
    'nuvio_tmdb_settings.properties',
    'nuvio_mdblist_settings.properties',
    'torrent_settings.properties'
)
$n = 0
foreach ($f in $ficheros) {
    $src = Join-Path $Destino $f
    if (Test-Path $src) { Copy-Item $src $backupDir -Force; $n++ }
}
Write-Ok "$n archivo(s) respaldados en: $backupDir"

# ---------------------------------------------------------------- 3. Addons
function New-AddonsProperties {
    param([string]$ApiKey, [bool]$ConTorBox)

    $tb = if ($ConTorBox) { $ApiKey } else { '' }

    $urls = [System.Collections.Generic.List[string]]::new()

    # --- Catalogos / metadatos
    $urls.Add('https://catalog.nuvio.tv/manifest.json')
    $urls.Add('https://v3-cinemeta.strem.io/manifest.json')
    $urls.Add('https://7a82163c306e-stremio-netflix-catalog-addon.baby-beamup.club/bmZ4LGRucCxhbXAsaGJtLG1wOSxjcnUsYXRwOjpFUzoxNzk0MDQxODIyNDE0OjA6MDpFUw%3D%3D/manifest.json')
    $urls.Add('https://pigamer37.alwaysdata.net/onAirCatalogs=animeav1%2Chenaojara%2Ctioanime%2Clatanime/manifest.json')

    # --- Subtitulos
    $urls.Add('https://opensubtitles-v3.strem.io/manifest.json')

    # --- Streams con TorBox
    if ($ConTorBox) {
        $urls.Add("https://torrentio.strem.fun/providers=mejortorrent,wolfmax4k%7Ctorbox=$tb/manifest.json")
        $onepaceJson = '{"debridServices":[{"service":"torbox","apiKey":"' + $tb + '"}]}'
        $onepaceB64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($onepaceJson))
        $urls.Add("https://onepace-premium.e6ip.com/$onepaceB64/manifest.json")
    } else {
        $urls.Add('https://torrentio.strem.fun/providers=mejortorrent,wolfmax4k/manifest.json')
    }

    # --- Streams propios (sin clave)
    $urls.Add('https://xperience-app.com/manifest/c98e63f8-b8a2-45bb-80e4-610da18eb73a/eyJhbGciOiJIUzI1NiJ9.eyJwaWQiOiJjOThlNjNmOC1iOGEyLTQ1YmItODBlNC02MTBkYTE4ZWI3M2EiLCJraWQiOiJmNzBkNDViNS02OWNiLTQ5YjgtOTU5Yy1kZDU3NjhjYzFlYTQiLCJzY29wZSI6Im1hbmlmZXN0Iiwic3ViIjoiYmVmZDNmZWUtMDA5ZS00ZDkxLWE0MzEtYjBhM2U4MmYxZDZlIiwiaWF0IjowfQ.rfkiqp1hhRi1C6NTfYlh2WQED-cbgtlqMaxY8mk6268/manifest.json')
    $urls.Add('https://aiostreams-nightly.fortheweak.cloud/stremio/0531c0cd-afa3-4b00-8ba1-b628b76c67b5/eyJpIjoiaHJ4ZlQvbDV0NTRaRmd5cytLUXI5dz09IiwiZSI6IkI4L2FkQnh2dzQ3TUlZTy9EOWJOWGVoa0NMMTg4MzBSMDFjQldvTWVZbkU9IiwidCI6ImEifQ/manifest.json')
    $urls.Add('https://animesub.duckdns.org/u_lJeiWS4dDqUORlfF5mE-jw/manifest.json')
    $urls.Add('https://stremiofcpremium.ddns.net/a/d62a613021c3f2c87d7eb968/manifest.json')
    $urls.Add('https://pelis-addon.com/cJ8uzOsOvMadXIurHyqhvGmL/manifest.json')
    $urls.Add('https://8bcec99c5d97-spanish-links-addon.baby-beamup.club/manifest.json')
    $urls.Add('https://addon.peerflix.mov/enc_BJdP3ew5F6DW74v_1PfmgOZv1JZMRM6uXDUrttaIBVpKO0MV3R4OFW4er5oSeeMDhGcqoU5_l2WYhIa2ASupPsVtAnXF5ourj_jyPK1ihTm3kiFa_K_uYf45OFenYFZY-kmfzsncMXNfuFWQS5FtBEfi7cDaqpDb8o2C1LrkIFIty4bkqdTG5EG3TW6CTtuhg-ukF-7ESFNWF-Yfs75G1wOq4yvIZbQDzuPIvLS35SvGUOJ143RDxEmXQgOSapHEZar1ehBNWmQh7b13s5YI-UcUD_XQg9p0pFvw7eV7QTFIX_FMmHfuLpfOhjAQM_VhUSAPTLo3gm205zZejw/manifest.json')

    # --- Cometa / Comet con TorBox (payload base64 generado en vivo)
    if ($ConTorBox) {
        $cometaCfg = [ordered]@{
            maxResultsPerResolution = 5
            maxSize = 5368709120
            cachedOnly = $false
            sortCachedUncachedTogether = $false
            removeTrash = $true
            resultFormat = @('all')
            debridServices = @(@{ service = 'torbox'; apiKey = $tb })
            enableTorrent = $true
            deduplicateStreams = $false
            scrapeDebridAccountTorrents = $false
            debridStreamProxyPassword = ''
            languages = [ordered]@{ required = @('es'); allowed = @('es'); exclude = @(); preferred = @('es') }
            resolutions = @{}
            options = [ordered]@{
                remove_ranks_under = -10000000000
                allow_english_in_languages = $false
                remove_unknown_languages = $false
            }
        }
        $cometaJson = $cometaCfg | ConvertTo-Json -Depth 10 -Compress
        $cometaB64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cometaJson)).TrimEnd('=').Replace('+','-').Replace('/','_')
        $urls.Add("https://cometa.stremaddon.net/$cometaB64/manifest.json")

        $cometCfg = [ordered]@{
            maxResultsPerResolution = 0
            maxSize = 0
            cachedOnly = $false
            sortCachedUncachedTogether = $false
            removeTrash = $true
            resultFormat = @('all')
            debridServices = @(@{ service = 'torbox'; apiKey = $tb })
            enableTorrent = $false
            deduplicateStreams = $false
            scrapeDebridAccountTorrents = $false
            debridStreamProxyPassword = ''
            languages = [ordered]@{ required = @('es'); allowed = @('es'); exclude = @(); preferred = @('es') }
            resolutions = [ordered]@{ r480p = $false; r360p = $false; r240p = $false; unknown = $false }
            options = [ordered]@{
                remove_ranks_under = -10000000000
                allow_english_in_languages = $false
                remove_unknown_languages = $false
            }
        }
        $cometJson = $cometCfg | ConvertTo-Json -Depth 10 -Compress
        $cometB64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cometJson))
        $urls.Add("https://comet.elfhosted.com/$cometB64/manifest.json")

        # MediaFusion: el token de instancia es propio de la cuenta TorBox
        $urls.Add('https://mediafusion.elfhosted.com/D-WSvi33vzw9Kvk7eWQpRNCjkvSZv_CK-NL1D-igMwOrL8zgEnpmK_9iFFkcjv7I_QuPg2kmzQPv0jn49Q1t_KStRk1XtKdkjfjJ7wDOPIiTjDRj52hku9gkHkF3TfUsm6VMM2TsGcAv08-VrMG9t4D2UUJEG2jblx7ZLUEXe8Etle4jCr-sxuA6I6owpNy3d9AlYU6V0_RS8zvpq9G_tR-FyX_x89Wt7h6OzWkx5VSzVpLgrczuHtIDNcs92Wpiipms2YYVbz8MDwWW1ecPiu1-QOq5dbKBSBzo8pIBHSl3N7NezBsTyq_nzU8ai6ivu-zRS3E5A8nblmKLn7MZulQS0GahgjcMo1C7zw8fhASdojPoDyzDbPsoFvDLFM1LD4iv1t5s1KdI2xjnyKstA81yq2h4PM2ce0O9ADYR2Z3ejJvG-Tw_TiKCqtUY0IWOjEHJ_cN-n_HPnpzyHR9kFH-ecDw9OhobwunCErGwSye7BpgFYeqaXKamzH4w7clJqFivcM2k_g9oDQvL6xMSYDgAJrUf3Fom8BU2_n1gP2Jgw6tnxIqgB6k1qcQPxkGX37q-5u1mqwsSR2jj1-glhdJbcF8aUeB-fW5rh0aWugFV6NMKRVGL6d0MQr9IcNLOPV5zyvATSS2l-twRg2R4ncrglRAL7OId9c2sksZi9TfiLE8bdNJQjMACn-G2lx9SfMM62kzaZCZWJn16alIoYrMbZoYxxJzNcvakgks6V9OMQSBPYMWGrRQ-TOx4Ad8UqqWNSB9HliP0gLEm9qzTABQJvfTTAK7zrXry-kt6fwgu1BqmqoR6QCjctBbfoWk64bBV5HqZtTaiLJu9OOSV2PsBq2yRO9Wm-fSoVkzgYTaEg1hQZwGPFqTfHt13HYWGCN4lqpgEgBed93LyHbu2BPAl8moA4nIA-c0Sz_7TnlyURuD4cuL0pMnzyKANbojRwcAJ79PHVzOA14-R5EqdYXEQ2s3Xh6kgzOpUux7_6J9qtXUqIAS0PKdZif_6qUiMXVW07v-28xEejl5qDTzxeu5Q/manifest.json')
    }

    # --- Serializacion estilo Java Properties
    $json = ($urls | ForEach-Object { '"' + ($_ -replace '\\','\\' -replace '"','\"') + '"' }) -join ','
    $json = '[' + $json + ']'
    $escaped = $json.Replace('\','\\').Replace(':','\:').Replace('=','\=')

    $estados = [ordered]@{}
    foreach ($u in $urls) { $estados[$u] = $true }
    # catalog.nuvio.tv estaba apagado en el perfil original
    foreach ($k in @($estados.Keys)) {
        if ($k -match 'catalog\.nuvio\.tv') { $estados[$k] = $false }
    }
    $estJson = ($estados.Keys | ForEach-Object {
        $v = if ($estados[$_]) { 'true' } else { 'false' }
        '"' + ($_ -replace '\\','\\' -replace '"','\"') + '":' + $v
    }) -join ','
    $estJson = '{' + $estJson + '}'
    $estEsc  = $estJson.Replace('\','\\').Replace(':','\:').Replace('=','\=')

    $sb = [Text.StringBuilder]::new()
    [void]$sb.AppendLine('#Nuvio desktop preferences')
    [void]$sb.AppendLine("#$(Get-Date -Format 'ddd MMM dd HH:mm:ss CET yyyy')")
    [void]$sb.AppendLine("installed_addon_urls_1=$escaped")
    [void]$sb.AppendLine("addon_enabled_states_1=$estEsc")

    return @{ Content = $sb.ToString(); Count = $urls.Count }
}

if (-not $SoloPlugins) {
    Write-Paso "Generando lista de addons"
    $res = New-AddonsProperties -ApiKey $TorBoxApiKey -ConTorBox (-not $SinTorBox)
    Set-Content -Path (Join-Path $Destino 'nuvio_addons.properties') -Value $res.Content -Encoding UTF8 -NoNewline
    Write-Ok "$($res.Count) addons configurados (TPB Adult excluidos)"
}

# ---------------------------------------------------------------- 4. Plugins
if (-not $SoloAddons) {
    Write-Paso "Configurando plugins Latam"

    $srcPlugins = Join-Path $ScriptDir 'nuvio_plugins.properties'
    if (Test-Path $srcPlugins) {
        Copy-Item $srcPlugins (Join-Path $Destino 'nuvio_plugins.properties') -Force
        Write-Ok "Plugins copiados desde plantilla local"
    } else {
        Write-Aviso "No se encontro nuvio_plugins.properties junto al script."
        Write-Host "    Anade el repositorio a mano en Nuvio:" -ForegroundColor Gray
        Write-Host "    Servicios > Plugins > Anadir repositorio" -ForegroundColor Gray
        Write-Host "    https://raw.githubusercontent.com/komangulo/sdfsdfwer/refs/heads/main/manifest.json" -ForegroundColor White
    }
}

# ---------------------------------------------------------------- 5. Ajustes ES
Write-Paso "Aplicando ajustes en espanol"

$ajustes = @{
    'nuvio_player_settings.properties' = @"
#Nuvio desktop preferences
#$(Get-Date -Format 'ddd MMM dd HH:mm:ss CET yyyy')
preferred_audio_language_1=es
resize_mode_1=Stretch

"@
    'torrent_settings.properties' = @"
#Nuvio desktop preferences
#$(Get-Date -Format 'ddd MMM dd HH:mm:ss CET yyyy')
p2p_enabled_1=true

"@
}

foreach ($k in $ajustes.Keys) {
    Set-Content -Path (Join-Path $Destino $k) -Value $ajustes[$k] -Encoding UTF8 -NoNewline
}
Write-Ok "Idioma de audio preferido: es (Castellano)"
Write-Ok "P2P activado"

# TMDB en espanol (conserva la clave existente si la hay)
$tmdbPath = Join-Path $Destino 'nuvio_tmdb_settings.properties'
$tmdbKey = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJlZjYxMTMwODZjNGFjZTZkMDI1NjgyNzg2MTRiNjUxMCIsIm5iZiI6MTc5Mzk4ODM0OS41NCwic3ViIjoiNmFlZTE2ZmQzOTE5NWJiOTFlOWY4MDhlIiwic2NvcGVzIjpbImFwaV9yZWFkIl0sInZlcnNpb24iOjF9.IJZN7dnmt3dg9SSX8nxBbLe7HAvxXHiyWocslDva7ZU'
if (Test-Path $tmdbPath) {
    $existente = Get-Content $tmdbPath -Raw
    if ($existente -match 'tmdb_api_key_1=([^\r\n]+)') { $tmdbKey = $Matches[1] }
}
@"
#Nuvio desktop preferences
#$(Get-Date -Format 'ddd MMM dd HH:mm:ss CET yyyy')
tmdb_language_1=es
tmdb_api_key_1=$tmdbKey
tmdb_enabled_1=true

"@ | Set-Content -Path $tmdbPath -Encoding UTF8 -NoNewline
Write-Ok "Metadatos TMDB en espanol"

# MDBList: ratings agregados (IMDb, RT, Metacritic, Trakt)
$mdblistPath = Join-Path $Destino 'nuvio_mdblist_settings.properties'
$mdblistKey = '5f4ps7nsi9oda4dvr6b1yh58g'
if (Test-Path $mdblistPath) {
    $existente = Get-Content $mdblistPath -Raw
    if ($existente -match 'mdblist_api_key_1=([^\r\n]+)') { $mdblistKey = $Matches[1] }
}
@"
#Nuvio desktop preferences
#$(Get-Date -Format 'ddd MMM dd HH:mm:ss CET yyyy')
mdblist_api_key_1=$mdblistKey

"@ | Set-Content -Path $mdblistPath -Encoding UTF8 -NoNewline
Write-Ok "Ratings MDBList configurados"

# ---------------------------------------------------------------- 6. Resumen
Write-Host @"

==============================================================
   LISTO
==============================================================

   Backup guardado en:
   $backupDir

   Siguiente paso:
   1. Abre Nuvio
   2. Ajustes > Servicios > Addons  (comprueba la lista)
   3. Ajustes > Servicios > Plugins (activa los que quieras)
   4. Si usas TorBox: Ajustes > Servicios > Servicios conectados
      y autoriza TorBox con el codigo de dispositivo

   Nota: los plugins vienen con solo 2 activos (AnimeAV1,
   Henaojara). Activa el resto a mano segun necesidad.

==============================================================
"@ -ForegroundColor White

if ($TorBoxApiKey) {
    Write-Aviso "Tu clave de TorBox queda guardada en este equipo."
}
