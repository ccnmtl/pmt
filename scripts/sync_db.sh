#!/bin/bash


echo "getting new copy of db..."
/usr/bin/ssh anders@www2.ccnmtl pg_dump pmt2 > /tmp/pmt.sql
/usr/bin/ssh anders@www2.ccnmtl pg_dump auth > /tmp/auth.sql



echo "deleting database..."
dropdb pmt2
dropdb auth

echo "creating new database..."
createdb pmt2
createdb auth

echo "loading in new data..."
/usr/bin/psql -d pmt2 -f /tmp/pmt.sql && /bin/rm -f /tmp/pmt.sql
/usr/bin/psql -d auth -f /tmp/auth.sql && /bin/rm -f /tmp/auth.sql


echo "done"
