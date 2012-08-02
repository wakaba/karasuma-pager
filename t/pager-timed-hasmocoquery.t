package test::Karasuma::Pager::Timed::HasMoCoQuery;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::MoreMore::Mock;
use Karasuma::Pager::Timed::HasMoCoQuery;
use DBIx::MoCo::Query;
use DateTime;

sub _date_column : Test(8) {
    my $pager = Karasuma::Pager::Timed::HasMoCoQuery->new;
    is $pager->date_column, 'created_on';
    is $pager->date_method, 'created_on';
    $pager->date_column('created');
    is $pager->date_column, 'created';
    is $pager->date_method, 'created';
    my $item = Test::MoreMore::Mock->new(created => DateTime->now, created_on => DateTime->now->subtract(seconds => 100));
    is $pager->get_time_from_item($item), time;
    $pager->date_method('created_on');
    is $pager->date_column, 'created';
    is $pager->date_method, 'created_on';
    is $pager->get_time_from_item($item), time - 100;
}

sub _reference_time_as_mysql_datetime : Test(2) {
    my $pager = Karasuma::Pager::Timed::HasMoCoQuery->new;
    ng $pager->reference_time_as_mysql_datetime;
    $pager->flush_cached_methods;
    $pager->reference_time(3244353223);
    is $pager->reference_time_as_mysql_datetime, '2072-10-22 09:13:43';
}

sub _window_query_window_item : Test(2) {
    my $query = DBIx::MoCo::Query->new;
    my $pager = Karasuma::Pager::Timed::HasMoCoQuery->new(query => $query);
    isa_ok $pager->window_query, 'DBIx::MoCo::Query';
    isa_list_ok $pager->window_items;
}

sub _window_query_window_item_has_items_preload : Test(3) {
    my $query = DBIx::MoCo::Query->new;
    my $called = 0;
    my $pager = Karasuma::Pager::Timed::HasMoCoQuery->new(query => $query, items_preload => sub { $called++ });
    isa_ok $pager->window_query, 'DBIx::MoCo::Query';
    isa_list_ok $pager->window_items;
    is $called, 1;
}

{
    package test::object::filter;
    
    sub new {
        my $class = shift;
        return bless {called => 0}, $class;
    }

    sub filter {
        $_[0]->{called}++;
    }
}

sub _window_query_window_item_has_items_preload_object : Test(3) {
    my $query = DBIx::MoCo::Query->new;
    my $obj = test::object::filter->new;
    my $pager = Karasuma::Pager::Timed::HasMoCoQuery->new(query => $query, items_preload => {object => $obj, method => 'filter'});
    isa_ok $pager->window_query, 'DBIx::MoCo::Query';
    isa_list_ok $pager->window_items;
    is $obj->{called}, 1;
}

sub _window_query_window_item_has_items_preload_object_removed : Test(2) {
    my $query = DBIx::MoCo::Query->new;
    my $pager = Karasuma::Pager::Timed::HasMoCoQuery->new(query => $query, items_preload => {object => undef, method => 'filter'});
    isa_ok $pager->window_query, 'DBIx::MoCo::Query';
    isa_list_ok $pager->window_items;
}

__PACKAGE__->runtests;

1;
