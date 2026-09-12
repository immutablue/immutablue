#!/bin/bash
set -euo pipefail

# Same reasoning as the login hook: USER is not guaranteed to be exported in
# every context that runs this, and `set -u` would abort on a bare $USER.
logout_user="${USER:-$(id -un)}"

echo "${logout_user} has logged out"

