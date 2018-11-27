#!/bin/perl/bin/

BEGIN {
    use File::Basename;
    unshift(@INC, dirname($0)."/lib");
}

my $cmd = "Rscript ".dirname($0)."/update_pkg_aliases_db.R --output ".dirname($0)."/pkg_aliases_db.json";
system($cmd);

use strict;
use R::Hydrogen;

my $path = shift;

R::Hydrogen->hydrogenize("$path");
