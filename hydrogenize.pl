#!/bin/perl/bin/

BEGIN {
    use File::Basename;
    unshift(@INC, dirname($0)."/lib");
}

use strict;
use R::Hydrogen;

my $path = shift;

R::Hydrogen->hydrogenize("$path");
