$ErrorActionPreference = 'Stop'

$root = (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[a-z0-9.]+)?$') {
    throw "Invalid VERSION: $version"
}
$packageVersion = $version.Replace('-', '_')
$packageName = "usb.guardian-$packageVersion-x86_64-1.txz"
$repository = 'xO-ox-ai/unraid-usb-guardian'
$pluginUrl = "https://raw.githubusercontent.com/$repository/main/usb.guardian.plg"
$supportUrl = "https://github.com/$repository/issues"
$packageUrl = "https://github.com/$repository/releases/download/v$version/$packageName"
$dist = Join-Path $root 'dist'
$buildRoot = Join-Path $root '.build'
$stage = Join-Path $buildRoot 'stage'
$intermediateTar = Join-Path $buildRoot 'usb.guardian-package.tar'
$stageTarPath = '.build/stage'
$intermediateTarPath = '.build/usb.guardian-package.tar'
$go = Join-Path $root '.tools\go\bin\go.exe'
$gnuTar = 'C:\Program Files\Git\usr\bin\tar.exe'

if (!(Test-Path $go)) {
    throw 'Go toolchain not found under .tools\go.'
}
if (!(Test-Path $gnuTar)) {
    throw 'GNU tar from Git for Windows is required to normalize Unix file modes.'
}

New-Item -ItemType Directory -Force -Path $dist, $buildRoot | Out-Null
if (Test-Path $stage) {
    $resolvedBuild = [IO.Path]::GetFullPath($buildRoot).TrimEnd('\') + '\'
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    if (!$resolvedStage.StartsWith($resolvedBuild, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean stage outside build directory: $resolvedStage"
    }
    Remove-Item -Recurse -Force -LiteralPath $stage
}
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item -Recurse -Path (Join-Path $root 'plugin\*') -Destination $stage
$legacySbin = Join-Path $stage 'usr\local\sbin'
if (Test-Path $legacySbin) {
    Remove-Item -Recurse -Force -LiteralPath $legacySbin
}

$binaryDir = Join-Path $stage 'usr\local\emhttp\plugins\usb.guardian\bin'
New-Item -ItemType Directory -Force -Path $binaryDir | Out-Null

$env:GOCACHE = Join-Path $root '.cache\go-build'
$env:GOMODCACHE = Join-Path $root '.cache\go-mod'
$env:GOOS = 'linux'
$env:GOARCH = 'amd64'
$env:CGO_ENABLED = '0'
& $go build -buildvcs=false -trimpath -ldflags "-s -w -X main.version=$version" -o (Join-Path $binaryDir 'usb-guardian') '.\cmd\usb-guardian'
if ($LASTEXITCODE -ne 0) {
    throw 'Linux worker build failed.'
}

$required = @(
    'usr\local\emhttp\plugins\usb.guardian\bin\usb-guardian',
    'usr\local\emhttp\plugins\usb.guardian\api.php',
    'usr\local\emhttp\plugins\usb.guardian\USBGuardian.page',
    'usr\local\emhttp\plugins\usb.guardian\USBGuardianMainHook.page',
    'usr\local\emhttp\plugins\usb.guardian\scripts\ud_adapter.php',
    'usr\local\emhttp\plugins\usb.guardian\event\started'
)
foreach ($relative in $required) {
    if (!(Test-Path (Join-Path $stage $relative))) {
        throw "Required package file is missing: $relative"
    }
}

Get-ChildItem -LiteralPath $dist -Filter 'usb.guardian-*.txz' -File | Remove-Item -Force
if (Test-Path $intermediateTar) {
    Remove-Item -Force -LiteralPath $intermediateTar
}

$executablePaths = @(
    'usr/local/emhttp/plugins/usb.guardian/bin/usb-guardian',
    'usr/local/emhttp/plugins/usb.guardian/event/started',
    'usr/local/emhttp/plugins/usb.guardian/scripts/rc.usb_guardian',
    'usr/local/emhttp/plugins/usb.guardian/scripts/ud_adapter.php',
    'usr/local/emhttp/plugins/usb.guardian/scripts/uninstall'
)
$createArgs = @(
    '-cf', $intermediateTarPath,
    '--format=ustar', '--sort=name', '--mtime=@0',
    '--owner=0', '--group=0', '--numeric-owner',
    '--mode=u+rwX,go+rX,go-w'
)
foreach ($path in $executablePaths) {
    $createArgs += "--exclude=$path"
}
$createArgs += @('-C', $stageTarPath, 'usr')
& $gnuTar @createArgs
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to create normalized package tar.'
}

$appendArgs = @(
    '-rf', $intermediateTarPath,
    '--format=ustar', '--mtime=@0',
    '--owner=0', '--group=0', '--numeric-owner', '--mode=0755',
    '-C', $stageTarPath
) + $executablePaths
& $gnuTar @appendArgs
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to add executable package files.'
}

