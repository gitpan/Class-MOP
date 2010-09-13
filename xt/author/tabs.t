#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Test::Requires {
    'Test::NoTabs' => '0.8', # skip all if not installed
};

for my $file ( qw( mop.c mop.h ), glob "xs/*xs" ) {
    notabs_ok( $file, "$file is tab free" );
}

# Module::Install has tabs, so we can't check 'inc' or ideally '.'
all_perl_files_ok('lib', 't', 'xt');
