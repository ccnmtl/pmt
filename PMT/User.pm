# File: User.pm
# Time-stamp: <Mon Nov  4 16:33:30 2002>
# Author: anders pearson
use strict;
package PMT::User;
use lib qw(.);
use PMT::Common;
my %PRIORITIES = (4 => 'CRITICAL', 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW',
0 => 'ICING');

my @ATTRIBUTES = qw(username fullname email status grp password);

sub new {
    my $pkg = shift;
    my $username = shift;
    my $self = bless {username => $username,
		      db => new PMT::DB()
		      }, $pkg;
    $self->debug("new($username)");
    $self->_load_data();

    return $self;
}

sub _load_data {
    my $self = shift;
    $self->debug("_load_data()");
    my $sql = qq{select username,fullname,email,status,grp, password
		     from users where username = ?;};
    my $res = $self->ss($sql,[$self->get("username")],[@ATTRIBUTES]);
    foreach my $att (@ATTRIBUTES) {
	$self->{$att} = $res->{$att};
    }
}

sub get {
    my $self = shift;
    my $attribute = shift;
    return undef unless grep {$attribute eq $_} @ATTRIBUTES;
    return $self->{$attribute};
}

sub data {
    my $self = shift;
    my %data;
    foreach my $attr (@ATTRIBUTES) {
	$data{$attr} = $self->get($attr);
    }
    return \%data;
}



# {{{ menu


# }}}





# {{{ delete

# to be used for testing only. not safe in the
# wild.
sub delete {
    my $self = shift;
    $self->warn("delete()");
    $self->update("delete from users where username = ?;",[$self->get("username")]);
}

# }}}


# {{{ db wrappers

sub s {my $self = shift;$self->{db}->s(@_);}
sub ss {my $self = shift;$self->{db}->ss(@_);}
sub update {my $self = shift;$self->{db}->update(@_);}

# }}}
# {{{ log wrappers
sub debug {my $self = shift;}
sub info {my $self = shift;}
sub warn {my $self = shift;}
sub error {my $self = shift;}
# }}}


1;