$txzPath = Join-Path $dist $packageName
if (Test-Path $txzPath) {
    Remove-Item -Force -LiteralPath $txzPath
}
$archiveReference = '@' + $intermediateTarPath
tar -cJf $txzPath --uid 0 --gid 0 --uname root --gname root $archiveReference
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to xz-compress plugin package.'
}

$sha = (Get-FileHash -Algorithm SHA256 $txzPath).Hash.ToLowerInvariant()
$size = (Get-Item $txzPath).Length
$plg = @"
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE PLUGIN [
<!ENTITY name "usb.guardian">
<!ENTITY author "xO-ox-ai">
<!ENTITY version "$version">
<!ENTITY pluginURL "$pluginUrl">
<!ENTITY supportURL "$supportUrl">
<!ENTITY packageName "$packageName">
<!ENTITY packageURL "$packageUrl">
]>
<PLUGIN name="&name;" author="&author;" version="&version;" pluginURL="&pluginURL;" support="&supportURL;" min="7.2.4" icon="eject">
  <CHANGES>
###$version
- Fixed static controls being hidden when UD uses a non-umount role for a mounted, running, disabled, or partition-aggregated disk row.
- Made the static entry point depend only on a canonical UD disk row and device identifier; all eligibility decisions remain click-time backend checks.

###0.1.0-beta5
- Added a static mounted-device control to every UD disk row; eligibility and safety requests now start only after a click.
- Decorated UD 2025.11.18 disk HTML before its atomic tbody replacement so the control renders in the same frame as UD controls.
- Removed the safe-eject control from table layout flow and reserved a fixed slot to prevent column movement during redraws.

###0.1.0-beta4
- Fixed the certified Unassigned Devices 2025.11.18 library loader so UD file-scope state remains globally visible.
- Added strict support for Unraid 7.3.2 systems with separate /mnt/user0 and /mnt/user shfs processes.
- Stopped unchanged device-list polling from replacing safe-eject controls and retained warning controls across transient list failures.
- Added an English and Chinese Enable USB Guardian setting, enforced by both list and eject APIs.

###0.1.0-beta3
- Fixed integration with Unraid's global CSRF validation for plugin POST requests.
- Added clear refresh guidance when Unraid rejects a stale page request.
- Disabled embedded Git VCS metadata so release packages are reproducible across documentation-only commits.

###0.1.0-beta2
- Added Community Applications metadata and single-URL online installation.
- Added a SHA-256 verified release-package download to the PLG manifest.

###0.1.0-beta1
- Initial guarded USB safe-eject beta for Unraid 7.2.4 and newer.
  </CHANGES>

  <FILE Name="/boot/config/plugins/usb.guardian/&packageName;">
    <URL>&packageURL;</URL>
    <SHA256>$sha</SHA256>
  </FILE>

  <FILE Run="/bin/bash" Method="install">
    <INLINE>
