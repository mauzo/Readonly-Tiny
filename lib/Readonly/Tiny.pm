package Readonly::Tiny;

use 5.008;
use warnings;
use strict;

our $VERSION = "0";

use Exporter "import";
our @EXPORT = qw/readonly/;
our @EXPORT_OK = qw/readonly Readonly/;

use Carp            qw/croak/;
use Scalar::Util    qw/reftype refaddr blessed/;
#use Data::Dump      qw/pp/;

sub debug { 
    #warn sprintf "%s [%x] %s\n", @_;
}

sub readonly;
sub readonly {
    my ($r, $o) = @_;

    my $x = refaddr $r
        or croak "readonly needs a reference";
    $o->{seen}{$x} and return $r;
    $o->{seen}{$x} = 1;

    blessed $r && !$o->{peek}
        and return $r;

    my $t = reftype $r;
    #debug $t, $x, pp $r;

    # it's not clear it's meaningful to SvREADONLY these types
    $t eq "CODE" || $t eq "IO" || $t eq "FORMAT" || $t eq "REGEXP"
        and return $r;

    unless ($o->{shallow}) {
        if ($t eq "REF") {
            readonly $$r, $o;
        }
        if ($t eq "ARRAY") {
            readonly \$_, $o for @$r;
        }
        if ($t eq "HASH") {
            readonly \$_, $o for values %$r;
            Internals::hv_clear_placeholders(%$r);
        }
        if ($t eq "GLOB") {
            *$r{$_} and readonly *$r{$_} 
                for qw/SCALAR ARRAY HASH/;
        }
    }

    # bleeding prototypes...
    &Internals::SvREADONLY($r, 1);
    #debug "READONLY", $r, &Internals::SvREADONLY($r);

    $r;
}

sub Readonly (\[$@%]@) {
    my $r = shift;
    my $t = reftype $r
        or croak "Readonly needs a reference";

    if ($t eq "SCALAR" or $t eq "REF") {
        $$r = $_[0];
    }
    if ($t eq "ARRAY") {
        @$r = @_;
    }
    if ($t eq "HASH") {
        %$r = @_;
    }
    if ($t eq "GLOB") {
        *$r = $_[0];
    }

    readonly $r;
}

1;
