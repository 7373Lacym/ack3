#!perl -T

use strict;
use warnings;

use lib 't';
use Util;

use Cwd qw(realpath);
use File::Spec;
use File::Temp;
use Test::Builder;
use Test::More;

use App::Ack::ConfigFinder;

my $tmpdir = $ENV{'TMPDIR'};
my $home   = $ENV{'HOME'};

for ( $tmpdir, $home ) {
    s{/$}{} if defined;
}

if ( $tmpdir && ($tmpdir =~ /^\Q$home/) ) {
    plan skip_all => "Your \$TMPDIR ($tmpdir) is set to a descendant directory of your home directory.  This test is known to fail with such a setting.  Please set your TMPDIR to something else to get this test to pass.";
    exit;
}

plan tests => 13;

# Set HOME to a known value, so we get predictable results.
local $ENV{HOME} = realpath('t/home');

# Clear the user's ACKRC so it doesn't throw out expect_ackrcs().
delete $ENV{'ACKRC'};

my $finder;
my @global_files;

if ( is_windows() ) {
    require Win32;

    @global_files = map { +{ path => File::Spec->catfile($_, 'ackrc') } } (
        Win32::GetFolderPath(Win32::CSIDL_COMMON_APPDATA()),
        Win32::GetFolderPath(Win32::CSIDL_APPDATA()),
    );
}
else {
    @global_files = (
        { path => '/etc/ackrc' },
    );
}

if ( is_windows() || is_cygwin() ) {
    set_up_globals( @global_files );
}

my @std_files = (@global_files, { path => File::Spec->catfile($ENV{'HOME'}, '.ackrc') });

my $wd      = getcwd_clean();
my $tempdir = File::Temp->newdir;
_chdir( $tempdir->dirname );

$finder = App::Ack::ConfigFinder->new;
expect_ackrcs( \@std_files, 'having no project file should return only the top level files' );

no_home( sub {
    expect_ackrcs( \@global_files, 'only system-wide ackrc is returned if HOME is not defined with no project files' );
} );

_mkdir( 'foo' );
_mkdir( File::Spec->catdir('foo', 'bar') );
_mkdir( File::Spec->catdir('foo', 'bar', 'baz') );
_chdir( File::Spec->catdir('foo', 'bar', 'baz') );


my $child_file  = File::Spec->rel2abs( '.ackrc' );
my $parent_file = File::Spec->catfile( $tempdir->dirname, 'foo', 'bar', '.ackrc' );

subtest 'A project file in the same directory should be detected' => sub {
    plan tests => 2;

    touch_ackrc( '.ackrc' );

    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $child_file } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $child_file } ] ) } );

    _unlink( '.ackrc' );
};


subtest 'A project file in the parent directory should be detected' => sub {
    plan tests => 2;

    touch_ackrc( $parent_file );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $parent_file } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $parent_file } ] ) } );
    _unlink( $parent_file );
};


my $grandparent_file = File::Spec->catfile($tempdir->dirname, 'foo', '.ackrc');
subtest 'A project in the grandparent directory should be detected' => sub {
    plan tests => 2;

    touch_ackrc( $grandparent_file );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $grandparent_file } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $grandparent_file } ] ) } );
};


subtest 'A project file in the same directory should be detected, even with another one above it' => sub {
    plan tests => 2;

    touch_ackrc( '.ackrc' );

    my $currdir_ackrc = File::Spec->rel2abs( '.ackrc' );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $currdir_ackrc } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $currdir_ackrc } ] ) } );

    _unlink( '.ackrc' );
    _unlink( $grandparent_file );
};


subtest 'A project file in the same directory should be detected' => sub {
    plan tests => 2;

    touch_ackrc( '_ackrc' );
    my $currdir_ackrc = File::Spec->rel2abs( '_ackrc' );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $currdir_ackrc } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $currdir_ackrc } ] ) } );

    _unlink( '_ackrc' );
};


my $project_file = File::Spec->catfile($tempdir->dirname, 'foo', '_ackrc');
subtest 'A project file in the grandparent directory should be detected' => sub {
    plan tests => 2;

    touch_ackrc( $project_file );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $project_file } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $project_file } ] ) } );
};


subtest 'A project file in the same directory should be detected, even with another one above it' => sub {
    plan tests => 2;

    touch_ackrc( '_ackrc' );
    my $currdir_ackrc = File::Spec->rel2abs( '_ackrc' );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $currdir_ackrc } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $currdir_ackrc } ] ) } );

    _unlink( $project_file );
};


