use strict;
package PMT::Common;
require Exporter;
@PMT::Common::ISA = qw(Exporter);
@PMT::Common::EXPORT = qw(interval_to_hours make_classes
                          untaint_date untaint_ascii
                          untaint_ascii_with_default
                          untaint_w untaint_w_with_default
                          untaint_iid untaint_pid
                          untaint_username untaint_password
                          untaint_mid untaint_sort untaint_status
                          untaint_d untaint_d_with_default
                          paragraphize selectify escape get_template
                          todays_date scale_array ld diff diff_order
                          lists_diff truncate_string tasty_get
                          tasty_delete tasty_put ldap_lookup dehtml
                          redirect_with_cookie
                          );

sub scale_array {
    my $max = shift;
    my $r = shift;
    my @a = @$r;
    my $total = 0;
    foreach my $i (@a) { $i ||= 0; $total += $i; }
    if ($total == 0) { $total = 1; }
    my $scale = $max / $total;
    return [map {$_ * $scale} @a];
}


# {{{ interval_to_hours
sub interval_to_hours {
    my $interval = shift;

    return 0 unless $interval;

    my ($days,$hours,$minutes) = (0,0,0);

    # handle "HHH:MM" or "HHH:MM:SS" (in the latter, seconds are just ignored)
    if($interval =~ /^(\d+):(\d\d)/) {
        $hours = $1;
        $minutes = $2;
    }
    # handle "DD days HH:MM" or "D day HH:MM"
    if ($interval =~ /^(\d+)\sday(s)?\s+(\d+):(\d\d)/) {
        $days = $1;
        # $2 is the optional (s) in "day(s)"
        $hours = $3;
        $minutes = $4;
    }
    $hours = ($days * 24) + $hours + ($minutes/60);

    $hours =~ s/\.(\d\d)(\d)\d*/.$1/g;
    if($2 > 4) { $hours += 0.01; }   # round
    return $hours;
}
# }}}
# {{{ make_classes

sub make_classes {
    my $r = shift;
    my %classes = ('bug' => "bug",
                   'action item' => "actionitem");
    # using map just cause i can
    return [map {$$_{type_class} = $classes{$$_{type}};$_;} @$r];
}

# }}}
# {{{ untaint_date

sub untaint_date {
    my $date = shift;

    eval {
        $date = untaint_ascii($date);
        throw Error::INVALID_DATE
            unless $date =~ /^\d{4}-\d{1,2}-\d{1,2}$/;
    };
    if ($@) {
        throw Error::INVALID_DATE "invalid or nonexistant date";
    }
    return $date;
}

# }}}
# {{{ untaint_ascii

sub untaint_ascii {
    my $text = shift;

    $text ||= "";
    $text =~ s/\0//g;
    if($text =~ /([[:ascii:]]+)/) {
        $text = $1;
    } else {
        throw Error::NO_TEXT "text contained no valid ascii characters";
    }
    return $text;
}

# }}}
# {{{ untaint_ascii_with_default

sub untaint_ascii_with_default {
    my ($text, $default) = @_;

    eval {
        $text = untaint_ascii($text);
    };
    if($@) {
        my $E = $@;
        if($E->isa('Error::NO_TEXT')) {
            $text = $default;
        } else {
            throw $E;
        }
    }
    return $text;
}

# }}}
# {{{ untaint_username

sub untaint_username {
    my $username = shift;
    eval {
        $username = untaint_w($username);
    };
    if ($@) {
        my $E = $@;
        if($E->isa('Error::NO_TEXT')) {
            throw Error::NO_USERNAME "username: '$username' is not valid";
        } else {
            throw Error::INVALID_USERNAME "bad username";
        }
    } else {
        return untaint_w($username);
    }
}

# }}}
# {{{ untaint_password

sub untaint_password {
    my $password = shift;
    eval {
        $password = untaint_ascii($password);
    };
    if($@) {
        my $E = $@;
        if($E->isa('Error::NO_TEXT')) {
            throw Error::NO_PASSWORD "no password was specified";
        } else {
            throw Error::AUTHENTICATION_FAILURE "error in password";
        }
    }
    return $password;
}

# }}}
# {{{ untaint_sort

sub untaint_sort {
    my $sortby = shift;
    return untaint_w_with_default($sortby,"priority");
}

# }}}
# {{{ untaint_iid

sub untaint_iid {
    my $iid = shift;

    eval {
        $iid = untaint_d($iid);
    };
    if ($@) {
        throw Error::NO_IID "invalid or nonexistant item id";
    }
    return $iid;
}

