# -*- Mode: cperl; coding: utf-8; cperl-indent-level: 2 -*-
#!perl -w

use strict;

use Test::More tests => 76;
use IO::Handle;

use CGI::Carp;
use Cwd;

#-----------------------------------------------------------------------------
# Test id
#-----------------------------------------------------------------------------

# directly invoked
my $expect_f = __FILE__;
my $expect_l = __LINE__ + 1;
my ($file, $line, $id) = CGI::Carp::id(0);
is($file, $expect_f, "file");
is($line, $expect_l, "line");
is($id, "carp.t", "id");

# one level of indirection
sub id1 { my $level = shift; return CGI::Carp::id($level); };

$expect_l = __LINE__ + 1;
($file, $line, $id) = id1(1);
is($file, $expect_f, "file");
is($line, $expect_l, "line");
is($id, "carp.t", "id");

# two levels of indirection
sub id2 { my $level = shift; return id1($level); };

$expect_l = __LINE__ + 1;
($file, $line, $id) = id2(2);
is($file, $expect_f, "file");
is($line, $expect_l, "line");
is($id, "carp.t", "id");

#-----------------------------------------------------------------------------
# Test stamp
#-----------------------------------------------------------------------------

my $stamp = "/^\\[
      ([a-z]{3}\\s){2}\\s?
      [\\s\\d:]+
      \\]\\s$id:/ix";

like(CGI::Carp::stamp(),
     $stamp,
     "Time in correct format");

sub stamp1 {return CGI::Carp::stamp()};
sub stamp2 {return stamp1()};

like(stamp2(), $stamp, "Time in correct format");

$CGI::Carp::FULL_PATH = 1;
# really should test the full path here, but platform differnces
# will make the regexp hideous. this may well fail if anything
# using it chdirs into t/ so using Cwd to dry to catch this
my $cwd = getcwd;
if ( $cwd !~ /t$/ ) {
	unlike(stamp2(), $stamp, "Time in correct format (FULL_PATH)");
} else {
	pass( "Can't run FULL_PATH test when cwd is t/" );
}
$CGI::Carp::FULL_PATH = 0;

#-----------------------------------------------------------------------------
# Test warn and _warn
#-----------------------------------------------------------------------------

# set some variables to control what's going on.
$CGI::Carp::WARN = 0;
$CGI::Carp::EMIT_WARNINGS = 0;
my $q_file = quotemeta($file);


# Test that realwarn is called
{
  local $^W = 0;
  ok( CGI::Carp::realwarn( "foo" ),'realwarn' );
  eval "sub CGI::Carp::realwarn {return 'Called realwarn'};";
}

$expect_l = __LINE__ + 1;
is(CGI::Carp::warn("There is a problem"),
   "Called realwarn",
   "CGI::Carp::warn calls CORE::warn");

# Test that message is constructed correctly
eval 'sub CGI::Carp::realwarn {my $mess = shift; return $mess};';

$expect_l = __LINE__ + 1;
like(CGI::Carp::warn("There is a problem"),
   "/] $id: There is a problem at $q_file line $expect_l.".'$/',
   "CGI::Carp::warn builds correct message");

# Test that _warn is called at the correct time
$CGI::Carp::WARN = 1;

my $warn_expect_l = $expect_l = __LINE__ + 1;
like(CGI::Carp::warn("There is a problem"),
   "/] $id: There is a problem at $q_file line $expect_l.".'$/',
   "CGI::Carp::warn builds correct message");

# Test $NO_TIMESTAMP
{
    local $CGI::Carp::NO_TIMESTAMP = 1;
    $expect_l = __LINE__ + 1;
    like(CGI::Carp::warn("There is a problem"),
        qr/\A\Q$id: There is a problem at $file line $expect_l.\E\s*\z/,
        "noTimestamp");

    local $CGI::Carp::NO_TIMESTAMP = 0;
    $expect_l = __LINE__ + 2;
    import CGI::Carp 'noTimestamp';
    like(CGI::Carp::warn("There is a problem"),
        qr/\A\Q$id: There is a problem at $file line $expect_l.\E\s*\z/,
        "noTimestamp");
}

