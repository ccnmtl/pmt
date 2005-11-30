def run_unit_tests(pusher):
    codir = pusher.checkout_dir()
    (out,err) = pusher.execute("pushd %s && ./test.pl && popd" % codir)
    return ("All tests successful." in out, out, err)

def post_rsync(pusher):
    """ we need to kick apache1 to get it to pick up the changes """
    (out,err) = pusher.execute(["ssh","frink.ccnmtl.columbia.edu","sudo","/etc/init.d/apache2","restart"])
    return (True,out,err)
