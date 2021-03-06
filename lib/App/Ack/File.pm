package App::Ack::File;

use App::Ack;

use warnings;
use strict;

=head1 NAME

App::Ack::File

=head1 DESCRIPTION

Abstracts a file from the filesystem.

=head1 METHODS

=head2 new( $filename )

Opens the file specified by I<$filename> and returns a filehandle and
a flag that says whether it could be binary.

If there's a failure, it throws a warning and returns an empty list.

=cut

sub new {
    my $class    = shift;
    my $filename = shift;

    my $self = bless {
        filename => $filename,
        fh       => undef,
        opened   => 0,
    }, $class;

    if ( $self->{filename} eq '-' ) {
        $self->{fh}     = *STDIN;
        $self->{opened} = 1;
    }

    return $self;
}


=head2 $file->name()

Returns the name of the file.

=cut

sub name {
    return $_[0]->{filename};
}


=head2 $file->basename()

Returns the basename (the last component the path)
of the file.

=cut

sub basename {
    my ( $self ) = @_;

    # XXX Definedness? Pre-populate the slot with an undef?
    unless ( exists $self->{basename} ) {
        $self->{basename} = (File::Spec->splitpath($self->name))[2];
    }

    return $self->{basename};
}


=head2 $file->open()

Opens a filehandle for reading this file and returns it, or returns
undef if the operation fails (the error is in C<$!>).  Instead of calling
C<close $fh>, C<$file-E<gt>close> should be called.

=cut

sub open {
    my ( $self ) = @_;

    if ( !$self->{opened} ) {
        if ( open $self->{fh}, '<', $self->{filename} ) {
            $self->{opened} = 1;
        }
        else {
            $self->{fh} = undef;
        }
    }

    return $self->{fh};
}


=head2 $file->needs_line_scan( \%opts )

Tells if the file needs a line-by-line scan.  This is a big
optimization because if you can tell from the outset that the pattern
is not found in the file at all, then there's no need to do the
line-by-line iteration.

Slurp up an entire file up to 100K, see if there are any matches
in it, and if so, let us know so we can iterate over it directly.
If it's bigger than 100K or the match is inverted, we have to do
the line-by-line, too.

=cut

sub needs_line_scan {
    my $self  = shift;
    my $opt   = shift;

    return 1 if $opt->{v};

    my $size = -s $self->{fh};
    if ( $size == 0 ) {
        return 0;
    }
    elsif ( $size > 100_000 ) {
        return 1;
    }

    my $buffer;
    my $rc = sysread( $self->{fh}, $buffer, $size );
    if ( !defined($rc) && $App::Ack::report_bad_filenames ) {
        App::Ack::warn( "$self->{filename}: $!" );
        return 1;
    }
    return 0 unless $rc && ( $rc == $size );

    return $buffer =~ /$opt->{regex}/m;
}


=head2 $file->reset()

Resets the file back to the beginning.  This is only called if
C<needs_line_scan()> is true, but not always if C<needs_line_scan()>
is true.

=cut

sub reset {
    my $self = shift;

    if ( defined($self->{fh}) ) {
        if ( !seek( $self->{fh}, 0, 0 ) && $App::Ack::report_bad_filenames ) {
            App::Ack::warn( "$self->{filename}: $!" );
        }
    }

    return;
}


=head2 $file->close()

Close the file.

=cut

sub close {
    my $self = shift;

    # Return if we haven't opened the file yet.
    if ( !defined($self->{fh}) ) {
        return;
    }

    if ( !close($self->{fh}) && $App::Ack::report_bad_filenames ) {
        App::Ack::warn( $self->name() . ": $!" );
    }

    $self->{opened} = 0;

    return;
}


=head2 $file->clone()

Clones this file.

=cut

sub clone {
    my ( $self ) = @_;

    return __PACKAGE__->new($self->name);
}


=head2 $file->firstliney()

Returns the first line of a file (or first 250 characters, whichever
comes first).

=cut

sub firstliney {
    my ( $self ) = @_;

    if ( !exists $self->{firstliney} ) {
        my $fh = $self->open();
        my $buffer;
        my $rc = sysread( $fh, $buffer, 250 );
        if ( $rc ) {
            $buffer =~ s/[\r\n].*//s;
        }
        else {
            if ( !defined($rc) ) {
                App::Ack::warn( $self->name . ': ' . $! );
            }
            $buffer = '';
        }
        $self->{firstliney} = $buffer;
        $self->reset;
    }

    return $self->{firstliney};
}

1;
