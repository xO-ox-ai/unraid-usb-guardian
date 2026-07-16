$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$go = Join-Path $root '.tools\go\bin\go.exe'
$php = Join-Path $root '.tools\php\php.exe'
$node = Join-Path $root '.tools\node\node.exe'
$bash = 'C:\Program Files\Git\bin\bash.exe'

if (!(Test-Path $go)) {
    throw 'Go toolchain not found under .tools\go.'
}
$env:GOCACHE = Join-Path $root '.cache\go-build'
$env:GOMODCACHE = Join-Path $root '.cache\go-mod'

& $go fmt '.\cmd\usb-guardian' '.\internal\guardian'
if ($LASTEXITCODE -ne 0) { throw 'gofmt failed.' }
& $go test -count=1 '.\...'
if ($LASTEXITCODE -ne 0) { throw 'Go tests failed.' }
& $go vet '.\...'
if ($LASTEXITCODE -ne 0) { throw 'go vet failed.' }

$env:GOOS = 'linux'
$env:GOARCH = 'amd64'
$env:CGO_ENABLED = '0'
& $go test -c -o (Join-Path $root '.build\guardian-linux-tests') '.\internal\guardian'
if ($LASTEXITCODE -ne 0) { throw 'Linux test binary compile failed.' }

if (!(Test-Path $php)) {
    throw 'Local PHP toolchain not found under .tools\php.'
}
Get-ChildItem -Recurse -File -Path (Join-Path $root 'plugin') -Include '*.php', '*.page' | ForEach-Object {
    & $php -l $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "PHP syntax check failed: $($_.FullName)" }
}
& $php -n (Join-Path $root 'tests\ud-adapter-contract.test.php')
if ($LASTEXITCODE -ne 0) { throw 'UD adapter mounted-state contract tests failed.' }
& $php -n (Join-Path $root 'tests\lease-contract.test.php')
if ($LASTEXITCODE -ne 0) { throw 'Safe-to-unplug lease contract tests failed.' }
& $php -n (Join-Path $root 'tests\boot-mount-contract.test.php')
if ($LASTEXITCODE -ne 0) { throw 'Persistent boot-mount contract tests failed.' }

