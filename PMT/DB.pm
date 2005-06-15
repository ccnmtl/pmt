use strict;
use lib qw(/home/httpd/html/lib .);
use DB;
use PMT::Config;
package PMT::DB;

my $singleton_db = undef;

# singleton DB class
sub new {
    my $pkg = shift;
    if($singleton_db) {
	return $singleton_db;
    } else {
	my $config = new PMT::Config();
	my $dbh = DBI->connect("DBI:Pg:dbname=$config->{database}",
			       $config->{database_username},
			       $config->{database_password},
			       {RaiseError => 1, AutoCommit => 0});

	my $db = DB->new($dbh);
	my $self = bless {db => $db}, $pkg;
	$singleton_db = $self;
	return $self;
    }
}

# {{{ --- database utility functions

# {{{ s

sub s {
    my $self        = shift;
    return $self->{db}->s(@_);
}

# }}}
# {{{ ss

sub ss {
    my $self        = shift;
    return $self->{db}->ss(@_);
}

# }}}
# {{{ update

sub update {
    my $self = shift;
    return $self->{db}->update(@_);
}

# }}}
sub insert {shift->update(@_);}
sub delete {shift->update(@_);}

# {{{ start_transaction

sub start_transaction {
    my $self = shift;
    $self->{db}->start_transaction();
}

# }}}
# {{{ end_transaction

sub end_transaction {
    my $self = shift;
    $self->{db}->end_transaction();
}

# }}}

# }}}

1;