#-----------------------------------------------------------------------------
# Test ineval
#-----------------------------------------------------------------------------

ok(!CGI::Carp::ineval, 'ineval returns false when not in eval');
eval {ok(CGI::Carp::ineval, 'ineval returns true when in eval');};

#-----------------------------------------------------------------------------
# Test die
#-----------------------------------------------------------------------------

# set some variables to control what's going on.
$CGI::Carp::WRAP = 0;

$expect_l = __LINE__ + 1;
eval { CGI::Carp::die('There is a problem'); };
like($@,
     '/^There is a problem/',
     'CGI::Carp::die calls CORE::die without altering argument in eval');

# Test that realwarn is called
{
  local $^W = 0;
  local *CGI::Carp::realdie = sub { my $mess = shift; return $mess };

    like(CGI::Carp::die('There is a problem'),
        $stamp,
        'CGI::Carp::die calls CORE::die, but adds stamp');

}

#-----------------------------------------------------------------------------
# Test set_message
#-----------------------------------------------------------------------------

is(CGI::Carp::set_message('My new Message'),
   'My new Message',
   'CGI::Carp::set_message returns new message');

is($CGI::Carp::CUSTOM_MSG,
   'My new Message',
   'CGI::Carp::set_message message set correctly');

# set the message back to the empty string so that the tests later
# work properly.
CGI::Carp::set_message(''),

#-----------------------------------------------------------------------------
# Test set_progname
#-----------------------------------------------------------------------------

import CGI::Carp qw(name=new_progname);
is($CGI::Carp::PROGNAME,
     'new_progname',
     'CGI::Carp::import set program name correctly');

is(CGI::Carp::set_progname('newer_progname'),
   'newer_progname',
   'CGI::Carp::set_progname returns new program name');

is($CGI::Carp::PROGNAME,
   'newer_progname',
   'CGI::Carp::set_progname program name set correctly');

# set the message back to the empty string so that the tests later
# work properly.
is (CGI::Carp::set_progname(undef),undef,"CGI::Carp::set_progname returns unset name correctly");
is ($CGI::Carp::PROGNAME,undef,"CGI::Carp::set_progname program name unset correctly");

#-----------------------------------------------------------------------------
# Test warnings_to_browser
#-----------------------------------------------------------------------------

CGI::Carp::warningsToBrowser(0);
is($CGI::Carp::EMIT_WARNINGS, 0, "Warnings turned off");

# turn off STDOUT (prevents spurious warnings to screen
tie *STDOUT, 'StoreStuff' or die "Can't tie STDOUT";
CGI::Carp::warningsToBrowser(1);
my $fake_out = join '', <STDOUT>;
untie *STDOUT;

open(STDOUT, ">&REAL_STDOUT");
my $fname = $0;
$fname =~ tr/<>-/\253\273\255/; # _warn does this so we have to also
is( $fake_out, "<!-- warning: There is a problem at $fname line $warn_expect_l. -->\n",
                        'warningsToBrowser() on' );

is($CGI::Carp::EMIT_WARNINGS, 1, "Warnings turned off");

#-----------------------------------------------------------------------------
# Test fatals_to_browser
#-----------------------------------------------------------------------------

package StoreStuff;

sub TIEHANDLE {
  my $class = shift;
  bless [], $class;
}

sub PRINT {
  my $self = shift;
  push @$self, @_;
}

sub READLINE {
  my $self = shift;
  shift @$self;
}

package main;

tie *STDOUT, "StoreStuff";

# do tests
my @result;

CGI::Carp::fatalsToBrowser();
$result[0] .= $_ while (<STDOUT>);

CGI::Carp::fatalsToBrowser('Message to the world');
$result[1] .= $_ while (<STDOUT>);