if (Test-Path $bash) {
    Get-ChildItem -Recurse -File -Path (Join-Path $root 'plugin') | Where-Object {
        (Get-Content $_.FullName -TotalCount 1 -ErrorAction SilentlyContinue) -match '^#!.*/(?:ba)?sh'
    } | ForEach-Object {
        & $bash -n ($_.FullName.Replace('\', '/'))
        if ($LASTEXITCODE -ne 0) { throw "Shell syntax check failed: $($_.FullName)" }
    }
}

if (!(Test-Path $node)) {
    throw 'Local Node.js toolchain not found under .tools\node.'
}
Get-ChildItem -File -Path (Join-Path $root 'plugin\usr\local\emhttp\plugins\usb.guardian\assets') -Filter '*.js' | ForEach-Object {
    & $node --check $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "JavaScript syntax check failed: $($_.FullName)" }
}
& $node (Join-Path $root 'tests\guardian-ui-vm.test.js')
if ($LASTEXITCODE -ne 0) { throw 'Guardian UI authority/lease VM tests failed.' }
& $node (Join-Path $root 'tests\localization-contract.test.js')
if ($LASTEXITCODE -ne 0) { throw 'Localization contract tests failed.' }

$bash = 'C:\Program Files\Git\bin\bash.exe'
if (!(Test-Path -LiteralPath $bash)) { throw 'Git Bash is required for uninstall lifecycle tests.' }
& $bash (Join-Path $root 'tests\uninstall-lifecycle.test.sh')
if ($LASTEXITCODE -ne 0) { throw 'Uninstall lifecycle behavior tests failed.' }

$forbidden = rg -n --glob '!docs/**' --glob '!README.md' --glob '!scripts/check.ps1' '(--device\b|/usr/local/sbin/usb-guardian|/boot/logs/usb\.guardian|last-job\.json|umount\s+-[A-Za-z]*[lf]|umount\s+--(?:lazy|force)|rc\.unassigned\s+umount|do_unmount\s*\()' cmd internal plugin scripts 2>$null
if ($LASTEXITCODE -eq 0) {
    throw "Forbidden legacy or unsafe path found:`n$forbidden"
}
if ($LASTEXITCODE -ne 1) {
    throw 'Static safety scan failed to run.'
}

function Assert-ContainsAll([string]$Path, [string[]]$Needles) {
    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($needle in $Needles) {
        if (!$content.Contains($needle)) {
            throw "Lifecycle safety check failed: $Path is missing '$needle'."
        }
    }
    return $content
}

$uninstallPath = Join-Path $root 'plugin\usr\local\emhttp\plugins\usb.guardian\scripts\uninstall'
$uninstall = Assert-ContainsAll $uninstallPath @(
    'set -euo pipefail', '.transaction.lock', 'flock', 'active.json',
    'ud-adapter', 'adapter_states', 'adapter_artifacts', '/bin/rm -rf -- "${RUN_ROOT}"',
    'uninstall_main', '--remove-package', 'remove_package', '/sbin/removepkg usb.guardian'
)
$uninstallLock = $uninstall.IndexOf('exec 9>>"${LOCK_FILE}"', [StringComparison]::Ordinal)
$uninstallMain = $uninstall.IndexOf('uninstall_main()', [StringComparison]::Ordinal)
$uninstallStateCheck = $uninstall.IndexOf('assert_no_recovery_state', $uninstallMain, [StringComparison]::Ordinal)
$uninstallRemovePackage = $uninstall.IndexOf('remove_package', $uninstallStateCheck, [StringComparison]::Ordinal)
$uninstallRuntimeCleanup = $uninstall.IndexOf('remove_runtime_state', $uninstallRemovePackage, [StringComparison]::Ordinal)
if ($uninstallLock -lt 0 -or $uninstallMain -lt 0 -or $uninstallStateCheck -le $uninstallMain -or
    $uninstallRemovePackage -le $uninstallStateCheck -or $uninstallRuntimeCleanup -le $uninstallRemovePackage) {
    throw 'Uninstall lifecycle lock/check/delete ordering is unsafe.'
}

$buildPath = Join-Path $root 'scripts\build.ps1'
$build = Assert-ContainsAll $buildPath @(
    'timeout --signal=TERM --kill-after=5s', '.transaction.lock', 'exec 9>>',
    'active_markers=(', 'adapter_states=(', 'adapter_artifacts=(',
    '/sbin/upgradepkg --install-new', '/usr/local/emhttp/plugins/usb.guardian/event/started'
)
$plgStart = $build.IndexOf('$plg = @"', [StringComparison]::Ordinal)
if ($plgStart -lt 0) { throw 'Generated PLG template was not found.' }
$plgInline = $build.Substring($plgStart)
$buildLock = $plgInline.IndexOf('exec 9>>', [StringComparison]::Ordinal)
$buildStateCheck = $plgInline.IndexOf('active_markers=(', [StringComparison]::Ordinal)
$buildUpgrade = $plgInline.IndexOf('/sbin/upgradepkg --install-new', [StringComparison]::Ordinal)
$buildStarted = $plgInline.IndexOf('/usr/local/emhttp/plugins/usb.guardian/event/started', [StringComparison]::Ordinal)
if ($buildLock -lt 0 -or $buildStateCheck -le $buildLock -or $buildUpgrade -le $buildStateCheck -or $buildStarted -le $buildUpgrade) {
    throw 'Generated PLG lifecycle lock/check/upgrade/start ordering is unsafe.'
}

$plgRemoveStart = $plgInline.IndexOf('<FILE Run="/bin/bash" Method="remove">', [StringComparison]::Ordinal)
if ($plgRemoveStart -lt 0) { throw 'Generated PLG remove template was not found.' }
$plgRemove = $plgInline.Substring($plgRemoveStart)
$helperRemoval = $plgRemove.IndexOf('"`${UNINSTALL_SCRIPT}" --remove-package', [StringComparison]::Ordinal)
$parentRemoval = $plgRemove.IndexOf('/sbin/removepkg usb.guardian', [StringComparison]::Ordinal)
if ($helperRemoval -lt 0 -or $parentRemoval -ge 0) {
    throw 'Generated PLG removal must delegate package removal to the lock-owning helper.'
}

Write-Host 'All source checks passed.'
exit 0