touch_ackrc( '.ackrc' );

subtest '.ackrc + _ackrc is an error' => sub {
    plan tests => 4;

    my $sub = sub {
        my $ok = eval { $finder->find_config_files };
        my $err = $@;
        ok( !$ok, '.ackrc + _ackrc is error' );
        like( $err, qr/\Qcontains both .ackrc and _ackrc/, 'Got the expected error' );
    };
    with_home( $sub );
    no_home(   $sub );
};


_unlink( '.ackrc' );
subtest 'A lower-level _ackrc should be preferred to a higher-level .ackrc' => sub {
    plan tests => 2;

    my $project_file = File::Spec->catfile($tempdir->dirname, 'foo', '.ackrc');
    touch_ackrc( $project_file );
    my $currdir_ackrc = File::Spec->rel2abs( '_ackrc' );
    with_home( sub { expect_ackrcs( [ @std_files,    { project => 1, path => $currdir_ackrc } ] ) } );
    no_home(   sub { expect_ackrcs( [ @global_files, { project => 1, path => $currdir_ackrc } ] ) } );

    _unlink( '_ackrc' );
};


subtest 'Do not load the same ackrc file twice' => sub {
    plan tests => 1;

    local $ENV{'HOME'} = File::Spec->catdir($tempdir->dirname, 'foo');

    my $user_file = File::Spec->catfile($tempdir->dirname, 'foo', '.ackrc');
    touch_ackrc( $user_file );

    expect_ackrcs( [ @global_files, { path => $user_file } ], q{Don't load the same ackrc file twice} );
    _unlink( $user_file );
};


subtest 'Hierarchical testing' => sub {
    plan tests => 3;

    _chdir( $tempdir->dirname );
    local $ENV{'HOME'} = File::Spec->catfile($tempdir->dirname, 'foo');

    my $user_file = File::Spec->catfile($ENV{'HOME'}, '.ackrc');
    touch_ackrc( $user_file );

    my $ackrc = create_tempfile();
    local $ENV{'ACKRC'} = $ackrc->filename;

    expect_ackrcs( [ @global_files, { path => $ackrc->filename } ], q{ACKRC overrides user's HOME ackrc} );
    _unlink( $ackrc->filename );

    expect_ackrcs( [ @global_files, { path => $user_file } ], q{ACKRC doesn't override if it doesn't exist} );

    touch_ackrc( $ackrc->filename );
    _chdir( 'foo' );
    expect_ackrcs( [ @global_files, { path => $ackrc->filename}, { project => 1, path => $user_file } ], q{~/.ackrc should still be found as a project ackrc} );
    _unlink( $ackrc->filename );
};

_chdir( $wd );
clean_up_globals();

exit 0;


sub touch_ackrc {
    my $filename = shift or die;
    write_file( $filename, () );

    return;
}


sub no_home {
    my ( $fn ) = @_;

    # We have to manually store the value of HOME because localized
    # delete isn't supported until Perl 5.12.0.
    my $home_saved = delete $ENV{HOME};
    $fn->();
    $ENV{HOME} = $home_saved;

    return;
}

# For parity with no_home
sub with_home {
    my ( $fn ) = @_;

    $fn->();

    return;
}

sub expect_ackrcs {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $expected = shift;
    my $name     = shift;

    my @got      = $finder->find_config_files;
    my @expected = @{$expected};

    foreach my $element (@got, @expected) {
        $element->{'path'} = realpath($element->{'path'});
    }
    is_deeply( \@got, \@expected, $name ) or diag(explain(\@got));

    return;
}


{
# The tests blow up on Windows if the global files don't exist,
# so here we create them if they don't, keeping track of the ones
# we make so we can delete them later.
my @created_globals;

sub set_up_globals {
    my (@files) = @_;

    foreach my $path (@files) {
        my $filename = $path->{path};
        if ( not -e $filename ) {
            touch_ackrc( $filename );
            push @created_globals, $path;
        }
    }

    return;
}

sub clean_up_globals {
    foreach my $path (@created_globals) {
        unlink $path->{path} or warn "Couldn't unlink $path: $!";
    }

    return;
}

}


sub _chdir {
    my $dir = shift;

    chdir $dir or die "Can't chdir to $dir: $!";

    return;
}


sub _mkdir {
    my $dir = shift;

    mkdir $dir or die "Can't create $dir: $!";

    return;
}


sub _unlink {
    my $dir = shift;

    unlink $dir or die "Can't unlink $dir: $!";

    return;
}
