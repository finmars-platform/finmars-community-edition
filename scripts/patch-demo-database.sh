#!/usr/bin/env sh

# Note: will not work when sourced from a different directory
script_dir=$(dirname "$0")
. "$script_dir/common_functions.sh"

run_sql()
{
  docker compose exec db psql --username "${DB_USER}" --dbname "$1" --command "$2"
}

# SQL SCRIPTS
sql_change_listview_dates="
-- Update date keys if they are present, ignore date keys which aren't
UPDATE space00000.ui_listlayout AS ull
SET json_data = updated.json_data
FROM (SELECT id,
             jsonb_set(
             jsonb_set(
             jsonb_set(
                 CASE
                     WHEN json_data::jsonb #>> '{reportLayoutOptions,datepickerOptions,reportFirstDatepicker,date}' = '0001-01-01'
                     THEN json_data::jsonb
                     ELSE jsonb_set(json_data::jsonb,
                                    '{reportLayoutOptions,datepickerOptions,reportFirstDatepicker,date}', '\"2022-12-01\"', false)
                 END,
                 '{reportLayoutOptions,datepickerOptions,reportLastDatepicker,date}', '\"2025-03-31\"', false),
                 '{reportOptions,begin_date}', '\"2022-12-01\"', false),
                 '{reportOptions,end_date}', '\"2025-03-31\"', false)
              as json_data
      FROM space00000.ui_listlayout) AS updated
WHERE ull.id = updated.id;
"


print_step_info "Setting report date picker to demo data range"
run_sql "backend_realm00000" "$sql_change_listview_dates"
