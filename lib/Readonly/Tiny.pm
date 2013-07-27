package Readonly::Tiny;

=head1 NAME

Readonly::Tiny - Simple, correct readonly values

=cut

use 5.008;
use warnings;
use strict;

our $VERSION = "0";

use Exporter "import";
our @EXPORT = qw/readonly/;
our @EXPORT_OK = qw/readonly readwrite Readonly/;

use Carp            qw/croak/;
use Scalar::Util    qw/reftype refaddr blessed/;
#use Data::Dump      qw/pp/;

sub debug { 
    #warn sprintf "%s [%x] %s\n", @_;
}

sub _recurse;

sub readonly    { _recurse 1, @_; $_[0] }
sub readwrite   { _recurse 0, @_; $_[0] }

sub _recurse {
    my ($ro, $r, $o) = @_;

    my $x = refaddr $r
        or croak "readonly needs a reference";

    exists $o->{skip}{$x}       and return $r;
    $o->{skip}{$x} = 1;

    blessed $r && !$o->{peek}   and return $r;

    my $t = reftype $r;
    #debug $t, $x, pp $r;

    # It's not clear it's meaningful to SvREADONLY these types. A qr//
    # is a ref to a REGEXP, so a scalar holding one can be made
    # readonly; the REGEXP itself would normally be skipped anyway
    # because it's blessed.
    $t eq "CODE" || $t eq "IO" || $t eq "FORMAT" || $t eq "REGEXP"
        and return $r;

    unless ($o->{shallow}) {
        if ($t eq "REF") {
            _recurse $ro, $$r, $o;
        }
        if ($t eq "ARRAY") {
            _recurse $ro, \$_, $o for @$r;
        }
        if ($t eq "HASH") {
            &Internals::SvREADONLY($r, 0);
            _recurse $ro, \$_, $o for values %$r;
            Internals::hv_clear_placeholders(%$r);
        }
        if ($t eq "GLOB") {
            *$r{$_} and _recurse $ro, *$r{$_}, $o 
                for qw/SCALAR ARRAY HASH/;
        }
    }

    # bleeding prototypes...
    &Internals::SvREADONLY($r, $ro);
    #debug "READONLY", $r, &Internals::SvREADONLY($r);
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

=head1 BUGS

Please report bugs to <L<bug-Readonly-Tiny@rt.cpan.org>>.

=head1 AUTHOR

Copyright 2012 Ben Morrow <ben@morrow.me.uk>.

Released under the 2-clause BSD licence.

