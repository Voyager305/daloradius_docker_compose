#!/bin/sh
set -eu

DB_HOST="${MARIADB_HOST:-mariadb}"
DB_PORT="${MARIADB_PORT:-3306}"
DB_NAME="${MARIADB_DATABASE:-radius}"
DB_USER="${MARIADB_USER:-radius}"
DB_PASS="${MARIADB_PASSWORD:-radius}"
SQL_DIR="${DALORADIUS_SQL_DIR:-/var/www/daloradius/contrib/db}"
FR_SQL_FILE="${SQL_DIR}/fr3-mariadb-freeradius.sql"
DALO_SQL_FILE="${SQL_DIR}/mariadb-daloradius.sql"
TARGET_CHARSET="utf8mb4"
TARGET_COLLATION="utf8mb4_unicode_ci"

echo "Waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
for i in $(seq 1 60); do
  if mariadb -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 2

  if [ "$i" -eq 60 ]; then
    echo "MariaDB did not become ready in time" >&2
    exit 1
  fi
done

if [ ! -f "${FR_SQL_FILE}" ] || [ ! -f "${DALO_SQL_FILE}" ]; then
  echo "SQL files not found in ${SQL_DIR}" >&2
  exit 1
fi

echo "Checking if schema is already initialized..."
operators_count="$(mariadb -N -s -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
  -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='operators';")"

if [ "${operators_count}" = "0" ]; then
  echo "Importing FreeRADIUS and daloRADIUS schema..."
  mariadb -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "${FR_SQL_FILE}"
  mariadb -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" < "${DALO_SQL_FILE}"
  echo "Schema import complete."
else
  echo "Schema already exists, skipping import."
fi

echo "Normalizing database/table collations to ${TARGET_COLLATION}..."
mariadb -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
  -e "ALTER DATABASE \`${DB_NAME}\` CHARACTER SET ${TARGET_CHARSET} COLLATE ${TARGET_COLLATION};"

tables_to_convert="$(mariadb -N -s -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
  -e "SELECT table_name FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_type='BASE TABLE' AND table_collation <> '${TARGET_COLLATION}';")"

if [ -n "${tables_to_convert}" ]; then
  echo "${tables_to_convert}" | while IFS= read -r table_name; do
    [ -n "${table_name}" ] || continue
    mariadb -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
      -e "ALTER TABLE \`${table_name}\` CONVERT TO CHARACTER SET ${TARGET_CHARSET} COLLATE ${TARGET_COLLATION};"
  done
fi

echo "Collation normalization complete."
