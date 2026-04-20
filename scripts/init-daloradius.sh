#!/bin/sh
set -eu

APP_DIR="/var/www/daloradius"
CONF_FILE="${APP_DIR}/app/common/includes/daloradius.conf.php"
HTMLPURIFIER_CACHE_DIR="${APP_DIR}/app/common/library/htmlpurifier/HTMLPurifier/DefinitionCache/Serializer"
DALORADIUS_GIT_REF="${DALORADIUS_GIT_REF:-master}"
REPO_URL="https://github.com/lirantal/daloradius.git"

DB_HOST="${MARIADB_HOST:-mariadb}"
DB_PORT="${MARIADB_PORT:-3306}"
DB_NAME="${MARIADB_DATABASE:-radius}"
DB_USER="${MARIADB_USER:-radius}"
DB_PASS="${MARIADB_PASSWORD:-radius}"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmpdir}"
}
trap cleanup EXIT

if [ ! -f "${APP_DIR}/app/operators/index.php" ]; then
  echo "Downloading daloRADIUS (${DALORADIUS_GIT_REF})..."
  git clone --depth 1 --branch "${DALORADIUS_GIT_REF}" "${REPO_URL}" "${tmpdir}/src"
  rm -rf "${APP_DIR:?}/"* "${APP_DIR:?}"/.[!.]* "${APP_DIR:?}"/..?* 2>/dev/null || true
  cp -a "${tmpdir}/src/." "${APP_DIR}/"
fi

if [ ! -f "${CONF_FILE}" ]; then
  if [ ! -f "${CONF_FILE}.sample" ]; then
    echo "Missing sample config file: ${CONF_FILE}.sample" >&2
    exit 1
  fi
  cp "${CONF_FILE}.sample" "${CONF_FILE}"
fi

sed -i "s|^\$configValues\['CONFIG_DB_HOST'\].*|\$configValues['CONFIG_DB_HOST'] = '${DB_HOST}';|" "${CONF_FILE}"
sed -i "s|^\$configValues\['CONFIG_DB_PORT'\].*|\$configValues['CONFIG_DB_PORT'] = '${DB_PORT}';|" "${CONF_FILE}"
sed -i "s|^\$configValues\['CONFIG_DB_USER'\].*|\$configValues['CONFIG_DB_USER'] = '${DB_USER}';|" "${CONF_FILE}"
sed -i "s|^\$configValues\['CONFIG_DB_PASS'\].*|\$configValues['CONFIG_DB_PASS'] = '${DB_PASS}';|" "${CONF_FILE}"
sed -i "s|^\$configValues\['CONFIG_DB_NAME'\].*|\$configValues['CONFIG_DB_NAME'] = '${DB_NAME}';|" "${CONF_FILE}"
sed -i "s|^\$configValues\['CONFIG_PATH_DALO_VARIABLE_DATA'\].*|\$configValues['CONFIG_PATH_DALO_VARIABLE_DATA'] = '/var/www/daloradius/var';|" "${CONF_FILE}"
sed -i "s|^\$configValues\['CONFIG_PATH_DALO_TEMPLATES_DIR'\].*|\$configValues['CONFIG_PATH_DALO_TEMPLATES_DIR'] = '/var/www/daloradius/app/common/templates';|" "${CONF_FILE}"

mkdir -p "${APP_DIR}/var/log" "${APP_DIR}/var/backup"
mkdir -p "${HTMLPURIFIER_CACHE_DIR}"
chmod -R 775 "${APP_DIR}/var"
chmod -R 775 "${APP_DIR}/app/common/library/htmlpurifier/HTMLPurifier/DefinitionCache"
find "${APP_DIR}/app/common/library/htmlpurifier/HTMLPurifier/DefinitionCache" -type f -exec chmod 664 {} \;
chown -R 82:82 "${APP_DIR}/var" "${APP_DIR}/app/common/library/htmlpurifier/HTMLPurifier/DefinitionCache" "${CONF_FILE}" || true

MANAGEMENT_FUNCTIONS="${APP_DIR}/app/operators/include/management/functions.php"
if [ -f "${MANAGEMENT_FUNCTIONS}" ]; then
  # Fix known query alias typo seen in some builds.
  sed -i "s/\`u\`\.\`username\`/\`ui\`\.\`username\`/g" "${MANAGEMENT_FUNCTIONS}"

  # Avoid fatal errors if a query returns DB_Error instead of a result set.
  sed -i "s/return intval(\$res->fetchrow()\\[0\\]);/if (DB::isError(\$res)) { return 0; } return intval(\$res->fetchrow()[0]);/" "${MANAGEMENT_FUNCTIONS}"
  sed -i "s/return \$dbSocket->query(\$query)->fetchrow()\\[0\\];/\$res = \$dbSocket->query(\$query); if (DB::isError(\$res)) { return 0; } return \$res->fetchrow()[0];/" "${MANAGEMENT_FUNCTIONS}"
fi

echo "daloRADIUS app files are ready."
