#!/usr/bin/env python
import psycopg2, urllib, httplib
from pprint import pprint
from simplejson import loads

dbconn = psycopg2.connect("dbname=pmt2")
cursor = dbconn.cursor()

json = open("ccnmtl_staff.js").read()
userdata = loads(json)

q = "update users set bio = %s, building=%s, campus=%s, phone=%s, room=%s, title=%s, " \
    " photo_url = %s, photo_width = 80, photo_height = 80, type='Staff' where upper(email) = upper(%s);"
for u in userdata['items']:
    cursor.execute(q,(u['bio'],u['building'],u['campus'],u['phone'],u['room'],
                      u['title'], u['imageURL'],u['email']))
    print "did ", u['label'] 

dbconn.commit()

