package test::Karasuma::Pager::Role::HasQueryTimedPager;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use DBIx::MoCo::Query;
use Karasuma::URL;
use Test::MoreMore;
use Test::MoreMore::Mock;
use DateTime;

{
    package test::App;
    
    sub new {
        my $class = shift;
        return bless {@_}, $class;
    }

    sub mk_accessors {
        my $class = shift;
        for my $method (@_) {
            eval sprintf q{
                sub %s::%s {
                    if (@_ > 1) {
                        $_[0]->{%s} = $_[1];
                    }
                    return $_[0]->{%s};
                }
                1;
            }, $class, $method, $method, $method or die $@;
        }
    }

    __PACKAGE__->mk_accessors(qw(locale));
}

{
    package test::MyApp1;
    use base qw(Karasuma::Pager::Role::HasQueryTimedPager test::App);
    
    __PACKAGE__->mk_accessors(qw(orig_query date_column date_method));
}

{
    package test::MyQuery::Many;
    use base qw(DBIx::MoCo::Query);
    use List::Rubyish;
    
    sub search {
        my ($self, $offset, $limit) = @_;
        return List::Rubyish->new([1..5000])->slice($offset, $offset + $limit - 1);
    }

    sub count { 5000 }
}

{
    package test::MyApp2;
    use base qw(Karasuma::Pager::Role::HasQueryTimedPager test::App);
    
    __PACKAGE__->mk_accessors(qw(orig_query date_column date_method));

    sub force_offset_pager {
        return 1;
    }
}

{
    package test::MyApp3;
    use base qw(Karasuma::Pager::Role::HasQueryTimedPager test::App);

    __PACKAGE__->mk_accessors(qw(orig_query date_column date_method));

    sub additional_timed_pager_parameters {
        return {
            foo => 'baz',
        }
    }
}

sub _set_pager_params_by_req : Test(6) {
    my $req = Test::MoreMore::Mock->new(
        param => {
            page => 40,
            per_page => 3,
            since => 3553253,
            date => 4554,
            date_delta => -44,
            order => 'asc',
        },
    );
    local *Test::MoreMore::Mock::epoch_param = sub {
        my $self = shift;
        my $name = shift;
        return DateTime->from_epoch(epoch => scalar $self->param($name));
    };
    my $app = test::MyApp1->new;
    $app->set_pager_params_by_req($req);
    is $app->page, 40;
    is $app->per_page, 3;
    is_datetime $app->page_since, '1970-02-11T03:00:53';
    is $app->date, 4554;
    is $app->date_delta, -44;
    is $app->order, 'asc';
}

sub _unpaged_url : Test(3) {
    my $app = test::MyApp1->new;
    is $app->unpaged_url->as_absurl, q</>;
    $app->unpaged_url(Karasuma::URL->new(path => [qw/a b/]));
    is $app->unpaged_url->as_absurl, q{/a/b};
    is $app->filtered_unpaged_url->as_absurl, q{/a/b};
}

sub _no_args_empty : Test(2) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $app = test::MyApp1->new(
        unpaged_url => $u,
    );
    $app->orig_query($DBIx::MoCo::Query::Null);
    isa_list_n_ok $app->items, 0;
    isa_ok $app->pager, 'Karasuma::Pager';
}

sub _no_args_many : Test(1) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        unpaged_url => $u,
    );
    $app->orig_query($q);
    eq_or_diff $app->items->to_a, [1..20];
}

sub _page_many : Test(7) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    {
        my $app = test::MyApp1->new(
            page => 1,
            unpaged_url => $u,
        );
        $app->orig_query($q);
        eq_or_diff $app->items->to_a, [1..20];
        is $app->pager->next, q{/test?page=2};
    }
    
    {
        my $app = test::MyApp1->new(page => 4);
        $app->orig_query($q);
        eq_or_diff $app->items->to_a, [61..80];
    }
    
    {
        my $app = test::MyApp1->new(page => 200);
        $app->orig_query($q);
        eq_or_diff $app->items->to_a, [3981..4000];
    }
    
    {
        my $app = test::MyApp1->new(page => 201);
        $app->orig_query($q);
        eq_or_diff $app->items->to_a, [];
    }
    
    {
        my $app = test::MyApp1->new(page => 101, per_page => 30);
        $app->orig_query($q);
        eq_or_diff $app->items->to_a, [3001..3030];
    }
    
    {
        my $app = test::MyApp1->new(page => 200, device_for_pager => 'mobile');
        $app->orig_query($q);
        eq_or_diff $app->items->to_a, [1991..2000];
    }
}

