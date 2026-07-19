'use strict';

const fs = require('fs');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const root = 'plugin/usr/local/emhttp/plugins/usb.guardian';
const english = JSON.parse(fs.readFileSync(`${root}/language/en_US.json`, 'utf8'));
const chinese = JSON.parse(fs.readFileSync(`${root}/language/zh_CN.json`, 'utf8'));
const settingsPage = fs.readFileSync(`${root}/USBGuardian.page`, 'utf8');
const mainHook = fs.readFileSync(`${root}/USBGuardianMainHook.page`, 'utf8');
const languageHook = fs.readFileSync(`${root}/USBGuardianLanguageHook.page`, 'utf8');
const guardianJs = fs.readFileSync(`${root}/assets/guardian.js`, 'utf8');
const guardianCss = fs.readFileSync(`${root}/assets/guardian.css`, 'utf8');
const settingsJs = fs.readFileSync(`${root}/assets/settings.js`, 'utf8');
const menuLanguage = fs.readFileSync(`${root}/unraid-language/zh_CN/usb.guardian.txt`, 'utf8');
const pluginReadme = fs.readFileSync(`${root}/README.md`, 'utf8');

assert(Object.keys(english).length >= 100, 'English source catalog is unexpectedly incomplete');
assert(Object.keys(chinese).length >= Object.keys(english).length, 'Chinese catalog is missing source entries');
for (const key of Object.keys(english)) {
  assert(typeof chinese[key] === 'string' && chinese[key].length > 0, `Chinese catalog is missing: ${key}`);
}
for (const required of [
  '@reason.inspection_failed.message',
  '@reason.open_files.advice',
  '@reason.shfs_unhealthy.message',
  '@reason.usb_remove_failed.advice',
  '@reason.interrupted_by_reboot.message',
]) {
  assert(typeof chinese[required] === 'string', `Chinese reason fallback is missing: ${required}`);
}
assert(settingsPage.includes("require_once '/usr/local/emhttp/plugins/usb.guardian/include/localization.php'"),
  'Settings page does not load the plugin localization helper');
assert(settingsPage.includes('Menu="Utilities:30"'), 'Settings tile is not registered under User Programs');
assert(menuLanguage.includes('USB Guardian=USB安全弹出'), 'Chinese Settings tile title is missing');
assert(languageHook.includes('Menu="Buttons:5z"')
  && languageHook.includes('usb_guardian_merge_unraid_menu_catalog()'),
  'Chinese Settings tile title is not merged before Unraid builds menu panels');
assert(pluginReadme.includes('html:lang(zh)') && pluginReadme.includes('可以安全拔出'),
  'Plugin Manager description does not follow the page language or lacks the Chinese safety notice');
assert(mainHook.includes("require_once '/usr/local/emhttp/plugins/usb.guardian/include/localization.php'"),
  'Main hook does not load the plugin localization helper');
assert(settingsPage.includes("'i18n' => usb_guardian_catalog()") && mainHook.includes("'i18n' => usb_guardian_catalog()"),
  'Pages do not publish the selected catalog to JavaScript');
assert(!settingsPage.includes('_('), 'Settings page still relies on pre-evaluation translation tokens');
assert(guardianJs.includes('translationTemplates') && guardianJs.includes('@reason.${code}.message'),
  'Main UI does not support templates and reason-code translation fallbacks');
assert(guardianJs.includes('document.createTextNode(tr(action.label))'),
  'Icon action buttons bypass the selected translation catalog');
assert(settingsJs.includes('runtime.i18n'), 'Settings UI does not use the selected catalog');
assert(settingsPage.includes('id="usb-guardian-clear-logs"')
  && settingsJs.includes("request('clear_logs')")
  && settingsJs.includes('window.confirm'),
  'The localized log-clear control is missing its confirmation or API action');
assert(guardianCss.includes('#disk-table-body tr.toggle-disk>td:first-child')
  && guardianCss.includes('.usb-guardian-control-wrap { position:absolute;'),
  'The static safe-eject control does not reserve a layout-neutral position in UD rows');

console.log('localization contract tests passed.');
