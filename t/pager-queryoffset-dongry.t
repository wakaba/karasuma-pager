use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use Test::X1;
use Test::More;
use Karasuma::Pager::QueryOffset::Dongry;

test {
    my $c = shift;
    my $pager = Karasuma::Pager::QueryOffset::Dongry->new;
    isa_ok $pager, 'Karasuma::Pager';
    ok !$pager->is_finite_list;
    ok $pager->is_query_offset;
    ok !$pager->is_calendar;
    ok !$pager->is_timed;
    done $c;
} n => 5;

run_tests;