sub _page_filtered : Test(1) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        unpaged_url => $u,
        page => 3,
        per_page => 4,
        orig_query => $q,
    );
    local *test::MyApp1::item_filter = sub { $_[1] % 2 };
    eq_or_diff $app->items->to_a, [9, 11];
}

sub _page_filtered_preloaded : Test(2) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        unpaged_url => $u,
        page => 3,
        per_page => 4,
        orig_query => $q,
    );
    my $preloaded = {};
    local *test::MyApp1::item_filter = sub { $_[1] % 2 };
    local *test::MyApp1::items_preload = sub { $preloaded->{$_}++ for @{$_[1]} };
    eq_or_diff $app->items->to_a, [9, 11];
    eq_or_diff $preloaded, {9 => 1, 10 => 1, 11 => 1, 12 => 1};
}

sub _date_column : Test(4) {
    my $app = test::MyApp1->new(
        date_column => 'abc',
    );
    is $app->timed_pager->date_column, 'abc';
    is $app->offset_pager->created_on_column, 'abc';
    is $app->calendar_filter->created_on_column, 'abc';
    is $app->timed_pager->date_method, 'abc';
}

sub _date_method : Test(4) {
    my $app = test::MyApp1->new(
        date_column => 'abc',
        date_method => 'xyz',
    );
    is $app->timed_pager->date_column, 'abc';
    is $app->offset_pager->created_on_column, 'abc';
    is $app->calendar_filter->created_on_column, 'abc';
    is $app->timed_pager->date_method, 'xyz';
}

sub _page_since : Test(2) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $dt = DateTime->new(year => 2004, month => 10, day => 4, hour => 4);
    my $app = test::MyApp1->new(
        unpaged_url => $u,
        page_since => $dt,
    );
    is_datetime $app->pager->since, $dt;
    is $app->pager->page_uri, q{/test}; # page_since はつかない
}

sub _reftime : Test(7) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        orig_query => $q,
        unpaged_url => $u,
    );
    my $pager = $app->pager;
    isa_ok $pager, 'Karasuma::Pager::Timed::HasMoCoQuery';
    is $pager->reference_type, 'after';
    is $pager->reference_time, 32333;
    is $pager->reference_offset, 1;
    is $pager->unpaged_url->as_absurl, q{/test};
    is $pager->per_page, 20;
    is $pager->per_window, 100;
}

sub _reftime_per_page : Test(8) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        orig_query => $q,
        unpaged_url => $u,
        per_page => 50,
    );
    my $pager = $app->pager;
    isa_ok $pager, 'Karasuma::Pager::Timed::HasMoCoQuery';
    is $pager->reference_type, 'after';
    is $pager->reference_time, 32333;
    is $pager->reference_offset, 1;
    is $pager->unpaged_url->as_absurl, q{/test};
    is $pager->per_page, 50;
    is $pager->per_window, 250;
    is $pager->order, 'desc';
}

sub _reftime_order : Test(9) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        orig_query => $q,
        unpaged_url => $u,
        order => 'asc',
        has_order => 1,
    );
    my $pager = $app->pager;
    isa_ok $pager, 'Karasuma::Pager::Timed::HasMoCoQuery';
    is $pager->reference_type, 'after';
    is $pager->reference_time, 32333;
    is $pager->reference_offset, 1;
    is $pager->unpaged_url->as_absurl, q{/test?order=asc};
    is $app->filtered_unpaged_url->as_absurl, q{/test?order=asc};
    is $pager->per_page, 20;
    is $pager->per_window, 100;
    is $pager->order, 'asc';
}

sub _reftime_default_order : Test(9) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        orig_query => $q,
        unpaged_url => $u,
    );
    local *test::MyApp1::default_order = sub { 'asc' };
    my $pager = $app->pager;
    isa_ok $pager, 'Karasuma::Pager::Timed::HasMoCoQuery';
    is $pager->reference_type, 'after';
    is $pager->reference_time, 32333;
    is $pager->reference_offset, 1;
    is $pager->unpaged_url->as_absurl, q{/test};
    is $app->filtered_unpaged_url->as_absurl, q{/test};
    is $pager->per_page, 20;
    is $pager->per_window, 100;
    is $pager->order, 'asc';
}

