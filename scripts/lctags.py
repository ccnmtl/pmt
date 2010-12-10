#!/usr/bin/python
import simplejson
from pprint import pprint
import urllib2
from restclient import GET, POST, DELETE


BASE_URL = "http://tasty.ccnmtl.columbia.edu/service/pmt/"

def has_uppers(s):
    return s.lower() != s

def fix_tag(tag):
    original = urllib2.quote(tag)
    fixed = original.lower()
    print "fixing %s -> %s" % (original,fixed)
    try:
        d = simplejson.loads(GET(BASE_URL + "tag/" + original))
        for ui in d['user_items']:
            (user,item) = (ui[0]['user'], ui[1]['item'])
            url = BASE_URL + "tag/" + original + "/user/" + user + "/item/" + item + "/"
            DELETE(BASE_URL + "tag/" + original + "/user/" + user + "/item/" + item + "/", async=False)
            POST(BASE_URL + "tag/" + fixed + "/user/" + user + "/item/" + item + "/", async=False)
            print "   %s,%s" % (user,item)
        for u in d['users']:
            user = u['user']
            DELETE(BASE_URL + "tag/" + original + "/user/" + user, async=False)            
            POST(BASE_URL + "tag/" + fixed + "/user/" + user, async=False)            
            print "   %s" % user 
        for i in d['items']:
            item = i['item']
            DELETE(BASE_URL + "tag/" + original + "/item/" + user, async=False)            
            POST(BASE_URL + "tag/" + fixed + "/item/" + item, async=False)            
            print "   %s" % item
    except Exception, e:
        print "!!!!!! Exception !!!!!!"
        print str(e)

if __name__ == "__main__":
    d = simplejson.loads(urllib2.urlopen(BASE_URL + "cloud/").read())

    for t in d['tags']:
        if has_uppers(t['tag']):
            fix_tag(t['tag'])
