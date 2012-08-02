package test::Karasuma::Pager::Calendar::Basic;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::ForkTimeline;
use Test::MoreMore;
use Karasuma::Pager::Calendar::Basic;

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

sub _type : Test(4) {
    my $pager = Karasuma::Pager::Calendar::Basic->new;
    ng $pager->is_finite_list;
    ng $pager->is_query_offset;
    ok $pager->is_calendar;
    ng $pager->is_timed;
}

sub _set_date_level : Test(7) {
    my $pager = Karasuma::Pager::Calendar::Basic->new;

    $pager->set_date_level('day');
    is $pager->date_level, 'day';

    $pager->set_date_level('week');
    is $pager->date_level, 'week';

    $pager->set_date_level('month');
    is $pager->date_level, 'month';
    
    $pager->set_date_level('year');
    is $pager->date_level, 'year';

    $pager->set_date_level;
    is $pager->date_level, 'year';

    $pager->set_date_level('abc');
    is $pager->date_level, 'year';

    $pager->date_as_datetime;

    is $pager->date_level, 'year';
}

sub _date_level_default : Test(3) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(
        date_level_default => 'year',
    );
    $pager->date_as_datetime;
    is $pager->date_level, 'year';
    
    $pager = Karasuma::Pager::Calendar::Basic->new(
        date_level_default => 'month',
    );
    $pager->date_as_datetime;
    is $pager->date_level, 'month';
    
    $pager = Karasuma::Pager::Calendar::Basic->new(
        date_level_default => 'month',
        date => '2020-W04',
    );
    $pager->date_as_datetime;
    is $pager->date_level, 'week';
}

sub __apply_delta_too_large : Test(4) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(
        date_delta => 100000,
        date_level => 'year',
    );
    my $dt = DateTime->new(year => 2001, month => 10, day => 2);
    $pager->_apply_delta($dt);
    is_datetime $dt, DateTime->new(year => 2051, month => 10, day => 2);

    $pager = Karasuma::Pager::Calendar::Basic->new(
        date_delta => 100001,
        date_level => 'month',
    );
    $dt = DateTime->new(year => 2001, month => 10, day => 2);
    $pager->_apply_delta($dt);
    is_datetime $dt, DateTime->new(year => 2051, month => 10, day => 2);

    $pager = Karasuma::Pager::Calendar::Basic->new(
        date_delta => 1000010000,
        date_level => 'second',
    );
    $dt = DateTime->new(year => 2001, month => 10, day => 2);
    $pager->_apply_delta($dt);
    is_datetime $dt, DateTime->new(year => 2001, month => 10, day => 2, hour => 4);

    $pager = Karasuma::Pager::Calendar::Basic->new(
        date_delta => -100000,
        date_level => 'year',
    );
    my $dt = DateTime->new(year => 2001, month => 10, day => 2);
    $pager->_apply_delta($dt);
    is_datetime $dt, DateTime->new(year => 1951, month => 10, day => 2);
}

