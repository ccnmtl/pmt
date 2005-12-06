#!/usr/bin/env python
import psycopg, urllib, httplib

TASTY_BASE = "tasty.ccnmtl.columbia.edu"
SERVICE = "pmt"

def add_tag(keyword,iid,pid,username):
    conn = httplib.HTTPConnection(TASTY_BASE)
    url = "/service/%s/user/user_%s/user/project_%d/item/item_%d/tag/%s/" % \
          (SERVICE,username,pid,iid,keyword)
    conn.request("PUT",url)
    response = conn.getresponse()
    conn.close()


dbconn = psycopg.connect("dbname=pmt2")
cursor = dbconn.cursor()

q = """SELECT k.keyword,k.iid,m.pid,i.owner from keywords k, items i, milestones m
     WHERE k.iid = i.iid AND i.mid = m.mid"""

cursor.execute(q)



for (keyword,iid,pid,username) in cursor.fetchall():
    # skip any that are probably bogus
    if len(keyword) > 32:
        continue
    print keyword,iid,pid,username
    add_tag(keyword,iid,pid,username)


