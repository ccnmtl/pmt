#!/usr/bin/env python
import psycopg2, hashlib, random
import string

dbconn = psycopg2.connect("dbname=pmt2")
cursor = dbconn.cursor()

# table type fix
q = """alter table users alter column password type varchar(256);"""
cursor.execute(q)

cursor = dbconn.cursor()
q = """SELECT username,password from users;"""
cursor.execute(q)

def salt():
    salt_chars = string.ascii_lowercase + string.digits
    return random.choice(salt_chars) + \
        random.choice(salt_chars) + \
        random.choice(salt_chars) + \
        random.choice(salt_chars) + \
        random.choice(salt_chars)

new_passwords = []
for (username,password) in cursor.fetchall():
    print username, password
    s = salt()
    full = s + password
    hashed = "sha1$" + s + "$" + hashlib.sha1(full).hexdigest()
    new_passwords.append((username,hashed))

cursor = dbconn.cursor()
q = """update users set password = %s where username = %s;"""
for (username,hashed) in new_passwords:
    cursor.execute(q,(hashed,username))
    print "changed password for %s",username

dbconn.commit()