# }}}
# {{{ untaint_pid
sub untaint_pid {
    my $pid = shift;

    eval {
        $pid = untaint_d($pid);
    };
    if ($@) {
        throw Error::NO_PID "invalid or nonexistant project id";
    }
    return $pid;
}
# }}}
# {{{ untaint_mid
sub untaint_mid {
    my $mid = shift;

    eval {
        $mid = untaint_d($mid);
    };
    if ($@) {
        throw Error::NO_MID "invalid or nonexistant milestone id";
    }
    return $mid;
}
# }}}

# {{{ untaint_status

sub untaint_status {
    my $status = shift;
    eval {
        $status = untaint_w($status);
    };
    if ($@) {
        throw Error::NO_STATUS "invalid or nonexistant status";
    } else {
        return $status;
    }
}

# }}}
# {{{ untaint_w_with_default

sub untaint_w_with_default {
    my ($text, $default) = @_;
    eval {
        $text = untaint_w($text);
    };
    if($@) {
        my $E = $@;
        if ($E->isa('Error::NO_TEXT')) {
            $text = $default;
        } else {
            throw $E;
        }
    }
    return $text;
}

# }}}
# {{{ untaint_w

sub untaint_w {
    my $text = shift || "";
    if($text =~ /(\w+)/) {
        $text = $1;
    } else {
        throw Error::NO_TEXT "text contained no valid characters";
    }
    return $text;
}

# }}}
# {{{ untaint_d_with_default

sub untaint_d_with_default {
    my ($text, $default) = @_;
    eval {
        $text = untaint_d($text);
    };
    if($@) {
        my $E = $@;
        if($E->isa('Error::NO_TEXT')) {
            $text = $default;
        } else {
            throw $E;
        }
    }
    return $text;
}

# }}}
# {{{ untaint_d

sub untaint_d {
    my ($this, $text) = @_;
    $text ||= "";
    if($text =~ /(\d+)/) {
        $text = $1;
    } else {
        throw Error::NO_TEXT "text contained no digits";
    }
    return $text;
}

# }}}

# {{{ paragraphize

# takes text that someone entered in a textarea
# and converts it to html that should be fairly
# close to what they intended it to look like.

sub paragraphize {
    my $text = shift || "";


    # normalize line endings
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;

    $text =~ s{</p>\s*<p>}{\n\n}gs;
    $text =~ s{</?p>}{}g;
    $text =~ s{<br />}{\n}g;

    my @pars = split /\n{2,}/, $text;

    $text = "";
    foreach my $par (@pars) {
        next if $par =~ /^\s*$/;
        $par =~ s{\n}{<br />}g;
        $text .= "<p>$par</p>\n";
    }
    return $text;
}
# }}}

sub selectify {
    my $values = shift;
    my $labels = shift;
    my $selected = shift;
    my %selected = map {$_ => 1} @{$selected};

    return [map {
        {
            value => $_,
            label => shift @{$labels},
            selected => $selected{$_} || "",
        }
    } @{$values}];
}

# {{{ escape

