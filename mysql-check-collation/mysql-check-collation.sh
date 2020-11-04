#!/bin/bash

schema=$1
charset=$2
collation=$3

if [[ -z "$schema" || "$1" == "--help" ]]; then
  echo "check-mysql-collation"
  echo "usage: $0 <schema> <charset> <collation>"
  echo
  echo "where charset & collation are the expected values."
  echo "ex: $0 mydbname utf8mb4 utf8mb4_unicode_ci"
  exit 1
fi
if [ -z "$charset" ]; then
  echo "ERROR: charset not given"
  echo "usage: $0 <schema> <charset> <collation>"
  exit 1
fi
if [ -z "$collation" ]; then
  echo "ERROR: collation not given"
  echo "usage: $0 <schema> <charset> <collation>"
  exit 1
fi

source_env() {
  [ -f .env ] && source .env
  [ -f .env.local ] && source .env.local
}

# Detect mysql conf from ENV
# Use defaults for local env
set_mysql_args() {
  local h=""
  if [[ -n "$MYSQL_HOST" ]]; then
    h="-h$MYSQL_HOST"
  else
    h="-hlocalhost"
  fi

  local u=""
  if [[ -n "$MYSQL_USER" ]]; then
    u="-u$MYSQL_USER"
  else
    u="-uroot"
  fi

  local p=""
  if [[ -n "$MYSQL_PASS" ]]; then
    p="-p$MYSQL_PASS"
  else
    p="-pmysql"
  fi

  # Always verbose
  if [[ -n "$MYSQL_DEBUG" ]]; then
    v="-v"
  fi

  MYSQL_CMD="mysql $v $h $u $p"
}

source_env
set_mysql_args

sql=$(cat << EOF
SELECT table_schema, table_name, column_name, character_set_name, collation_name
  FROM information_schema.columns
  WHERE table_schema = '${schema}'
    AND collation_name IS NOT NULL
    AND (character_set_name != '${charset}'
         OR collation_name != '${collation}')
    ORDER BY table_schema,table_name,ordinal_position;
EOF
);

out=$(echo "$sql" | $MYSQL_CMD --table 2>&1 | grep -v Warning)
count=$(echo "$out" | grep -v TABLE_SCHEMA | wc -l)
if [[ $count -gt 0 ]]; then
  echo "Found the following issues:"
  echo "$out"
  echo "Expected: charset=$charset collation=$collation"
  exit 2
fi
