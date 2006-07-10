#!/usr/bin/env python

import psycopg, sys

conn = psycopg.connect("dbname=pmt2")
cursor = conn.cursor()

for name in sys.argv[1:]:
    print name
    cursor.execute("select username,status from users where upper(fullname) = upper('%s');" % name)
    res = cursor.fetchall()
    try:
        status = res[0][1]
        username = res[0][0]
    except IndexError:
        print "user %s doesn't seem to exist" % name
        continue
    cursor.execute("select pid,name from projects where caretaker = '%s';" % username)
    no_projects = 1
    for (pid,project) in cursor.fetchall():
        print "project %d: %s" % (pid,project)
        no_projects = 0

    if no_projects == 1:
        cursor.execute("""update users set status = 'inactive' where username
        = '%s';""" % username)

conn.commit()