<![CDATA[
set -e
PACKAGE="/boot/config/plugins/usb.guardian/$packageName"
EXPECTED_SHA256="$sha"
boot_flash_is_safe() {
  local awk_bin
  awk_bin="`$(command -v awk 2>/dev/null || true)"
  [[ -n "`${awk_bin}" && -x "`${awk_bin}" && -r /proc/self/mountinfo ]] || return 1
  "`${awk_bin}" '
    {
      separator = 0
      for (i = 7; i <= NF; i++) if (`$i == "-") { separator = i; break }
      if (`$5 == "/boot") {
        count++
        fstype = `$(separator + 1)
        source = `$(separator + 2)
        if (separator > 0 && `$4 == "/" && `$6 ~ /(^|,)rw(,|`$)/ &&
            (fstype == "vfat" || fstype == "msdos" || fstype == "fat") && source ~ /^\/dev\//) valid++
      }
      protected = "/boot/config/plugins/usb.guardian"
      if (`$5 != "/boot" && (index(protected "/", `$5 "/") == 1 || index(`$5 "/", protected "/") == 1)) shadow++
    }
    END { exit !(count == 1 && valid == 1 && shadow == 0) }
  ' /proc/self/mountinfo
}
if ! boot_flash_is_safe; then
  echo "USB Guardian install refused: /boot is not a single writable FAT block-device mount"
  exit 1
fi
if [[ ! -f "`${PACKAGE}" ]]; then
  echo "USB Guardian package is missing: `${PACKAGE}"
  exit 1
fi
ACTUAL_SHA256=`$(/usr/bin/sha256sum "`${PACKAGE}" | /usr/bin/cut -d' ' -f1)
if [[ "`${ACTUAL_SHA256}" != "`${EXPECTED_SHA256}" ]]; then
  echo "USB Guardian package checksum mismatch"
  exit 1
fi

CONFIG_ROOT="/boot/config/plugins/usb.guardian"
CONFIG_FILE="`${CONFIG_ROOT}/usb.guardian.cfg"
LOG_DIR="`${CONFIG_ROOT}/logs"
RUN_ROOT="/run/usb-guardian"
JOB_DIR="`${RUN_ROOT}/jobs"
ADAPTER_STATE_DIR="`${RUN_ROOT}/ud-adapter"
TRANSACTION_DIR="`${LOG_DIR}/transactions"
LOCK_FILE="`${LOG_DIR}/.transaction.lock"
OLD_BINARY="/usr/local/emhttp/plugins/usb.guardian/bin/usb-guardian"

/usr/bin/install -d -m 0700 "`${CONFIG_ROOT}" "`${LOG_DIR}" "`${RUN_ROOT}" "`${JOB_DIR}" "`${ADAPTER_STATE_DIR}"

# Give an installed worker one bounded chance to resolve a dead transaction before locking the upgrade.
if [[ -x "`${OLD_BINARY}" ]]; then
  if [[ ! -x /usr/bin/timeout ]]; then
    echo "USB Guardian upgrade refused: timeout is unavailable for bounded recovery"
    exit 1
  fi
  if ! /usr/bin/timeout --signal=TERM --kill-after=5s 70s "`${OLD_BINARY}" recover --config "`${CONFIG_FILE}" --job-dir "`${JOB_DIR}" --log-dir "`${LOG_DIR}"; then
    echo "USB Guardian upgrade refused: the installed worker could not recover interrupted state"
    exit 1
  fi
fi

FLOCK_BIN=`$(command -v flock 2>/dev/null || true)
if [[ -z "`${FLOCK_BIN}" || ! -x "`${FLOCK_BIN}" ]]; then
  echo "USB Guardian upgrade refused: flock is unavailable"
  exit 1
fi
exec 9>>"`${LOCK_FILE}"
if ! "`${FLOCK_BIN}" -n 9; then
  echo "USB Guardian upgrade refused: a transaction owns the persistent lock"
  exit 1
fi

# All state checks are repeated under FD 9, which remains locked through upgrade and startup.
if /usr/bin/pgrep -f '^/usr/local/emhttp/plugins/usb[.]guardian/bin/usb-guardian eject ' >/dev/null 2>&1; then
  echo "USB Guardian upgrade refused: a safe-eject worker is running"
  exit 1
fi
shopt -s nullglob
active_markers=("`${TRANSACTION_DIR}"/*/active.json)
adapter_states=("`${ADAPTER_STATE_DIR}"/*.json)
adapter_artifacts=("`${ADAPTER_STATE_DIR}"/*)
if (( `${#active_markers[@]} > 0 )); then
  echo "USB Guardian upgrade refused: an active transaction marker remains"
  exit 1
fi
if (( `${#adapter_states[@]} > 0 )); then
  echo "USB Guardian upgrade refused: Unassigned Devices rollback state remains"
  exit 1
fi
if (( `${#adapter_artifacts[@]} > 0 )); then
  echo "USB Guardian upgrade refused: unrecognized adapter recovery artifacts remain"
  exit 1
fi

/sbin/upgradepkg --install-new "`${PACKAGE}"
/usr/local/emhttp/plugins/usb.guardian/event/started
for old_package in "`${CONFIG_ROOT}"/usb.guardian-*.txz; do
  if [[ "`${old_package}" != "`${PACKAGE}" ]]; then
    /bin/rm -f -- "`${old_package}"
  fi
done
# FD 9 is intentionally held until the install script exits.
]]>
    </INLINE>
  </FILE>

  <FILE Run="/bin/bash" Method="remove">
    <INLINE>
<![CDATA[
set -e
UNINSTALL_SCRIPT="/usr/local/emhttp/plugins/usb.guardian/scripts/uninstall"
if [[ ! -x "`${UNINSTALL_SCRIPT}" ]]; then
  echo "USB Guardian cannot be uninstalled safely: lifecycle helper is missing"
  exit 1
fi
"`${UNINSTALL_SCRIPT}" --remove-package
/bin/rm -rf -- /usr/local/emhttp/plugins/usb.guardian
/bin/rm -f -- /boot/config/plugins/usb.guardian/usb.guardian-*.txz
]]>
    </INLINE>
  </FILE>
</PLUGIN>
"@
$plgPath = Join-Path $dist 'usb.guardian.plg'
[IO.File]::WriteAllText($plgPath, $plg, [Text.UTF8Encoding]::new($false))
$rootPlgPath = Join-Path $root 'usb.guardian.plg'
[IO.File]::WriteAllText($rootPlgPath, $plg, [Text.UTF8Encoding]::new($false))

Write-Host "Built $txzPath"
Write-Host "SHA256 $sha"
Write-Host "Size $size bytes"
Write-Host "Built $plgPath"
Write-Host "Built $rootPlgPath"
