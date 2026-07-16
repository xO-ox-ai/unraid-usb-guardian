(function () {
  'use strict';

  const runtime = window.UsbGuardianSettingsRuntime;
  const form = document.getElementById('usb-guardian-settings-form');
  const notice = document.getElementById('usb-guardian-settings-notice');
  const diagnosticsButton = document.getElementById('usb-guardian-download-diagnostics');
  if (!runtime || !form || !notice || !diagnosticsButton) {
    return;
  }

  const translations = runtime.i18n && typeof runtime.i18n === 'object' ? runtime.i18n : {};
  const tr = (text) => typeof translations[text] === 'string' ? translations[text] : text;

  function showNotice(kind, message) {
    notice.className = `usb-guardian-settings-notice usb-guardian-settings-notice-${kind}`;
    notice.textContent = tr(message);
  }

  async function request(action, fields = {}) {
    const body = new URLSearchParams({ action, csrf_token: runtime.csrfToken, ...fields });
    const response = await window.fetch(runtime.apiUrl, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
      body: body.toString(),
      cache: 'no-store',
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok || payload?.ok !== true) {
      throw new Error(payload?.error?.message || 'USB Guardian request failed.');
    }
    return payload.data;
  }

  function populate(settings) {
    for (const [name, value] of Object.entries(settings)) {
      const input = form.elements.namedItem(name);
      if (!input) {
        continue;
      }
      if (input.type === 'checkbox') {
        input.checked = value === 'yes';
      } else {
        input.value = value;
      }
    }
  }

  async function loadSettings() {
    try {
      populate(await request('settings'));
    } catch (error) {
      showNotice('error', error.message);
    }
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const submit = form.querySelector('button[type="submit"]');
    submit.disabled = true;
    showNotice('progress', 'Saving settings...');
    try {
      const data = Object.fromEntries(new FormData(form).entries());
      data.ENABLE_SG_IO = form.elements.namedItem('ENABLE_SG_IO').checked ? 'yes' : 'no';
      data.PERSISTENT_LOGGING = 'yes';
      populate(await request('save_settings', data));
      showNotice('success', 'USB Guardian settings saved.');
    } catch (error) {
      showNotice('error', error.message);
    } finally {
      submit.disabled = false;
    }
  });

  diagnosticsButton.addEventListener('click', async () => {
    diagnosticsButton.disabled = true;
    showNotice('progress', 'Collecting diagnostics...');
    try {
      const body = new URLSearchParams({ action: 'diagnostics', csrf_token: runtime.csrfToken });
      const response = await window.fetch(runtime.apiUrl, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
        body: body.toString(),
        cache: 'no-store',
      });
      if (!response.ok) {
        const payload = await response.json().catch(() => null);
        throw new Error(payload?.error?.message || 'Unable to download diagnostics.');
      }
      const blob = await response.blob();
      const disposition = response.headers.get('Content-Disposition') || '';
      const match = disposition.match(/filename="([A-Za-z0-9._-]+)"/);
      const filename = match ? match[1] : 'usb-guardian-diagnostics.zip';
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.append(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
      showNotice('success', 'Diagnostics archive downloaded.');
    } catch (error) {
      showNotice('error', error.message);
    } finally {
      diagnosticsButton.disabled = false;
    }
  });

  loadSettings();
})();