$ENV{SERVER_ADMIN} = 'foo@bar.com';
CGI::Carp::fatalsToBrowser();
$result[2] .= $_ while (<STDOUT>);

CGI::Carp::set_message('Override the message passed in'),

CGI::Carp::fatalsToBrowser('Message to the world');
$result[3] .= $_ while (<STDOUT>);

CGI::Carp::set_message(sub {print 'Override message with callback'}),
CGI::Carp::fatalsToBrowser('Message to the world');
$result[4] .= $_ while (<STDOUT>);

CGI::Carp::set_message(''),
delete $ENV{SERVER_ADMIN};

# now restore STDOUT
untie *STDOUT;


like($result[0],
     '/Content-type: text/html/',
     "Default string has header");

ok($result[0] !~ /Message to the world/, "Custom message not in default string");

like($result[1],
    '/Message to the world/',
    "Custom Message appears in output");

ok($result[0] !~ /foo\@bar.com/, "Server Admin does not appear in default message");

like($result[2],
    '/foo@bar.com/',
    "Server Admin appears in output");

like($result[3],
     '/Message to the world/',
     "Custom message not in result");

like($result[3],
     '/Override the message passed in/',
     "Correct message in string");

like($result[4],
     '/Override message with callback/',
     "Correct message in string");

#-----------------------------------------------------------------------------
# Test to_filehandle
#-----------------------------------------------------------------------------

sub buffer {
  CGI::Carp::to_filehandle (@_);
}

tie *STORE, "StoreStuff";

require FileHandle;
my $fh = FileHandle->new;

ok( defined buffer(\*STORE),       '\*STORE returns proper filehandle');
ok( defined buffer( $fh ),         '$fh returns proper filehandle');
ok( defined buffer('::STDOUT'),    'STDIN returns proper filehandle');
ok( defined buffer(*main::STDOUT), 'STDIN returns proper filehandle');
ok(!defined buffer("WIBBLE"),      '"WIBBLE" doesn\'t returns proper filehandle');

# Calling die with code refs with no WRAP
{
    local $CGI::Carp::WRAP = 0;

    eval { CGI::Carp::die( 'regular string' ) };
    like $@ => qr/regular string/, 'die with string';

    eval { CGI::Carp::die( [ 1..10 ] ) };
    like $@ => qr/ARRAY\(0x[\da-f]+\)/, 'die with array ref';

    eval { CGI::Carp::die( { a => 1 } ) };
    like $@ => qr/HASH\(0x[\da-f]+\)/, 'die with hash ref';

    eval { CGI::Carp::die( sub { 'Farewell' } ) };
    like $@ => qr/CODE\(0x[\da-f]+\)/, 'die with code ref';

    eval { CGI::Carp::die( My::Plain::Object->new ) };
    isa_ok $@, 'My::Plain::Object';

    eval { CGI::Carp::die( My::Plain::Object->new, ' and another argument' ) };
    like $@ => qr/My::Plain::Object/,     'object is stringified';
    like $@ => qr/and another argument/, 'second argument is present';

    eval { CGI::Carp::die( My::Stringified::Object->new ) };
    isa_ok $@, 'My::Stringified::Object';

    eval { CGI::Carp::die( My::Stringified::Object->new, ' and another argument' ) };
    like $@ => qr/stringified/,          'object is stringified';
    like $@ => qr/and another argument/, 'second argument is present';

    eval { CGI::Carp::die() };
    like $@ => qr/Died at/, 'die with no argument';
}

