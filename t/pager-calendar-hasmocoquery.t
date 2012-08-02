package test::Karasuma::Pager::Calendar::HasMoCoQuery;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::ForkTimeline;
use Test::MoreMore;
use Karasuma::Pager::Calendar::HasMoCoQuery;
use DBIx::MoCo::Query;
use SQL::Abstract;

{
    package test::MyLocale;
    use base qw(Test::MoreMore::Mock);

    sub tz {
        return $_[0]->{override_tz} || 'UTC';
    }

    sub in_local_tz {
        my $self = shift;
        my $dt = shift->clone;

        $dt->set_time_zone('UTC') if $dt->time_zone->name eq 'floating';
        $dt->set_time_zone($self->tz);
        return $dt;
    }
}

stop_time;

sub _date_as_where : Test(2) {
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04');
    eq_or_diff $pager->date_as_where, {-and => [
        {created_on => {'>=', '2010-01-04 00:00:00'}},
        {created_on => {'<=', '2010-01-04 23:59:59'}},
    ]};

    my ($stmt, @bind) = SQL::Abstract->new->select('table', ['*'], $pager->date_as_where, []);
    eq_or_diff [$stmt, @bind], [
        'SELECT * FROM table WHERE ( ( created_on >= ? AND created_on <= ? ) )',
        '2010-01-04 00:00:00',
        '2010-01-04 23:59:59',
    ];
}

sub _date_as_where_tz : Test(2) {
    my $locale = test::MyLocale->new(override_tz => 'Asia/Tokyo');
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04', locale => $locale);
    eq_or_diff $pager->date_as_where, {-and => [
        {created_on => {'>=', '2010-01-03 15:00:00'}},
        {created_on => {'<=', '2010-01-04 14:59:59'}},
    ]};

    my ($stmt, @bind) = SQL::Abstract->new->select('table', ['*'], $pager->date_as_where, []);
    eq_or_diff [$stmt, @bind], [
        'SELECT * FROM table WHERE ( ( created_on >= ? AND created_on <= ? ) )',
        '2010-01-03 15:00:00',
        '2010-01-04 14:59:59',
    ];
}

sub _date_as_where_month : Test(2) {
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04');
    eq_or_diff $pager->date_as_where_month, {-and => [
        {created_on => {'>=', '2010-01-01 00:00:00'}},
        {created_on => {'<=', '2010-01-31 23:59:59'}},
    ]};

    my ($stmt, @bind) = SQL::Abstract->new->select('table', ['*'], $pager->date_as_where_month, []);
    eq_or_diff [$stmt, @bind], [
        'SELECT * FROM table WHERE ( ( created_on >= ? AND created_on <= ? ) )',
        '2010-01-01 00:00:00',
        '2010-01-31 23:59:59',
    ];
}

sub _date_as_where_month_tz : Test(2) {
    my $locale = test::MyLocale->new(override_tz => 'Asia/Tokyo');
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04', locale => $locale);
    eq_or_diff $pager->date_as_where_month, {-and => [
        {created_on => {'>=', '2009-12-31 15:00:00'}},
        {created_on => {'<=', '2010-01-31 14:59:59'}},
    ]};

    my ($stmt, @bind) = SQL::Abstract->new->select('table', ['*'], $pager->date_as_where_month, []);
    eq_or_diff [$stmt, @bind], [
        'SELECT * FROM table WHERE ( ( created_on >= ? AND created_on <= ? ) )',
        '2009-12-31 15:00:00',
        '2010-01-31 14:59:59',
    ];
}

sub _modify_query_empty : Test(2) {
    my $q = DBIx::MoCo::Query->new;
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04');
    my $q2 = $pager->modify_query($q);
    is $q2, $q;
    eq_or_diff $q2->where, [
        '( created_on >= ? AND created_on <= ? )',
        '2010-01-04 00:00:00',
        '2010-01-04 23:59:59',
    ];
}

sub _modify_query_nonempty : Test(2) {
    my $q = DBIx::MoCo::Query->new(where => {foo => 'bar', created_on => '12345'});
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04');
    my $q2 = $pager->modify_query($q);
    is $q2, $q;
    eq_or_diff $q2->where, [
        '( created_on = ? AND foo = ? ) AND ( created_on >= ? AND created_on <= ? )',
        '12345',
        'bar',
        '2010-01-04 00:00:00',
        '2010-01-04 23:59:59',
    ];
}

sub _has_data_in_day : Test(3) {
    my $query = $DBIx::MoCo::Query::Null;
    my $pager = Karasuma::Pager::Calendar::HasMoCoQuery->new(date => '2010-01-04', query => $query);
    ng $pager->has_data_in_day;
    ng $pager->has_data_in_day(1);
    ng $pager->has_data_in_day(10);
}

__PACKAGE__->runtests;

1;