sub _date_as_datetime : Test(84) {
    my $l1 = test::MyLocale->new(override_tz => 'Asia/Tokyo');
    for (
        [{} => DateTime->today(time_zone => 'UTC'), 'UTC', 'day'],
        [{date => '2010-10-12'} => DateTime->new(
            year => 2010, month => 10, day => 12, time_zone => 'UTC',
        ), 'UTC', 'day'],
        [{date => '2010-W10'} => DateTime->new(
            year => 2010, month => 3, day => 8, time_zone => 'UTC',
        ), 'UTC', 'week'],
        [{date => '2010-10'} => DateTime->new(
            year => 2010, month => 10, day => 1, time_zone => 'UTC',
        ), 'UTC', 'month'],
        [{date => '2010'} => DateTime->new(
            year => 2010, month => 1, day => 1, time_zone => 'UTC',
        ), 'UTC', 'year'],
        [{date => 'invalid'} => DateTime->today(time_zone => 'UTC'), 'UTC', 'day'],
        [{date => '-100001'} => DateTime->today(time_zone => 'UTC'), 'UTC', 'day'],
        [{date => '0900-01-01'} => DateTime->today(time_zone => 'UTC'), 'UTC', 'day'],
        [{date => '2000-01-01T01:01:00Z'} => DateTime->today(time_zone => 'UTC'), 'UTC', 'day'],

        [{locale => $l1} => DateTime->today(time_zone => 'Asia/Tokyo'), 'Asia/Tokyo', 'day'],
        [{locale => $l1, date => '2010-10-12'} => DateTime->new(
            year => 2010, month => 10, day => 12, time_zone => 'Asia/Tokyo',
        ), 'Asia/Tokyo', 'day'],
        [{locale => $l1, date => '2010-W10'} => DateTime->new(
            year => 2010, month => 3, day => 8, time_zone => 'Asia/Tokyo',
        ), 'Asia/Tokyo', 'week'],
        [{locale => $l1, date => '2010-10'} => DateTime->new(
            year => 2010, month => 10, day => 1, time_zone => 'Asia/Tokyo',
        ), 'Asia/Tokyo', 'month'],
        [{locale => $l1, date => '2010'} => DateTime->new(
            year => 2010, month => 1, day => 1, time_zone => 'Asia/Tokyo',
        ), 'Asia/Tokyo', 'year'],
        [{locale => $l1, date => 'invalid'} => DateTime->today(time_zone => 'Asia/Tokyo'), 'Asia/Tokyo', 'day'],

        [{date_delta => 1} => DateTime->today(time_zone => 'UTC')->add(days => 1), 'UTC', 'day'],
        [{date_delta => 1, date => '2010-10-12'} => DateTime->new(
            year => 2010, month => 10, day => 13, time_zone => 'UTC',
        ), 'UTC', 'day'],
        [{date_delta => 1, date => '2010-W10'} => DateTime->new(
            year => 2010, month => 3, day => 15, time_zone => 'UTC',
        ), 'UTC', 'week'],
        [{date_delta => 1, date => '2010-10'} => DateTime->new(
            year => 2010, month => 11, day => 1, time_zone => 'UTC',
        ), 'UTC', 'month'],
        [{date_delta => 1, date => '2010'} => DateTime->new(
            year => 2011, month => 1, day => 1, time_zone => 'UTC',
        ), 'UTC', 'year'],
        [{date_delta => 1, date => 'invalid'} => DateTime->today(time_zone => 'UTC')->add(days => 1), 'UTC', 'day'],

        [{date_delta => -1} => DateTime->today(time_zone => 'UTC')->add(days => -1), 'UTC', 'day'],
        [{date_delta => -1, date => '2010-10-12'} => DateTime->new(
            year => 2010, month => 10, day => 11, time_zone => 'UTC',
        ), 'UTC', 'day'],
        [{date_delta => -1, date => '2010-W10'} => DateTime->new(
            year => 2010, month => 3, day => 1, time_zone => 'UTC',
        ), 'UTC', 'week'],
        [{date_delta => -1, date => '2010-10'} => DateTime->new(
            year => 2010, month => 9, day => 1, time_zone => 'UTC',
        ), 'UTC', 'month'],
        [{date_delta => -1, date => '2010'} => DateTime->new(
            year => 2009, month => 1, day => 1, time_zone => 'UTC',
        ), 'UTC', 'year'],
        [{date_delta => -1, date => 'invalid'} => DateTime->today(time_zone => 'UTC')->add(days => -1), 'UTC', 'day'],

        [{date_delta => 'broken', date => '2010-10-12'} => DateTime->new(
            year => 2010, month => 10, day => 12, time_zone => 'UTC',
        ), 'UTC', 'day'],
    ) {
        my $pager = Karasuma::Pager::Calendar::Basic->new($_->[0]);
        is_datetime $pager->date_as_datetime, $_->[1];
        is $pager->date_as_datetime->time_zone->name, $_->[2];
        is $pager->date_level, $_->[3];
    }
}

sub _older_newer_date_day : Test(10) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-01-02');
    is_datetime $pager->older_date_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 1);
    is_datetime $pager->newer_date_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 3);
    is_datetime $pager->start_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 2, hour => 0, minute => 0, second => 0);
    is_datetime $pager->end_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 2, hour => 23, minute => 59, second => 59);
    my $u1 = $pager->older_url;
    isa_ok $u1, 'Karasuma::URL';
    is $u1->as_absurl, q</?date=2010-01-01>;
    my $u2 = $pager->newer_url;
    isa_ok $u2, 'Karasuma::URL';
    is $u2->as_absurl, q</?date=2010-01-03>;
    my $u3 = $pager->current_url;
    isa_ok $u3, 'Karasuma::URL';
    is $u3->as_absurl, q</?date=2010-01-02>;
}

