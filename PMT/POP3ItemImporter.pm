use lib qw(..);
package PMT::POP3ItemImporter;
use Mail::POP3Client;
use PMT::Common;
use PMT::Config;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    $self->{cursor} = 0;
    bless ($self, $class);
    return $self;
}

sub connect {
    my $self = shift;
    my $config = new PMT::Config;
    $self->{client} = new Mail::POP3Client(USER     => $config->{importer_pop3_user},
                                           PASSWORD => $config->{importer_pop3_password},
                                           HOST     => $config->{importer_pop3_host},
                                           USESSL   => $config->{importer_pop3_usessl},
                                           DEBUG    => 1);
    return $self->{client}->Count() >= 0 ? 1 : 0;
}

sub next {
    my $self = shift;
    my $from;
    my $subject;
    my $body;
    if ($self->{cursor} < $self->{client}->Count()) {
        $self->{cursor}++;
        foreach ($self->{client}->Head($self->{cursor})) {
            if ($_ =~ /^From:\s+(.*)/i) {
                $from = $1;
            }
            if ($_ =~ /^Subject:\s+(.*)/i) {
                $subject = $1;
            }
        }
        # Further refine $from to just email address, if possible
        if ($from =~ /([a-zA-Z0-9._+-]+@[a-zA-Z0-9._-]+)/) {
            $from = $1;
        }
        $body = $self->{client}->Body($self->{cursor});
        $self->{client}->Delete($self->{cursor});
        return {from => $from,
                subject => $subject,
                body => $body,
                delivery_method => 'Email'};
    }
}

sub reset {
    my $self = shift;
    $self->{cursor} = 0;
}

sub close {
    my $self = shift;
    $self->{client}->Close();
}

#
# Tries to open a connection and reads through From/Subject headers
#
sub test_connection {
    my $self = shift;
    for( $i = 1; $i <= $self->{client}->Count(); $i++ ) {
        foreach( $self->{client}->Head( $i ) ) {
            /^(From|Subject):\s+/i && print $_, "\n";
        }
    }
}

sub test_next {
    my $self = shift;
    my $num_test_messages = shift;
    if ($self->{cursor} < $num_test_messages) {
        $self->{cursor}++;
        my @unique = (map { ("a".."z")[rand 26] } 1..6);
        return {from => 'ah1352@nyu.edu.xyz', 
                subject => "Case @unique",
                body => "@unique ... some body text",
                delivery_method => 'Email'};
                
    }
}
1;