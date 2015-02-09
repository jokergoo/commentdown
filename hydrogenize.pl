#!/bin/perl/bin/

BEGIN {
    use File::Basename;
    unshift(@INC, dirname($0)."/lib");
}

use strict;
use R::Hydrogen;

my $package = shift;

R::Hydrogen->hydrogenize("$package");
