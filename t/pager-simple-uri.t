package test::Karasuma::Pager::Simple::URI;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use List::Rubyish;
use Karasuma::Pager::Simple::URI;

sub _type : Test(4) {
    my $pager = Karasuma::Pager::Simple::URI->new;
    ok $pager->is_finite_list;
    ng $pager->is_query_offset;
    ng $pager->is_calendar;
    ng $pager->is_timed;
}

sub _pager : Tests(40) {
    my $l = List::Rubyish->new([1..18]);
    my $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
    );
    is $p->page, 1;
    is $p->per_page, 10;
    is $p->next, "/hoge?moge=toge&page=2";
    ng $p->prev;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [1..10];
    is $p->count, 18;
    ng $p->has_prev;
    ok $p->has_next;
    is $p->total_pages, 2;

    $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
        page      => 2
    );
    is $p->page, 2;
    is $p->per_page, 10;
    is $p->prev, "/hoge?moge=toge&page=1";
    ng $p->next;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [11..18];
    is $p->count, 18;
    ok $p->has_prev;
    ng $p->has_next;
    is $p->total_pages, 2;

    $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
        page      => 3
    );
    is $p->page, 3;
    is $p->per_page, 10;
    is $p->prev, "/hoge?moge=toge&page=2";
    ng $p->next;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [];
    is $p->count, 18;
    ok $p->has_prev;
    ng $p->has_next;
    is $p->total_pages, 2;

    $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
        page      => 4
    );
    is $p->page, 4;
    is $p->per_page, 10;
    is $p->prev, "/hoge?moge=toge&page=3";
    ng $p->next;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [];
    is $p->count, 18;
    ok $p->has_prev;
    ng $p->has_next;
    is $p->total_pages, 2;
}

sub _missing : Test(10) {
    my $p = Karasuma::Pager::Simple::URI->new;
    is $p->page, 1;
    is $p->per_page, 10;
    ng $p->prev;
    ng $p->next;
    ng $p->all_items;
    eq_or_diff $p->items->to_a, [];
    is $p->count, 0;
    ng $p->has_prev;
    ng $p->has_next;
    is $p->total_pages, 1;
}

sub _empty : Test(10) {
    my $l = List::Rubyish->new;
    my $p = Karasuma::Pager::Simple::URI->new(all_items => $l);
    is $p->page, 1;
    is $p->per_page, 10;
    ng $p->prev;
    ng $p->next;
    eq_or_diff $p->all_items->to_a, [];
    eq_or_diff $p->items->to_a, [];
    is $p->count, 0;
    ng $p->has_prev;
    ng $p->has_next;
    is $p->total_pages, 1;
}

sub _invalid_page : Test(10) {
    my $l = List::Rubyish->new([1..18]);
    my $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
        page      => 'abcdefg',
    );
    is $p->page, 1;
    is $p->per_page, 10;
    is $p->next, "/hoge?moge=toge&page=2";
    ng $p->prev;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [1..10];
    is $p->count, 18;
    ng $p->has_prev;
    ok $p->has_next;
    is $p->total_pages, 2;
}

sub _negative_page : Test(10) {
    my $l = List::Rubyish->new([1..18]);
    my $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
        page      => -3
    );
    is $p->page, 1;
    is $p->per_page, 10;
    is $p->next, "/hoge?moge=toge&page=2";
    ng $p->prev;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [1..10];
    is $p->count, 18;
    ng $p->has_prev;
    ok $p->has_next;
    is $p->total_pages, 2;
}

sub _non_integer_page : Test(10) {
    my $l = List::Rubyish->new([1..18]);
    my $p = Karasuma::Pager::Simple::URI->new(
        all_items => $l,
        uri       => "/hoge?moge=toge",
        page      => 3.4
    );
    is $p->page, 1;
    is $p->per_page, 10;
    is $p->next, "/hoge?moge=toge&page=2";
    ng $p->prev;
    eq_or_diff $p->all_items->to_a, [1..18];
    eq_or_diff $p->items->to_a, [1..10];
    is $p->count, 18;
    ng $p->has_prev;
    ok $p->has_next;
    is $p->total_pages, 2;
}

__PACKAGE__->runtests;

1;