sub _older_newer_date_week : Test(10) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-W01');
    is_datetime $pager->older_date_as_datetime,
        DateTime->new(year => 2009, month => 12, day => 28);
    is_datetime $pager->newer_date_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 11);
    is_datetime $pager->start_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 4, hour => 0, minute => 0, second => 0);
    is_datetime $pager->end_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 10, hour => 23, minute => 59, second => 59);
    my $u1 = $pager->older_url;
    isa_ok $u1, 'Karasuma::URL';
    is $u1->as_absurl, q</?date=2009-W53>;
    my $u2 = $pager->newer_url;
    isa_ok $u2, 'Karasuma::URL';
    is $u2->as_absurl, q</?date=2010-W02>;
    my $u3 = $pager->current_url;
    isa_ok $u3, 'Karasuma::URL';
    is $u3->as_absurl, q</?date=2010-W01>;
}

sub _older_newer_date_month : Test(14) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-01');
    is_datetime $pager->older_date_as_datetime,
        DateTime->new(year => 2009, month => 12, day => 1);
    is_datetime $pager->newer_date_as_datetime,
        DateTime->new(year => 2010, month => 2, day => 1);
    is_datetime $pager->start_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 1, hour => 0, minute => 0, second => 0);
    is_datetime $pager->end_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 31, hour => 23, minute => 59, second => 59);
    my $u1 = $pager->older_url;
    isa_ok $u1, 'Karasuma::URL';
    is $u1->as_absurl, q</?date=2009-12>;
    my $u2 = $pager->newer_url;
    isa_ok $u2, 'Karasuma::URL';
    is $u2->as_absurl, q</?date=2010-02>;
    my $u3 = $pager->current_url;
    isa_ok $u3, 'Karasuma::URL';
    is $u3->as_absurl, q</?date=2010-01>;
    my $u4 = $pager->older_delta_url;
    isa_ok $u4, 'Karasuma::URL';
    is $u4->as_absurl, q</?date=2010-01&date_delta=-1>;
    my $u5 = $pager->newer_delta_url;
    isa_ok $u5, 'Karasuma::URL';
    is $u5->as_absurl, q</?date=2010-01&date_delta=1>;
}

sub _older_newer_date_year : Test(10) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010');
    is_datetime $pager->older_date_as_datetime,
        DateTime->new(year => 2009, month => 1, day => 1);
    is_datetime $pager->newer_date_as_datetime,
        DateTime->new(year => 2011, month => 1, day => 1);
    is_datetime $pager->start_as_datetime,
        DateTime->new(year => 2010, month => 1, day => 1, hour => 0, minute => 0, second => 0);
    is_datetime $pager->end_as_datetime,
        DateTime->new(year => 2010, month => 12, day => 31, hour => 23, minute => 59, second => 59);
    my $u1 = $pager->older_url;
    isa_ok $u1, 'Karasuma::URL';
    is $u1->as_absurl, q</?date=2009>;
    my $u2 = $pager->newer_url;
    isa_ok $u2, 'Karasuma::URL';
    is $u2->as_absurl, q</?date=2011>;
    my $u3 = $pager->current_url;
    isa_ok $u3, 'Karasuma::URL';
    is $u3->as_absurl, q</?date=2010>;
}

sub _month_calendar : Test(2) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-01');
    is_datetime $pager->month_calendar_datetime, $pager->date_as_datetime;
    eq_or_diff $pager->month_calendar_as_arrayref, [
        [undef, undef, undef, undef, 1, 2, 3],
        [4, 5, 6, 7, 8, 9, 10],
        [11, 12, 13, 14, 15, 16, 17],
        [18, 19, 20, 21, 22, 23, 24],
        [25, 26, 27, 28, 29, 30, 31],
    ];
}

sub _get_relative : Test(5) {
    fork_timeline {
        my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-01-03');
        is $pager->date_level, 'day';
        is $pager->get_relative_day_type(10), 'newer';
        is $pager->get_relative_week_type_by_day(10), 'newer';
        is $pager->get_absolute_day_type(10), 'older';
        is $pager->get_absolute_week_type_by_day(10), 'older';
    } DateTime->new(year => 2010, month => 1, day => 18)->epoch;
}

