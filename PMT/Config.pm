use strict;
use lib qw(.);
package PMT::Config;

use XML::Simple;
my $config = undef;
my $CONFIG_FILE = "config/settings.xml";

if (-e "config/local.xml") {
    $CONFIG_FILE = "config/local.xml";
}

sub new {
    my $pkg = shift;
    if($config) {
        return $config;
    } else {
        $config = XML::Simple::XMLin($CONFIG_FILE);
        return $config;
    }
}

1;
