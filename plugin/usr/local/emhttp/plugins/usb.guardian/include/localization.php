<?php

declare(strict_types=1);

function usb_guardian_locale(): string
{
    $locale = (string)($_SESSION['locale'] ?? '');
    return $locale === 'zh_CN' ? 'zh_CN' : 'en_US';
}

function usb_guardian_catalog(): array
{
    static $catalogs = [];

    $locale = usb_guardian_locale();
    if (isset($catalogs[$locale])) {
        return $catalogs[$locale];
    }

    $root = '/usr/local/emhttp/plugins/usb.guardian/language';
    $path = $root.'/'.$locale.'.json';
    $fallback = $root.'/en_US.json';
    $json = @file_get_contents($path);
    if ($json === false && $path !== $fallback) {
        $json = @file_get_contents($fallback);
    }
    $decoded = is_string($json) ? json_decode($json, true) : null;
    $catalogs[$locale] = is_array($decoded)
        ? array_filter($decoded, static fn ($value, $key): bool => is_string($key) && is_string($value), ARRAY_FILTER_USE_BOTH)
        : [];
    return $catalogs[$locale];
}

function usb_guardian_merge_unraid_menu_catalog(?string $locale = null, ?array $language = null): array
{
    $base = $language ?? ($GLOBALS['language'] ?? []);
    if (!is_array($base)) {
        $base = [];
    }

    $locale = strtolower((string)($locale ?? ($_SESSION['locale'] ?? ($GLOBALS['locale'] ?? 'en_US'))));
    if (!str_starts_with($locale, 'zh')) {
        return $base;
    }

    $path = dirname(__DIR__).'/unraid-language/zh_CN/usb.guardian.txt';
    $catalog = @parse_ini_file($path, false, INI_SCANNER_RAW);
    return is_array($catalog) ? array_merge($base, $catalog) : $base;
}

function usb_guardian_t(string $text): string
{
    $catalog = usb_guardian_catalog();
    return $catalog[$text] ?? $text;
}

function usb_guardian_h(string $text): string
{
    return htmlspecialchars(usb_guardian_t($text), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