sub _get_relative_old_month : Test(11) {
    fork_timeline {
        my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-01-03');
        is $pager->date_level, 'day';
        is $pager->get_relative_day_type(10), 'newer';
        is $pager->get_relative_week_type_by_day(10), 'newer';
        is $pager->get_absolute_day_type(10), 'older';
        is $pager->get_absolute_week_type_by_day(10), 'older';
        is $pager->get_absolute_day_type(18), 'older';
        is $pager->get_absolute_week_type_by_day(18), 'older';
        is $pager->get_absolute_day_type(22), 'older';
        is $pager->get_absolute_week_type_by_day(22), 'older';
        $pager->{_date_as_datetime} = DateTime->new(year => 2010, month => 5, day => 18, hour => 3);
        is $pager->get_absolute_day_type(18), 'current';
        is $pager->get_absolute_week_type_by_day(18), 'current';
    } DateTime->new(year => 2010, month => 5, day => 18)->epoch;
}

sub _get_relative_in_month : Test(7) {
    fork_timeline {
        my $pager = Karasuma::Pager::Calendar::Basic->new(date => '2010-05');
        is $pager->date_level, 'month';
        is $pager->get_relative_day_type(10), 'na';
        is $pager->get_relative_week_type_by_day(10), 'na';
        is $pager->get_absolute_day_type(10), 'older';
        is $pager->get_absolute_week_type_by_day(10), 'older';
        is $pager->get_absolute_day_type(20), 'newer';
        is $pager->get_absolute_week_type_by_day(20), 'current';
    } DateTime->new(year => 2010, month => 5, day => 18)->epoch;
}

sub _unpaged_url : Test(3) {
    my $pager = Karasuma::Pager::Calendar::Basic->new;

    my $u1 = $pager->unpaged_url;
    isa_ok $u1, 'Karasuma::URL';

    my $u2 = Karasuma::URL->new(path => [qw/a b/]);
    $pager->unpaged_url($u2);
    my $u3 = $pager->unpaged_url;
    isa_ok $u3, 'Karasuma::URL';
    is $u3->url_path, q[/a/b];
}

sub _get_url_with_date_and_level : Test(11) {
    my $pager = Karasuma::Pager::Calendar::Basic->new;
    
    my $u1 = $pager->get_url_with_date_and_level;
    isa_ok $u1, 'Karasuma::URL';
    
    my $u2 = $pager->get_url_with_date_and_level(DateTime->new(year => 2001, month => 10, day => 3), 'day');
    isa_ok $u2, 'Karasuma::URL';
    is $u2->url_query, q[?date=2001-10-03];
    
    my $u3 = $pager->get_url_with_date_and_level(DateTime->new(year => 2001, month => 10, day => 3), 'week');
    isa_ok $u3, 'Karasuma::URL';
    is $u3->url_query, q[?date=2001-W40];
    
    my $u4 = $pager->get_url_with_date_and_level(DateTime->new(year => 2001, month => 10, day => 3), 'month');
    isa_ok $u4, 'Karasuma::URL';
    is $u4->url_query, q[?date=2001-10];
        
    my $u5 = $pager->get_url_with_date_and_level(DateTime->new(year => 2001, month => 10, day => 3), 'year');
    isa_ok $u5, 'Karasuma::URL';
    is $u5->url_query, q[?date=2001];

    my $locale = test::MyLocale->new(override_tz => 'Asia/Tokyo');
    $pager->locale($locale);
    my $u6 = $pager->get_url_with_date_and_level(DateTime->new(year => 2001, month => 10, day => 3, hour => 23, minute => 3, time_zone => 'UTC'), 'day');
    isa_ok $u6, 'Karasuma::URL';
    is $u6->url_query, q[?date=2001-10-04];
}

sub _day_url_week_url : Test(4) {
    my $pager = Karasuma::Pager::Calendar::Basic->new(
        date => '2010-12-24',
        unpage_url => Karasuma::URL->new,
    );
    is $pager->day_url(3)->as_absurl, q</?date=2010-12-03>;
    is $pager->week_url_by_day(3)->as_absurl, q</?date=2010-W48>;
    is_datetime $pager->date_as_datetime, '2010-12-24T00:00:00';

    my $u2 = Karasuma::URL->new(path => [qw/a b c/]);
    my $u3 = $pager->get_day_qualified_url($u2, 3);
    is $u3->as_absurl, q</a/b/c?date=2010-12-03>;
}

__PACKAGE__->runtests;

1;
