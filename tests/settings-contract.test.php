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
if (substr_count($api, 'guardian_require_enabled();') < 2
    || !str_contains($api, 'guardian_save_settings_guarded($settings)')
    || !str_contains($hook, "['ENABLED']")
    || !str_contains($settingsJs, 'data.ENABLED')) {
    throw new RuntimeException('The enable switch is not enforced across UI, list, eject, and settings save paths.');
}

echo "Settings enable/disable contract tests passed.\n";
