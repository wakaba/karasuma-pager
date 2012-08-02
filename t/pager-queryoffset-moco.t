package test::Karasuma::Pager::QueryOffset::MoCo;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use List::Rubyish;
use DBIx::MoCo::Query;
use Test::MoreMore;
use Test::MoreMore::Mock;

{
    package test::Movie;
    use base qw(Test::MoreMore::Mock);
    
    sub query {
        return 'test::Movie::Query';
    }

    sub movies_query {
        return shift->query;
    }

    my $objects = List::Rubyish->new;
    $objects->push(test::Movie->new) for 0..6;

    sub count {
        return $objects->length;
    }

    package test::Movie::Query;
    use base qw(Test::MoreMore::Mock);
    
    sub search {
        return $objects;
    }

    sub count {
        return $objects->length;
    }

    package test::User;
    use base qw(Test::MoreMore::Mock);

    my $user_objects = List::Rubyish->new;
    $user_objects->push(test::Movie->new) for 1..12;

    sub query {
        return 'test::User::Query';
    }

    sub movies_query {
        return shift->query;
    }

    sub movies {
        return $user_objects;
    }

    package test::User::Query;
    use base qw(Test::MoreMore::Mock);
    
    sub search {
        return $user_objects;
    }

    sub count {
        return $user_objects->length;
    }
}

sub motemen {
    return test::User->new;
}

sub _use : Test(startup => 1) {
    use_ok 'Karasuma::Pager::QueryOffset::MoCo';
}

sub _type : Test(4) {
    my $pager = Karasuma::Pager::QueryOffset::MoCo->new;
    ng $pager->is_finite_list;
    ok $pager->is_query_offset;
    ng $pager->is_calendar;
    ng $pager->is_timed;
}

sub _new : Test(2) {
    my $pager;

    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => DBIx::MoCo::Query->new,
        uri   => 'http://localhost/',
    );
    isa_ok $pager->uri, 'URI';
    is $pager->page, 1;
}

sub pages : Test(6) {
    my $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query    => test::Movie->movies_query,
        per_page => 10,
    );
    is $pager->count, 7;
    is $pager->total_pages, 1;

    $pager->per_page(6);
    is $pager->total_pages, 2;

    $pager->per_page(5);
    is $pager->total_pages, 2;

    $pager->per_page(3);
    is $pager->total_pages, 3;

    $pager->per_page(2);
    is $pager->total_pages, 4;
}

sub _explicit_offset : Test(2) {
    my $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        offset => 12,
    );
    is $pager->offset, 12;
    is $pager->page, 1;
}

sub _has_next : Test(5) {
    my $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query,
    );
    $pager->per_page(12);
    ng $pager->has_next;
    
    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query,
    );
    $pager->per_page(12);
    $pager->page(2);
    ng $pager->has_next;
    
    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query,
    );
    $pager->per_page(5);
    ok $pager->has_next;
    
    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query,
    );
    $pager->per_page(5);
    $pager->page(2);
    ok $pager->has_next;
    
    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query,
    );
    $pager->per_page(5);
    $pager->page(3);
    ng $pager->has_next;
}

sub items : Tests(6) {
    my $self = shift;
    my $pager;

    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query,
    );
    isa_list_ok $pager->items;
    isa_ok $pager->items->first, 'test::Movie';
    is $pager->count, motemen->movies->size;

    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => test::Movie->query,
    );
    isa_list_ok $pager->items;
    isa_ok $pager->items->first, 'test::Movie';
    is $pager->count, test::Movie->count;
}

sub since : Tests(2) {
    my $self = shift;
    my $pager;
    my $since = '2010-11-19 05:18:31';

    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query->new,
        since => DateTime::Format::MySQL->parse_datetime($since),
    );
    is_deeply $pager->query->where->{created_on}, {">" => $since};

    $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query => motemen->movies_query->new,
        since => DateTime::Format::MySQL->parse_datetime($since),
        created_on_column => 'created'
    );
    is_deeply $pager->query->where->{created}, {">" => $since};
}

