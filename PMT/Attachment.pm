use lib qw(..);
package PMT::Attachment;
use PMT::Common;
use base 'CDBI::DBI';
use PMT::User;
use PMT::Item;

__PACKAGE__->table('attachment');
__PACKAGE__->sequence('attachment_id_seq');
__PACKAGE__->columns(All => qw/id item_id filename title type url description author last_mod/);
__PACKAGE__->has_a(item_id => 'PMT::Item');
__PACKAGE__->has_a(author => 'PMT::User');

my %content_types = (html => 'text/html',
                     txt => 'text/plain',
                     xml => 'text/xml',
                     doc => 'application/vnd.ms-word',
                     xls => 'application/vnd.ms-excel',
                     pdf => 'application/pdf',
                     gif => 'image/gif',
                     jpg => 'image/jpg',
                     png => 'image/png',
		     csv => 'text/csv',
		     zip => 'application/zip',
		     xls => 'application/vnd.ms-excel',
                     mov => 'video/quicktime');

sub data {
    my $self = shift;
    return {
        id => $self->id, iid => $self->item_id->iid, filename =>
        $self->filename, title => $self->title, type => $self->type, url =>
        $self->url, description => $self->description, author => $self->author->username, last_mod =>
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
                        pdf => 1,
			csv => 1,
			xls => 1,
                        mov => 1);
    return $dispositions{$self->type};
}

sub contents {
    my $self = shift;

    my $repository = $self->config->{attachment_repository};
    my $id = $self->id;
    my $type = $self->type;
    my $filename = "$repository/$id.$type";
    open(FILE,$filename)
        or throw Error::Simple "couldn't read attachment: $!";
    my $data = join '', <FILE>;
    close FILE;
    return $data;
}

sub add_attachment {
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
                throw Error::Simple "this file is not an allowed type for attachments";
            }
        } else {
            throw Error::Simple
                "The file must have a correct extension";
        }
    } else {
        # url
        $type = "url";
        if($params{url} =~ m!^http://$!) {
            throw Error::Simple "no url or file specified";
        }
    }
    my $item = PMT::Item->retrieve($params{item_id});
    my $author = PMT::User->retrieve($params{author});

    my $filename = $params{filename};
    my $title = $params{title};
    my $url = $params{url};
    my $description = $params{description};
    my $attachment = PMT::Attachment->create({item_id => $item, author => $author, filename =>
        "$filename", title => $title, type => $type, url=>
        $url, description => $description});

    my $id = $attachment->id;

    # if it's a file, we write it to the repository
    if($type ne "url") {
        my $repository = $config->{attachment_repository};
        my $filename = "$repository/$id.$type";
        if ($filename =~ m{^([\/\w\.]+)$}) {
            $filename = $1;
        }
        open(FILE,">$filename")
            or throw Error::Simple "couldn't write to attachment repository: $!";
        my $fh = $params{fh};
        while(<$fh>) {
            print FILE $_;
        }
        close FILE
            or throw Error::Simple "couldn't close file: $!";
    }

    return $id;
}