# Calling die with code refs when WRAPped
{
    local $CGI::Carp::WRAP = 1;
    local *CGI::Carp::realdie = sub { return @_ };
    local *STDOUT;

    tie *STDOUT, 'StoreStuff';

    my %result;   # store results because stdout is kidnapped

    CGI::Carp::die( 'regular string' );
    $result{string} .= $_ while <STDOUT>;

    CGI::Carp::die( [ 1..10 ] );
    $result{array_ref} .= $_ while <STDOUT>;

    CGI::Carp::die( { a => 1 } );
    $result{hash_ref} .= $_ while <STDOUT>;

    CGI::Carp::die( sub { 'Farewell' } );
    $result{code_ref} .= $_ while <STDOUT>;

    CGI::Carp::die( My::Plain::Object->new );
    $result{plain_object} .= $_ while <STDOUT>;

    CGI::Carp::die( My::Stringified::Object->new );
    $result{string_object} .= $_ while <STDOUT>;

    undef $@;
    CGI::Carp::die();
    $result{no_args} .= $_ while <STDOUT>;

    $@ = "I think I caught a virus";
    CGI::Carp::die();
    $result{propagated} .= $_ while <STDOUT>;

    untie *STDOUT;

    like $result{string}    => qr/regular string/, 'regular string, wrapped';
    like $result{array_ref} => qr/ARRAY\(\w+?\)/,  'array ref, wrapped';
    like $result{hash_ref}  => qr/HASH\(\w+?\)/,   'hash ref, wrapped';
    like $result{code_ref}  => qr/CODE\(\w+?\)/,   'code ref, wrapped';
    like $result{plain_object} => qr/My::Plain::Object/,
      'plain object, wrapped';
    like $result{string_object} => qr/stringified/,
      'stringified object, wrapped';
    like $result{no_args} => qr/Died at/, 'no args, wrapped';

    like $result{propagated} => qr/I think I caught a virus\t\.{3}propagated/, 
        'propagating $@ if no argument';

}

{
    package My::Plain::Object;

    sub new {
        return bless {}, shift;
    }
}

{
    package My::Stringified::Object;

    use overload '""' => sub { 'stringified' };

    sub new {
        return bless {}, shift;
    }
}


@result = ();
tie *STDOUT, 'StoreStuff' or die "Can't tie STDOUT";
 {
 	eval {
 		$CGI::Carp::TO_BROWSER = 0;
 		die 'Message ToBrowser = 0';
	};
 	$result[0] = $@;
 	$result[1] .= $_ while (<STDOUT>);
 }
untie *STDOUT;

 like $result[0] => qr/Message ToBrowser/, 'die message for ToBrowser = 0 is OK';
 ok !$result[1], 'No output for ToBrowser = 0';

*CGI::Carp::die = sub { &$CGI::Carp::DIE_HANDLER; return 1 };
*CGI::Carp::warn = sub { return 1 };

CGI::Carp::set_die_handler( sub { pass( "die handler" ); return 1 } );
ok( CGI::Carp::confess(),'confess' );
ok( CGI::Carp::croak(),'croak' );
ok( CGI::Carp::carp(),'carp' );
ok( CGI::Carp::cluck(),'cluck' );

use File::Temp;
my $fh = File::Temp->new;

ok( CGI::Carp::carpout( $fh ),'carpout' );

# mod_perl nonsense
$ENV{MOD_PERL} = 2;
$ENV{MOD_PERL_API_VERSION} = 2;
$ENV{HTTP_USER_AGENT} = "MSIE";

use FindBin qw/ $Bin /;
use lib $Bin;

CGI::Carp::fatalsToBrowser();
like($ENV{MOD_PERL_PRINTED},
     qr/Software error/,
     "fatalsToBrowser with mod_perl 2");

$ENV{MOD_PERL} = 1;
$ENV{MOD_PERL_API_VERSION} = 1;
$ENV{MOD_PERL_PRINTED} = undef;

use FindBin qw/ $Bin /;
use lib $Bin;

require Apache;
CGI::Carp::fatalsToBrowser();
ok( length( $ENV{MOD_PERL_PRINTED} ) > 512,'MSIE error length hack' );
like($ENV{MOD_PERL_PRINTED},
     qr/Software error/,
     "fatalsToBrowser with mod_perl 1");
