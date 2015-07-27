#!/bin/sh

# Turns out SQLite does not like databases with tens of millions lines.
# Especially so when the database file resides on a slow medium, such
# as a CompactFlash card. This script helps clean up a table when the DB
# must not block when doing the cleanup.

set -eu

# File name of database
DB_FILE=/data/avdb
# Table name in database
DB_TABLE=deviceproperty_log
NUM_LINES_TO_KEEP=10000
DELETE_BATCH_SIZE=100

first=$(sqlite3 "${DB_FILE}" "select id from '${DB_TABLE}' order by id asc limit 1;")
last=$(sqlite3 "${DB_FILE}" "select max(1, id - ${NUM_LINES_TO_KEEP}) from '${DB_TABLE}' order by id desc limit 1;")


for i in $(seq $first $DELETE_BATCH_SIZE $last); do

    echo -n "Deleting ${i}/${last}"
    until sqlite3 "${DB_FILE}" "delete from '${DB_TABLE}' where id < $i;" 2>/dev/null ; do
        # Print out a dot if the DB is locked, then retry
        echo -n "."
    done
    echo

done

echo -n "Done!"
remaining=sqlite3 "${DB_FILE}" "select count(id) from '${DB_TABLE}';" 
echo " ${remaining} lines in ${DB_TABLE} remain."

