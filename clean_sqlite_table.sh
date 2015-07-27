#!/bin/sh

# Turns out SQLite does not like databases with tens of millions lines.
# Especially so when the database file resides on a slow medium, such
# as a CompactFlash card. This script helps clean up a table when the DB
# must not block when doing the cleanup. Running VACUUM; after this script
# is recommended, although it will make the DB block.

set -eu

# File name of database
DB_FILE=/data/avdb

# Table name in database
DB_TABLE=deviceproperty_log

# Spare this many lines in the database. keeping the ones with ther largest ID.
# 100k to 1M lines should be the absolute maximum if running from a CF card
# Disclaimer: When measured, a 1x100 inner join over indexed columns took around one second when
# the larger table had ~10M rows on a CF card.
NUM_LINES_TO_KEEP=10000

# Delete lines this many rows at a time. Smaller values here result in faster transactions,
# lock the DB for a shorter time and require less space on the card. A larger value
# makes the DB block longer and require more space (possibly running out of it) but makes
# the overall operation faster
DELETE_BATCH_SIZE=10000

# Configuration ends here

first=$(sqlite3 "${DB_FILE}" "select id from '${DB_TABLE}' order by id asc limit 1;")
last=$(sqlite3 "${DB_FILE}" "select max(${first}, id - ${NUM_LINES_TO_KEEP}) from '${DB_TABLE}' order by id desc limit 1;")
lines_to_delete=$(($last - $first))
lines_deleted=$((0))
time_at_start=$(date +%s)

for i in $(seq $first $DELETE_BATCH_SIZE $last; echo $last); do

    echo -n "Deleting rows ${i}/${last}"
    until sqlite3 "${DB_FILE}" "delete from '${DB_TABLE}' where id <= $i;" 2>/dev/null ; do
        # Print out a dot if the DB is locked, then retry
        echo -n "."
    done

    # Output estimated completion time
    lines_deleted=$(($lines_deleted + $DELETE_BATCH_SIZE))
    lines_to_delete=$(($lines_to_delete - $DELETE_BATCH_SIZE))
    time_now=$(date +%s)
    finished_at=$(echo "select $time_now + 1.0 * $lines_to_delete * ($time_now - $time_at_start) / $lines_deleted;" | sqlite3)
    echo -n ". Estimated completion at "
    echo $finished_at | awk '{print strftime("%c", $0)}'

done

echo -n "Done!"
remaining=sqlite3 "${DB_FILE}" "select count(id) from '${DB_TABLE}';" 
echo " ${remaining} lines in ${DB_TABLE} remain."

