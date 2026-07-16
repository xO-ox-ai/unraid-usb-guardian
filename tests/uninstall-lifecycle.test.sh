#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${root}/plugin/usr/local/emhttp/plugins/usb.guardian/scripts/uninstall"

events=()
lock_held=false
worker_checks=0

record() {
  events+=("$1")
}

boot_flash_is_safe() {
  return 0
}

assert_no_worker() {
  worker_checks=$((worker_checks + 1))
  record "worker-check-${worker_checks}"
}

acquire_transaction_lock() {
  lock_held=true
  record 'lock-acquired'
}

assert_no_recovery_state() {
  [[ "${lock_held}" == true ]]
  record 'state-recheck-under-lock'
}

remove_package() {
  [[ "${lock_held}" == true ]]
  record 'removepkg-under-lock'
}

remove_runtime_state() {
  [[ "${lock_held}" == true ]]
  record 'runtime-cleanup-under-lock'
}

logger() {
  :
}

# The production function calls /usr/bin/logger directly. Keep this test focused on the destructive phases.
uninstall_main --remove-package
expected=(
  'worker-check-1'
  'lock-acquired'
  'worker-check-2'
  'state-recheck-under-lock'
  'removepkg-under-lock'
  'runtime-cleanup-under-lock'
)
[[ "${events[*]}" == "${expected[*]}" ]] || {
  printf 'unexpected full-removal sequence: %s\n' "${events[*]}" >&2
  exit 1
}

events=()
lock_held=false
worker_checks=0
uninstall_main
expected=(
  'worker-check-1'
  'lock-acquired'
  'worker-check-2'
  'state-recheck-under-lock'
  'runtime-cleanup-under-lock'
)
[[ "${events[*]}" == "${expected[*]}" ]] || {
  printf 'unexpected direct-helper sequence: %s\n' "${events[*]}" >&2
  exit 1
}

printf 'Uninstall lifecycle behavior tests passed.\n'
