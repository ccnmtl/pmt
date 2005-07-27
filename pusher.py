def post_rsync(pusher):
    """ we need to kick apache1 to get it to pick up the changes """
    (out,err) = pusher.execute(["ssh","frink.ccnmtl.columbia.edu","sudo","/etc/init.d/apache","restart"])
    return (True,out,err)