# escapes higher ascii characters. as xml entities.
# allows researches to just copy and paste in multilingual
# text.
sub escape {
    my $text = shift || "";

    $text = safe_encode($text);

    # deal with stupid "smart" quotes and other MS nonsense
    $text =~ s/(\&\#147;|\&\#148;)/"/g; #"
    $text =~ s/(\&\#145;|\&\#146;)/'/g; #'
    $text =~ s/(\&\#8220;|\&\#8221;)/"/g; #"
    $text =~ s/(\&\#8212;)/--/g;
    $text =~ s/(\&\#8216;|\&\#8217;)/'/g; #'
    $text =~ s/(\&\#8230;)/.../g;

    $text =~ s/\&\#150;/-/g;
    $text =~ s/\&\#151;/--/g;

    $text =~ s/<([^\w\/])/&lt;$1/g;
    $text =~ s/\s>(\s*)/ &gt;$1/g;

    return $text;
}

# }}}
# {{{ safe_encode

sub safe_encode {
    my $str = shift || "";
    $str =~ s{([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...)}
    {XmlUtf8Decode ($1)}egs;
    return $str;
  }

# }}}
# {{{ XmlUtf8Decode

sub XmlUtf8Decode
  { my ($str, $hex) = @_;
    my $len = length ($str);
    my $n;

    if ($len == 2)
      { my @n = unpack "C2", $str;
        $n = (($n[0] & 0x3f) << 6) + ($n[1] & 0x3f);
      }
    elsif ($len == 3)
    { my @n = unpack "C3", $str;
      $n = (($n[0] & 0x1f) << 12) + (($n[1] & 0x3f) << 6) + ($n[2] & 0x3f);
    }
    elsif ($len == 4)
    { my @n = unpack "C4", $str;
      $n = (($n[0] & 0x0f) << 18) + (($n[1] & 0x3f) << 12)
         + (($n[2] & 0x3f) << 6) + ($n[3] & 0x3f);
    }
    elsif ($len == 1)   # just to be complete...
    { $n = ord ($str); }
    else
    { die "bad value [$str] for XmlUtf8Decode"; }

    $hex ? sprintf ("&#x%x;", $n) : "&#$n;";
}

# }}}

sub get_template {
    use HTML::Template;
    my $file = shift || throw Error::Simple "no template specified";
    my $template = HTML::Template->new(filename => "templates/$file",
                                       die_on_bad_params => 0,
                                       loop_context_vars => 1);
    return $template;
}

sub todays_date {
    my ($sec,$min,$hour,$mday,$mon,
        $year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    $mon = sprintf "%02d", $mon;
    $mday = sprintf "%02d", $mday;
    return ($year,$mon,$mday);
}

# recursively compares two lists by value
# works for damn near any reasonably complex structure
# including: lists of scalars, lists of lists, lists of hashes,
# lists of hashes of lists of arrays of scalars, etc, etc.
# arguably should be called data_structures_diff
# argument $order == 1 means that we don't care about the order
# ie ['foo','bar'] == ['bar','foo']

sub ld {
    my $x      = shift;       # first element of first list
    my $y      = shift;       # first element of second list
    my $r1     = shift;       # reference to rest of first list
    my $r2     = shift;       # reference to rest of second list
    my $sorted = shift;       # whether or not the lists have been sorted
    my $order  = shift;       # whether we're order agnostic with lists

    my $DIFFERENT = 1;
    my $SAME      = 0;

    my @xs = @$r1;
    my @ys = @$r2;

    if(!$sorted && $order) {
        @xs = sort @xs;
        @ys = sort @ys;
        $sorted = 1;
    }

    if ($#xs != $#ys) {
        # lists are different lengths, so we know right off that
        # they must not be the same.
        return $DIFFERENT;
    } else {

        # lists are the same length, so we compare $x and $y
        # based on what they are
        if (!ref $x) {

            # make sure $y isn't a reference either
            return $DIFFERENT if ref $y;

            # both scalars, compare them
            return $DIFFERENT if $x ne $y;
        } else {

            # we're dealing with references now
            if (ref $x ne ref $y) {

                # they're entirely different data types
                return $DIFFERENT;
            } elsif ("SCALAR" eq ref $x) {

                # some values that we can actually compare
                return $DIFFERENT if $$x ne $$y;
            } elsif ("REF" eq ref $x) {

                # yes, we even handle references to references to references...
                return $DIFFERENT if ld($$x,$$y,[],[],0,$order);
            } elsif ("HASH" eq ref $x) {

                # references to hashes are a little tricky
                # we make arrays of keys and values (keeping
                # the values in order relative to the keys)
                # and compare those.
                my @kx = sort keys %$x;
                my @ky = sort keys %$y;
                my @vx = map {$$x{$_}} @kx;
                my @vy = map {$$y{$_}} @ky;
                return $DIFFERENT
                    if ld("", "", \@kx,\@ky,1,$order) ||
                        ld("", "", \@vx,\@vy,1,$order);
            } elsif ("ARRAY" eq ref $x) {
                return $DIFFERENT if ld("","",$x,$y,0,$order);
            } else {
                # don't know how to compare anything else
                throw Error::UNKNOWN_TYPE "sorry, can't compare type " . ref $x;
            }
        }
        if (-1 == $#xs) {

            # no elements left in list, this is the base case.
            return $SAME;
        } else {
            return ld(shift @xs,shift @ys,\@xs,\@ys,$sorted,$order);
        }

    }
}

sub diff {
    my $r1 = shift;
    my $r2 = shift;
    # ld expects references to lists
    if ("ARRAY" eq ref $r1 && "ARRAY" eq ref $r2) {
        return ld("","",$r1,$r2,0,1);
    } else {
        # if they're not references to lists, we just make them
        return ld("","",[$r1],[$r2],0,1);
    }
}

# same as diff but not order agnostic
# ['foo','bar'] != ['bar','foo']
sub diff_order {
    my $r1 = shift;
    my $r2 = shift;
    # ld expects references to lists
    if ("ARRAY" eq ref $r1 && "ARRAY" eq ref $r2) {
        return ld("","",$r1,$r2,0,0);
    } else {
        # if they're not references to arrays, we just make them
        return ld("","",[$r1],[$r2],0,0);
    }
}

# recursively compares two lists
# works for damn near any reasonably complex structure
# lists of scalars, lists of lists, lists of hashes,
# lists of hashes of lists of arrays of scalars, etc, etc.
# doesn't take order into account.

sub lists_diff {
    my $r1 = shift;
    my $r2 = shift;
    my $DIFFERENT = 1;
    my $SAME = 0;

    # sort things so order isn't taken into account.
    my @l1 = sort @$r1;
    my @l2 = sort @$r2;

    if ($#l1 != $#l2) {
        # lists are different lengths, so we know right off that
        # they must not be the same.
        return $DIFFERENT;
    } else {
        for(my $i = 0; $i <= $#l1; $i++) {
            if (ref $l1[$i] eq ref $l2[$i]) {
                if (ref $l1[$i] eq "SCALAR") {
                    return $DIFFERENT if $l1[$i] ne $l2[$i];
                } elsif (ref $l1[$i] eq "HASH") {
                    return $DIFFERENT
                        if (lists_diff([keys %{$l1[$i]}],
                                       [keys %{$l2[$i]}])
                            == $DIFFERENT ||
                            lists_diff([values %{$l1[$i]}],
                                       [values %{$l2[$i]}])
                            == $DIFFERENT);
                } elsif (ref $l1[$i] eq "ARRAY") {
                    return $DIFFERENT
                        if (lists_diff($l1[$i],$l2[$i]) == $DIFFERENT);
                } else {
                    # don't know how to compare anything else
                }
            } else {
                return $DIFFERENT;
            }
        }
    }
    return $SAME;
}


# extract first x chars of a string
# input 0: string to be truncated
# input 1: max length of string
sub truncate_string {

    my $full_string = shift;
    my $len = shift || 20;
    my $truncated_string;

    #checks for length of title first
    if ( length($full_string) > $len ) {
        $truncated_string = substr($full_string, 0, $len) . "...";
    } else {
        $truncated_string = $full_string;
    }
}

sub ldap_lookup {
    use LWP::Simple;
    use JSON;
    use PMT::Config;
    my $config = new PMT::Config;
    if ($config->{ldap_url}) {
        my $uni = shift;
        my $json = new JSON;
       return $json->jsonToObj(get "http://cdap.ccnmtl.columbia.edu/?uni=$uni");
    }
}

sub tasty_get {
    use LWP::Simple;
    use JSON;
    use PMT::Config;
    my $config = new PMT::Config;
    my $base = $config->{tasty_base};
    my $service = $config->{tasty_service};
    my $url = shift;
    my $full = "http://$base/service/$service/$url";
    my $r = get $full;
    my $json = new JSON;
    eval {
	my $obj = $json->jsonToObj($r);
#    my $obj = $json->decode($r);
	if (!$obj) {
	    $obj = {};
	}
	return $obj;
    };
    if ($@) {
	# tasty didn't return JSON for some reason
	return {};
    }
}

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw(POST);

sub tasty_put {
    my $url = shift;
    my $ua = LWP::UserAgent->new;
    my $config = new PMT::Config;
    my $base = $config->{tasty_base};
    my $service = $config->{tasty_service};
    my $req = POST "http://$base/service/$service/$url", [];
    return $ua->request($req)->as_string;
}

sub tasty_delete {
    my $url = shift;
    my $ua = LWP::UserAgent->new;
    my $config = new PMT::Config;
    my $base = $config->{tasty_base};
    my $service = $config->{tasty_service};
    my $req = HTTP::Request->new(DELETE => "http://$base/service/$service/$url");
    my $res = $ua->request($req);
}

sub get_wiki_url {
    use PMT::Config;
    my $config = new PMT::Config;
    return $config->{wiki_base_url};
}

sub get_uni_domain {
    use PMT::Config;
    my $config = new PMT::Config;
    return $config->{uni_domain};
}

# very quick and dirty approach to switching
# the html that has been submitted in a comment 
# (thanks to wmd.js) from going out in email as html.
# for now it's good enough to just remove the '<p>' tags.

sub dehtml {
    my $string = shift;
    $string =~ s{<p>}{}g;
    $string =~ s{</p>}{}g;
    return $string;
}

sub redirect_with_cookie {
    my $cgi = shift;
    my $url      = shift || throw Error::NO_URL "no url specified in redirect_with_cookie()";
    my $username = shift || "";
    my $password = shift || "";

    my $lcookie = $cgi->cookie(-name => 'pmtusername',
                               -value => $username,
                               -path => '/',
                               -expires => '+10y');
    my $pcookie = $cgi->cookie(-name => 'pmtpassword',
                               -value => $password,
                               -path => '/',
                               -expires => '+10y');
    if($url ne "") {
        print $cgi->redirect(-location => $url,
                             -cookie => [$lcookie,$pcookie]);
    } else {
        print $cgi->header(-cookie => [$lcookie,$pcookie]);
    }
}


1;
