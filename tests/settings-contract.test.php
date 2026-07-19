<?php
declare(strict_types=1);

require_once __DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/include/api_helpers.php';

$defaults = guardian_default_settings();
if (($defaults['ENABLED'] ?? null) !== 'yes') {
    throw new RuntimeException('USB Guardian must default to enabled for upgrade compatibility.');
}

$_POST = [
    'ENABLED' => 'no',
    'LOG_LEVEL' => 'info',
    'LOG_RETENTION_DAYS' => '30',
    'MAX_LOG_MIB' => '128',
    'LOG_KEEP' => '20',
    'SETTLE_SECONDS' => '30',
    'SHFS_HEALTH_SECONDS' => '5',
    'ENABLE_SG_IO' => 'yes',
];
$validated = guardian_validate_settings_request();
if (($validated['ENABLED'] ?? null) !== 'no') {
    throw new RuntimeException('The disabled setting was not validated and retained.');
}

$_POST['ENABLED'] = 'maybe';
try {
    guardian_validate_settings_request();
    throw new RuntimeException('An invalid enabled setting was accepted.');
} catch (GuardianApiException $error) {
    if ($error->httpStatus !== 400) {
        throw $error;
    }
}

$api = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/api.php');
$hook = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/USBGuardianMainHook.page');
$settingsJs = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/assets/settings.js');
$settingsPage = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/USBGuardian.page');
$menuLanguage = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/unraid-language/zh_CN/usb.guardian.txt');
$pluginReadme = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/README.md');
$helpers = (string)file_get_contents(__DIR__.'/../plugin/usr/local/emhttp/plugins/usb.guardian/include/api_helpers.php');
if (substr_count($api, 'guardian_require_enabled();') < 2
    || !str_contains($api, 'guardian_save_settings_guarded($settings)')
    || !str_contains($api, "case 'clear_logs':")
    || !str_contains($hook, "['ENABLED']")
    || !str_contains($settingsJs, 'data.ENABLED')
    || !str_contains($settingsJs, "request('clear_logs')")
    || !str_contains($settingsPage, 'id="usb-guardian-clear-logs"')
    || !str_contains($settingsPage, 'Menu="Utilities:30"')
    || !str_contains($settingsPage, 'Title="USB Guardian"')
    || !str_contains($menuLanguage, 'USB Guardian=USB安全弹出')
    || !str_contains($pluginReadme, 'html:lang(zh)')
    || !str_contains($pluginReadme, 'Safe to unplug')
    || !str_contains($pluginReadme, '可以安全拔出')
    || !str_contains($helpers, "GUARDIAN_RUN_ROOT.'/diagnostics.lock'")
    || !str_contains($helpers, "GUARDIAN_LOG_DIR.'/.transaction.lock'")
    || !str_contains($helpers, "GUARDIAN_RUN_ROOT.'/flat-log.lock'")) {
    throw new RuntimeException('The settings and log-clear controls are not enforced across the UI and API paths.');
}

$logFixture = sys_get_temp_dir().DIRECTORY_SEPARATOR.'usb-guardian-logs-'.bin2hex(random_bytes(6));
$nested = $logFixture.DIRECTORY_SEPARATOR.'transactions'.DIRECTORY_SEPARATOR.'job-one';
if (!mkdir($nested, 0700, true)) {
    throw new RuntimeException('Unable to create the log-clear test fixture.');
}
file_put_contents($logFixture.DIRECTORY_SEPARATOR.'.transaction.lock', 'keep');
file_put_contents($logFixture.DIRECTORY_SEPARATOR.'api.log', 'old log');
file_put_contents($nested.DIRECTORY_SEPARATOR.'timeline.jsonl', '{}');
$removed = guardian_clear_log_directory($logFixture);
$remaining = array_values(array_diff(scandir($logFixture) ?: [], ['.', '..']));
if ($removed !== 4 || $remaining !== ['.transaction.lock']) {
    throw new RuntimeException('Log clearing did not remove only the intended entries: '.json_encode($remaining));
}
unlink($logFixture.DIRECTORY_SEPARATOR.'.transaction.lock');
rmdir($logFixture);

echo "Settings and log-clear contract tests passed.\n";