sub _reftime_default_order_desc : Test(9) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        orig_query => $q,
        unpaged_url => $u,
        order => 'desc',
        has_order => 1,
    );
    local *test::MyApp1::default_order = sub { 'asc' };
    my $pager = $app->pager;
    isa_ok $pager, 'Karasuma::Pager::Timed::HasMoCoQuery';
    is $pager->reference_type, 'after';
    is $pager->reference_time, 32333;
    is $pager->reference_offset, 1;
    is $pager->unpaged_url->as_absurl, q{/test?order=desc};
    is $app->filtered_unpaged_url->as_absurl, q{/test?order=desc};
    is $pager->per_page, 20;
    is $pager->per_window, 100;
    is $pager->order, 'desc';
}

sub _reftime_filtered : Test(3) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        unpaged_url => $u,
        per_page => 4,
        orig_query => $q,
        has_per_page => 1,
    );
    local *test::MyApp1::item_filter = sub { $_[1] % 2 };
    eq_or_diff $app->items->to_a, [9, 7, 5, 3];
    my $pager = $app->pager;
    is $pager->unpaged_url->as_absurl, q{/test?per_page=4};
    is $app->filtered_unpaged_url->as_absurl, q{/test?per_page=4};
}

sub _reftime_filtered_preloaded : Test(2) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(
        reftime => '+32333,1',
        unpaged_url => $u,
        per_page => 4,
        orig_query => $q,
    );
    my $preloaded = {};
    local *test::MyApp1::per_window = sub { 8 };
    local *test::MyApp1::item_filter = sub { $_[1] % 2 };
    local *test::MyApp1::items_preload = sub { $preloaded->{$_}++ for @{$_[1]} };
    eq_or_diff $app->items->to_a, [9, 7, 5, 3];
    eq_or_diff $preloaded, {2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1};
}

sub _use_calendar_filter_no : Test(7) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(unpaged_url => $u, orig_query => $q);
    ng $app->use_calendar_filter;
    my $cal = $app->calendar_filter;
    isa_ok $cal, 'Karasuma::Pager::Calendar::HasMoCoQuery';
    is_datetime $cal->date_as_datetime, DateTime->today;
    is $cal->date_level, 'day';
    is $app->filtered_unpaged_url->as_absurl, q</test>;
    my $q2 = $app->query;
    isa_ok $q2, 'DBIx::MoCo::Query';
    is $q2, $q;
}

sub _use_calendar_filter_date : Test(7) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(date => '2001-02-04', unpaged_url => $u, orig_query => $q);
    ok $app->use_calendar_filter;
    my $cal = $app->calendar_filter;
    isa_ok $cal, 'Karasuma::Pager::Calendar::HasMoCoQuery';
    is_datetime $cal->date_as_datetime, '2001-02-04T00:00:00';
    is $cal->date_level, 'day';
    is $app->filtered_unpaged_url->as_absurl, q</test?date=2001-02-04>;
    my $q2 = $app->query;
    isa_ok $q2, 'DBIx::MoCo::Query';
    isnt $q2, $q;
}

sub _use_calendar_filter_date_level_default : Test(7) {
    my $u = Karasuma::URL->new(path => [qw/test/]);
    my $q = test::MyQuery::Many->new;
    my $app = test::MyApp1->new(date_level_default => 'year', unpaged_url => $u, orig_query => $q);
    ok $app->use_calendar_filter;
    my $cal = $app->calendar_filter;
    isa_ok $cal, 'Karasuma::Pager::Calendar::HasMoCoQuery';
    is_datetime $cal->date_as_datetime, DateTime->today;
    is $cal->date_level, 'year';
    is $app->filtered_unpaged_url->as_absurl, q</test?date=2011>;
    my $q2 = $app->query;
    isa_ok $q2, 'DBIx::MoCo::Query';
    isnt $q2, $q;
}

sub _force_offset_pager : Test(2) {
    my $app = test::MyApp2->new;
    ng $app->pager->is_timed;
    ok $app->pager->is_query_offset;
}

sub _additional_timed_pager_parameters : Test(1) {
    my $app = test::MyApp3->new;
    my $pager = $app->timed_pager;
    is $pager->{foo}, 'baz';
}

__PACKAGE__->runtests;

1;
