use lib qw(..);
package PMT::Document;
use PMT::Common;
use base 'CDBI::DBI';
use PMT::User;
use PMT::Project;

__PACKAGE__->table('documents');
__PACKAGE__->sequence('documents_did_seq');
__PACKAGE__->columns(All => qw/did pid filename title type url description
version author last_mod/);
__PACKAGE__->has_a(pid => 'PMT::Project');
__PACKAGE__->has_a(author => 'PMT::User');

my %content_types = (html => 'text/html',
                     txt => 'text/plain',
                     xml => 'text/xml',
                     doc => 'application/vnd.ms-word',
                     xls => 'application/vnd.ms-excel',
                     pdf => 'application/pdf',
                     gif => 'image/gif',
                     jpg => 'image/jpg',
                     png => 'image/png');

sub data {
    my $self = shift;
    return {
        did => $self->did, pid => $self->pid->pid, filename =>
        $self->filename, title => $self->title, type => $self->type, url =>
        $self->url, description => $self->description, version =>
        $self->version, author => $self->author->username, last_mod =>
        $self->last_mod,
    };
}

sub content_type {
    my $self = shift;
    return $content_types{$self->type};
}

sub content_disposition {
    my $self = shift;
    my %dispositions = (html => 0,
                        txt => 0,
                        jpg => 0,
                        gif => 0,
                        png => 0,
                        doc => 1,
                        xls => 1,
                        xml => 1,
                        pdf => 1);
    return $dispositions{$self->type};
}

sub contents {
    my $self = shift;
    
    my $repository = $self->config->{document_repository};
    my $did = $self->did;
    my $type = $self->type;
    my $filename = "$repository/$did.$type";
    open(FILE,$filename)
        or throw Error::Simple "couldn't read document: $!";
    my $data = join '', <FILE>;
    close FILE;
    return $data;
}

sub add_document {
    my $self = shift;
    my %params = @_;
    my $type = "";
    my $config = new PMT::Config();

    if($params{filename}) {
        # uploaded file
        
        # make sure it is a valid type
        if($params{filename} =~ /\.(\w{3,4})$/ ) {
            my $ext = lc($1);
            if (exists $content_types{$ext}) {
                $type = $ext;
            } else {
                throw Error::Simple "not a legal filetype";
            }
        } else {
            throw Error::Simple 
                "file does not have a legal extension.";
        }
    } else {
        # url
        $type = "url";
        if($params{url} =~ m!^http://$!) {
            throw Error::Simple "no url or file specified";
        }
    }
    my $project = PMT::Project->retrieve($params{pid});
    my $author = PMT::User->retrieve($params{author});

    my $filename = $params{filename};
    my $title = $params{title};
    my $url = $params{url};
    my $description = $params{description};
    my $version = $params{version};
    my $doc = PMT::Document->create({pid => $project, author => $author, filename =>
        "$filename", title => $title, type => $type, url=>
        $url, description => $description, version =>
        $version});
    
    my $did = $doc->did;

    # if it's a file, we write it to the repository
    if($type ne "url") {
        my $repository = $config->{document_repository};
        my $filename = "$repository/$did.$type";
        if ($filename =~ m{^([\/\w\.]+)$}) {
            $filename = $1;
        }
        open(FILE,">$filename") 
            or throw Error::Simple "couldn't write to document repository: $!";
        my $fh = $params{fh};
        while(<$fh>) {
            print FILE $_;
        }
        close FILE
            or throw Error::Simple "couldn't close file: $!";
    }
#    $doc->dbi_commit();
    return $did;
}


1;
