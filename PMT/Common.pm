use strict;
package PMT::Common;
require Exporter;
@PMT::Common::ISA = qw(Exporter);
@PMT::Common::EXPORT = qw(interval_to_hours make_classes
			  untaint_date untaint_ascii 
			  untaint_ascii_with_default
			  untaint_w untaint_w_with_default
			  untaint_iid untaint_pid untaint_keyword
			  untaint_username untaint_password
			  untaint_mid untaint_sort untaint_status
			  untaint_d untaint_d_with_default
			  paragraphize selectify escape template
                          todays_date scale_array
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
    
    if($interval =~ /(\d\d):(\d\d)/) {
	$hours = $1;
	$minutes = $2;
    } 
    if ($interval =~ /^(\d+)\sday(s\s+\d\d:\d\d)?/) {
	$days = $1;
    }
    $hours = ($days * 24) + $hours + ($minutes/60);
    $hours =~ s/\.(\d\d)\d*/.$1/g;
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
# {{{ untaint_keyword

sub untaint_keyword {
    my $keyword = shift;
    return untaint_ascii($keyword);
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
    elsif ($len == 1)	# just to be complete...
    { $n = ord ($str); }
    else
    { die "bad value [$str] for XmlUtf8Decode"; }

    $hex ? sprintf ("&#x%x;", $n) : "&#$n;";
}

# }}}

sub template {
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


1;
