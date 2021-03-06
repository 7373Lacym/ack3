package App::Ack::Filter::Default;

=head1 NAME

App::Ack::Filter::Default

=head1 DESCRIPTION

The class that implements the filter that ack uses by
default if you don't specify any filters on the command line.

=cut

use strict;
use warnings;
use parent 'App::Ack::Filter';

sub new {
    my ( $class ) = @_;

    return bless {}, $class;
}

sub filter {
    my ( $self, $file ) = @_;

    return -T $file->name;
}

1;