sub range : Tests(5) {
    my $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query    => test::Movie->movies_query,
        uri      => '/test?foo=bar',
        page     => 1,
        per_page => 10,
        count    => 10,
    );
    is_deeply $pager->range, [
        {
            page => 1,
            uri  => '/test?foo=bar'
        },
    ];

    $pager->per_page(5);
    is_deeply $pager->range, [
        {
            page => 1,
            uri  => '/test?foo=bar',
        },
        {
            page => 2,
            uri  => '/test?foo=bar&page=2',
        },
    ];

    $pager->per_page(1);
    is_deeply $pager->range, [
        {
            page => 1,
            uri  => '/test?foo=bar',
        },
        {
            page => 2,
            uri  => '/test?foo=bar&page=2',
        },
        {
            page => 3,
            uri  => '/test?foo=bar&page=3',
        },
        {
            page => 4,
            uri  => '/test?foo=bar&page=4',
        },
        {
            page => 5,
            uri  => '/test?foo=bar&page=5',
        },
        {
            page => 6,
            uri  => '/test?foo=bar&page=6',
        },
        {
            page => 7,
            uri  => '/test?foo=bar&page=7',
        },
    ];

    $pager->pages_in_range(3);
    is_deeply $pager->range, [
        {
            page => 1,
            uri  => '/test?foo=bar',
        },
        {
            page => 2,
            uri  => '/test?foo=bar&page=2',
        },
        {
            page => 3,
            uri  => '/test?foo=bar&page=3',
        },
    ];

    $pager->page(3);
    is_deeply $pager->range, [
        {
            page => 2,
            uri  => '/test?foo=bar&page=2',
        },
        {
            page => 3,
            uri  => '/test?foo=bar&page=3',
        },
        {
            page => 4,
            uri  => '/test?foo=bar&page=4',
        },
    ];
}

sub page_uri : Tests(15) {
    my $pager = Karasuma::Pager::QueryOffset::MoCo->new(
        query    => test::Movie->movies_query,
        uri      => '/test?foo=bar&foo=hoge',
        page     => 1,
        per_page => 10,
        count    => 10,
    );
    is $pager->page_uri(1), '/test?foo=bar&foo=hoge';
    is $pager->page_uri(2), '/test?foo=bar&foo=hoge&page=2';

    is $pager->page_uri('hoge'), '/test?foo=bar&foo=hoge';
    is $pager->page_uri(-100), '/test?foo=bar&foo=hoge';

    $pager->uri('/test?foo=bar&foo=hoge&page=8');

    is $pager->page_uri(), '/test?foo=bar&foo=hoge';
    is $pager->page_uri(1), '/test?foo=bar&foo=hoge';
    is $pager->page_uri(2), '/test?foo=bar&foo=hoge&page=2';

    is $pager->page_uri(-100), '/test?foo=bar&foo=hoge';
    is $pager->page_uri('hoge'), '/test?foo=bar&foo=hoge';

    {
        my $pager = Karasuma::Pager::QueryOffset::MoCo->new(uri => '/?page=2&x=x&y=y');
        is $pager->page_uri(1), '/?x=x&y=y';
        is $pager->page_uri(2), '/?page=2&x=x&y=y';
        is $pager->page_uri(3), '/?page=3&x=x&y=y';
    }

    {
        my $pager = Karasuma::Pager::QueryOffset::MoCo->new(uri => '/?page=2&foo=a&foo=b&bar=c');
        is $pager->page_uri(1), '/?bar=c&foo=a&foo=b';
        is $pager->page_uri(2), '/?bar=c&foo=a&foo=b&page=2';
        is $pager->page_uri(3), '/?bar=c&foo=a&foo=b&page=3';
    }
}

__PACKAGE__->runtests;

1;
