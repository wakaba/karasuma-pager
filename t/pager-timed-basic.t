package test::Karasuma::Pager::Timed::Basic;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->subdir('modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::MoreMore::Mock;
use Karasuma::URL;
use Scalar::Util qw(weaken);

{
    package test::pager::empty;
    use base qw(Karasuma::Pager::Timed::Basic);

    sub _all_items { List::Rubyish->new }
    
    sub window_items {
        my $self = shift;
        my $reftime = $self->reference_time;
        my $reftype = $self->reference_type;
        my $list = $self->_all_items;
        if ($reftime) {
            $list = $list->grep($reftype eq 'before'
                                    ? sub { $reftime >= $_->[1] }
                                    : sub { $reftime <= $_->[1] });
        }
        $list = $list->reverse if $reftype eq 'before';
        my $refoffset = $self->reference_offset;
        if ($refoffset) {
            $list = $list->slice($refoffset, $list->length - 1);
        }
        return $list;
    }

    sub get_time_from_item {
        return $_[1]->[1];
    }
}

{
    package test::pager::1;
    use base qw(test::pager::empty);
    
                                          # value, timestamp
    sub _all_items { List::Rubyish->new([map { [$_, $_] } 1..100]) }
}

{
    package test::pager::2;
    use base qw(test::pager::empty);
    
                                          # value, timestamp
    sub _all_items { List::Rubyish->new([map { [$_, int $_] } qw(
        1 2 3 4 5 6.1 6.2 6.3 6.4 6.5 7.1 7.2 7.3 7.4 8 9 10 11 12 13
    )]) }
}

{
    package test::pager::3;
    use base qw(test::pager::empty);
 
    __PACKAGE__->mk_accessors(qw(_all_items));
}

{
    package test::pager::4;
    use base qw(test::pager::empty);
 
    __PACKAGE__->mk_accessors(qw(_all_items));

    sub window_items {
        my $self = shift;
        my $reftime = $self->reference_time;
        my $reftype = $self->reference_type;
        my $list = $self->_all_items;
        if ($reftime) {
            $list = $list->grep($reftype eq 'before'
                                    ? sub { $reftime >= $_->[1] }
                                    : sub { $reftime <= $_->[1] });
        }
        $list = $list->reverse if $reftype eq 'before';
        my $refoffset = $self->reference_offset;
        if ($refoffset) {
            $list = $list->slice($refoffset, $list->length - 1);
        }
        my $per_window = $self->per_window;
        $list = $list->slice(0, $per_window - 1);
        return $list;
    }
}

sub _type : Test(4) {
    my $pager = Karasuma::Pager::Timed::Basic->new;
    ng $pager->is_finite_list;
    ng $pager->is_query_offset;
    ng $pager->is_calendar;
    ok $pager->is_timed;
}

# ------ Input parameters ------

sub _set_params_by_req : Test(42) {
    for (
        [{} => 'before', undef, 0],
        [{order => 'asc'} => 'after', undef, 0],
        [{order => 'desc'} => 'before', undef, 0],
        [{reftime => '-120'} => 'before', 120, 0],
        [{reftime => '+120'} => 'after', 120, 0],
        [{reftime => '-120', order => 'asc'} => 'before', 120, 0],
        [{reftime => '+120', order => 'asc'} => 'after', 120, 0],
        [{reftime => '120'} => 'after', 120, 0],
        [{reftime => '120,23'} => 'after', 120, 23],
        [{reftime => '120,10023'} => 'after', 120, 1000],
        [{reftime => '-120,23'} => 'before', 120, 23],
        [{reftime => '120,23,45'} => 'after', 120, 23],
        [{reftime => 'abc'} => 'after', 0, 0],
        [{reftime => '-120.55'} => 'before', 120.55, 0],
    ) {
        my $req = Test::MoreMore::Mock->new(param => $_->[0]);
        my $pager = test::pager::1->new;
        $pager->set_params_by_req($req);
        is $pager->reference_type, $_->[1];
        is $pager->reference_time, $_->[2];
        is $pager->reference_offset, $_->[3];
    }
}

sub _reference_type : Test(7) {
    my $pager = test::pager::1->new;
    is $pager->reference_type, 'before';
    $pager->reference_type('after');
    is $pager->reference_type, 'after';
    $pager->reference_type('before');
    is $pager->reference_type, 'before';
    $pager->reference_type('abe gq');
    is $pager->reference_type, 'before';
    $pager->reference_type(undef);
    is $pager->reference_type, 'before';
    $pager->{reference_type} = 'gewga';
    is $pager->reference_type, 'before';
    $pager->{reference_type} = 'after';
    is $pager->reference_type, 'after';
}

sub _reference_type_as_order : Test(2) {
    my $pager = test::pager::1->new;

    $pager->reference_type('after');
    is $pager->reference_type_as_order, 'asc';

    $pager->reference_type('before');
    is $pager->reference_type_as_order, 'desc';
}

sub _reference_time : Test(5) {
    my $pager = test::pager::1->new;
    is $pager->reference_time, undef;
    $pager->reference_time(52533);
    is $pager->reference_time, 52533;
    $pager->reference_time('gasgeae');
    is $pager->reference_time, 0;
    $pager->reference_time(-53253253);
    is $pager->reference_time, -53253253;
    $pager->reference_time(undef);
    is $pager->reference_time, undef;
}

sub _reference_offset : Test(6) {
    my $pager = test::pager::1->new;
    is $pager->reference_offset, 0;
    $pager->reference_offset(5353);
    is $pager->reference_offset, 1000;
    $pager->reference_offset(53);
    is $pager->reference_offset, 53;
    $pager->reference_offset(53.201);
    is $pager->reference_offset, 53;
    $pager->reference_offset(-35);
    is $pager->reference_offset, 0;
    $pager->reference_offset('gaega');
    is $pager->reference_offset, 0;
}

sub _per_page : Test(7) {
    my $pager = test::pager::1->new;
    is $pager->per_page, 1;
    $pager->per_page(210);
    is $pager->per_page, 210;
    $pager->per_page(-500);
    is $pager->per_page, 1;
    $pager->per_page(10.3);
    is $pager->per_page, 10;
    $pager->per_page(0);
    is $pager->per_page, 1;
    $pager->per_page('gewagwage');
    is $pager->per_page, 1;
    $pager->{per_page} = 'gewea';
    is $pager->per_page, 1;
}

sub _per_window : Test(7) {
    my $pager = test::pager::1->new;
    is $pager->per_window, 1;
    $pager->per_window(210);
    is $pager->per_window, 210;
    $pager->per_window(-500);
    is $pager->per_window, 1;
    $pager->per_window(10.3);
    is $pager->per_window, 10;
    $pager->per_window(0);
    is $pager->per_window, 1;
    $pager->per_window('gewagwage');
    is $pager->per_window, 1;
    $pager->{per_window} = 'gewea';
    is $pager->per_window, 1;
}

sub _order : Test(6) {
    my $pager = test::pager::1->new;
    is $pager->order, 'desc';
    $pager->order('asc');
    is $pager->order, 'asc';
    $pager->order('desc');
    is $pager->order, 'desc';
    $pager->order('geage');
    is $pager->order, 'asc';
    $pager->{order} = 'ggqfagawg';
    is $pager->order, 'asc';
    $pager->{order} = 'asc';
    is $pager->order, 'asc';
}

# ------ Basic paging ------

# ---- Items ----

sub _items_no_args : Test(2) {
    my $pager = test::pager::1->new(per_page => 20);
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 81..100];
}

sub _items_no_args_desc : Test(2) {
    my $pager = test::pager::1->new(per_page => 20, order => 'desc');
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 81..100];
}

sub _items_no_args_asc : Test(2) {
    my $pager = test::pager::1->new(per_page => 20, order => 'asc');
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [81..100];
}

sub _items_reftype_before : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_type => 'before',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 81..100];
}

sub _items_reftype_after : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20, 
        reference_type => 'after',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..20];
}

sub _items_reftype_after_order_desc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20, 
        reference_type => 'after',
        order => 'desc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..20];
}

sub _items_reftype_after_order_asc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20, 
        reference_type => 'after',
        order => 'asc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [1..20];
}

sub _items_no_args_not_enough : Test(2) {
    my $pager = test::pager::1->new(per_page => 200);
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..100];
}

sub _items_no_args_not_enough_order_desc : Test(2) {
    my $pager = test::pager::1->new(per_page => 200, order => 'desc');
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..100];
}

sub _items_no_args_not_enough_order_asc : Test(2) {
    my $pager = test::pager::1->new(per_page => 200, order => 'asc');
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [1..100];
}

sub _items_no_args_not_enough_reftype_before : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 200,
        reference_type => 'before',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..100];
}

sub _items_no_args_not_enough_reftype_after : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 200,
        reference_type => 'after',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..100];
}

sub _items_no_args_not_enough_reftype_after_order_desc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 200,
        reference_type => 'after',
        order => 'desc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..100];
}

sub _items_no_args_not_enough_reftype_after_order_asc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 200,
        reference_type => 'after',
        order => 'asc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 100;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [1..100];
}

sub _items_no_args_empty : Test(1) {
    my $pager = test::pager::empty->new(per_page => 20);
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 0;
}

sub _items_no_args_empty_order_desc : Test(1) {
    my $pager = test::pager::empty->new(per_page => 20, order => 'desc');
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 0;
}

sub _items_no_args_empty_order_asc : Test(1) {
    my $pager = test::pager::empty->new(per_page => 20, order => 'asc');
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 0;
}

sub _items_reftime : Test(2) {
    my $pager = test::pager::1->new(per_page => 20, reference_time => 31);
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 12..31];
}

sub _items_reftime_reftype_before : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 31,
        reference_type => 'before',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 12..31];
}

sub _items_reftime_reftype_before_order_desc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 31,
        reference_type => 'before',
        order => 'desc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 12..31];
}

sub _items_reftime_reftype_before_order_asc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 31,
        reference_type => 'before',
        order => 'asc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [12..31];
}

sub _items_reftime_reftype_after : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 31,
        reference_type => 'after',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 31..50];
}

sub _items_reftime_not_enough : Test(2) {
    my $pager = test::pager::1->new(per_page => 100, reference_time => 11);
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 11;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..11];
}

sub _items_reftime_not_enough_reftype_before : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 11,
        reference_type => 'before',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 11;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..11];
}

sub _items_reftime_not_enough_reftype_before_order_desc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 11,
        reference_type => 'before',
        order => 'desc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 11;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..11];
}

sub _items_reftime_not_enough_reftype_before_order_asc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 11,
        reference_type => 'before',
        order => 'asc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 11;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [1..11];
}

sub _items_reftime_reftype_after_not_enough : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 91,
        reference_type => 'after',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 10;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 91..100];
}

sub _items_reftime_refoffset : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 30,
        reference_offset => 3,
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 8..27];
}

sub _items_reftime_refoffset_reftype_before : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'before',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 8..27];
}

sub _items_reftime_refoffset_reftype_before_order_desc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'before',
        order => 'desc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 8..27];
}

sub _items_reftime_refoffset_reftype_before_order_asc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'before',
        order => 'asc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [8..27];
}

sub _items_reftime_refoffset_reftype_after : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'after',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 20;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 33..52];
}

sub _items_reftime_refoffset_not_enough : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 30,
        reference_offset => 3,
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 27;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..27];
}

sub _items_reftime_refoffset_not_enough_reftype_before : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'before',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 27;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 1..27];
}

sub _items_reftime_refoffset_not_enough_reftype_after : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'after',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 68;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 33..100];
}

sub _items_reftime_refoffset_not_enough_reftype_after_order_desc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'after',
        order => 'desc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 68;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [reverse 33..100];
}

sub _items_reftime_refoffset_not_enough_reftype_after_order_asc : Test(2) {
    my $pager = test::pager::1->new(
        per_page => 100,
        reference_time => 30,
        reference_offset => 3,
        reference_type => 'after',
        order => 'asc',
    );
    my $l1 = $pager->items;
    isa_list_n_ok $l1, 68;
    eq_or_diff $l1->map(sub { $_->[0] })->to_a, [33..100];
}

# ---- Older/newer ----

sub _older_newer_no_args : Test(6) {
    my $pager = test::pager::1->new(per_page => 20);
    is $pager->older_reference_type, 'before';
    is $pager->older_reference_time, 81;
    is $pager->older_reference_offset, 1;
    is $pager->newer_reference_type, 'after';
    is $pager->newer_reference_time, 100;
    is $pager->newer_reference_offset, 1;
}

sub _older_newer_before : Test(6) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_type => 'before',
        reference_time => 81,
        reference_offset => 1,
    );
    is $pager->older_reference_type, 'before';
    is $pager->older_reference_time, 61;
    is $pager->older_reference_offset, 1;
    is $pager->newer_reference_type, 'after';
    is $pager->newer_reference_time, 80;
    is $pager->newer_reference_offset, 1;
}

sub _older_newer_reftype_after : Test(8) {
    my $pager = test::pager::1->new(per_page => 20, reference_type => 'after');
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [reverse 1..20];
    eq_or_diff $pager->relevant_items->map(sub { $_->[0] })->to_a, [reverse 1..20];
    is $pager->older_reference_type, 'before';
    is $pager->older_reference_time, 1;
    is $pager->older_reference_offset, 1;
    is $pager->newer_reference_type, 'after';
    is $pager->newer_reference_time, 20;
    is $pager->newer_reference_offset, 1;
}

sub _older_newer_reftype_after_reftime : Test(6) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_type => 'after',
        reference_time => 40,
    );
    is $pager->older_reference_type, 'before';
    is $pager->older_reference_time, 40;
    is $pager->older_reference_offset, 1;
    is $pager->newer_reference_type, 'after';
    is $pager->newer_reference_time, 59;
    is $pager->newer_reference_offset, 1;
}

sub _older_newer_reftype_after_reftime_refoffset : Test(6) {
    my $pager = test::pager::1->new(
        per_page => 20,
        reference_type => 'after',
        reference_time => 40,
        reference_offset => 3,
    );
    is $pager->older_reference_type, 'before';
    is $pager->older_reference_time, 43;
    is $pager->older_reference_offset, 1;
    is $pager->newer_reference_type, 'after';
    is $pager->newer_reference_time, 62;
    is $pager->newer_reference_offset, 1;
}

# ------ If there are multiple items with same timestamps ------

sub _sametime_after_asc : Test(7) {
    # 1 2 3 4 5 6.1 6.2 6.3 6.4 6.5 7.1 7.2 7.3 7.4 8 9 10 11 12 13
    my $pager = test::pager::2->new(
        per_page => 8,
        reference_type => 'after',
        order => 'asc',
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5 6.1 6.2 6.3
    )];

    my $pager2 = test::pager::2->new(
        per_page => 8,
        reference_type => 'after',
        order => 'asc',
        reference_type => $pager->newer_reference_type,
        reference_time => $pager->newer_reference_time,
        reference_offset => $pager->newer_reference_offset,
    );
    is $pager2->reference_time, 6;
    is $pager2->reference_offset, 3;
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        6.4 6.5 7.1 7.2 7.3 7.4 8 9
    )];

    my $pager3 = test::pager::2->new(
        per_page => 8,
        reference_type => 'before',
        order => 'asc',
        reference_type => $pager2->older_reference_type,
        reference_time => $pager2->older_reference_time,
        reference_offset => $pager2->older_reference_offset,
    );
    is $pager3->reference_time, 6;
    is $pager3->reference_offset, 2;
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5 6.1 6.2 6.3
    )];
}

sub _sametime_before_desc : Test(7) {
    # 1 2 3 4 5 6.1 6.2 6.3 6.4 6.5 7.1 7.2 7.3 7.4 8 9 10 11 12 13
    my $pager = test::pager::2->new(
        per_page => 8,
        reference_type => 'before',
        order => 'desc',
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        13 12 11 10 9 8 7.4 7.3
    )];

    my $pager2 = test::pager::2->new(
        per_page => 8,
        reference_type => 'before',
        order => 'desc',
        reference_type => $pager->older_reference_type,
        reference_time => $pager->older_reference_time,
        reference_offset => $pager->older_reference_offset,
    );
    is $pager2->reference_time, 7;
    is $pager2->reference_offset, 2;
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        7.2 7.1 6.5 6.4 6.3 6.2 6.1 5
    )];

    my $pager3 = test::pager::2->new(
        per_page => 8,
        reference_type => 'after',
        order => 'desc',
        reference_type => $pager2->newer_reference_type,
        reference_time => $pager2->newer_reference_time,
        reference_offset => $pager2->newer_reference_offset,
    );
    is $pager3->reference_time, 7;
    is $pager3->reference_offset, 2;
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        13 12 11 10 9 8 7.4 7.3
    )];
}

sub _sametime_morethanpage_after_asc : Test(10) {
    # 1 2 3 4 5 6.1 6.2 6.3 6.4 6.5 7.1 7.2 7.3 7.4 8 9 10 11 12 13
    my $pager = test::pager::2->new(
        per_page => 2,
        reference_type => 'after',
        reference_time => 6,
        reference_offset => 1,
        order => 'asc',
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        6.2 6.3
    )];

    my $pager2 = test::pager::2->new(
        per_page => 2,
        reference_type => 'after',
        order => 'asc',
        reference_type => $pager->newer_reference_type,
        reference_time => $pager->newer_reference_time,
        reference_offset => $pager->newer_reference_offset,
    );
    is $pager2->reference_time, 6;
    is $pager2->reference_offset, 3;
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        6.4 6.5
    )];

    my $pager3 = test::pager::2->new(
        per_page => 2,
        reference_type => 'after',
        order => 'asc',
        reference_type => $pager2->newer_reference_type,
        reference_time => $pager2->newer_reference_time,
        reference_offset => $pager2->newer_reference_offset,
    );
    is $pager3->reference_time, 6;
    is $pager3->reference_offset, 5;
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        7.1 7.2
    )];

    my $pager4 = test::pager::2->new(
        per_page => 2,
        reference_type => 'after',
        order => 'asc',
        reference_type => $pager3->newer_reference_type,
        reference_time => $pager3->newer_reference_time,
        reference_offset => $pager3->newer_reference_offset,
    );
    is $pager4->reference_time, 7;
    is $pager4->reference_offset, 2;
    eq_or_diff $pager4->items->map(sub { $_->[0] })->to_a, [qw(
        7.3 7.4
    )];
}

sub _sametime_morethanpage_before_desc : Test(10) {
    # 1 2 3 4 5 6.1 6.2 6.3 6.4 6.5 7.1 7.2 7.3 7.4 8 9 10 11 12 13
    my $pager = test::pager::2->new(
        per_page => 2,
        reference_type => 'before',
        reference_time => 8,
        reference_offset => 1,
        order => 'desc',
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        7.4 7.3
    )];

    my $pager2 = test::pager::2->new(
        per_page => 2,
        reference_type => 'before',
        order => 'desc',
        reference_type => $pager->older_reference_type,
        reference_time => $pager->older_reference_time,
        reference_offset => $pager->older_reference_offset,
    );
    is $pager2->reference_time, 7;
    is $pager2->reference_offset, 2;
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        7.2 7.1
    )];

    my $pager3 = test::pager::2->new(
        per_page => 2,
        reference_type => 'before',
        order => 'desc',
        reference_type => $pager2->older_reference_type,
        reference_time => $pager2->older_reference_time,
        reference_offset => $pager2->older_reference_offset,
    );
    is $pager3->reference_time, 7;
    is $pager3->reference_offset, 4;
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        6.5 6.4
    )];

    my $pager4 = test::pager::2->new(
        per_page => 2,
        reference_type => 'before',
        order => 'desc',
        reference_type => $pager3->older_reference_type,
        reference_time => $pager3->older_reference_time,
        reference_offset => $pager3->older_reference_offset,
    );
    is $pager4->reference_time, 6;
    is $pager4->reference_offset, 2;
    eq_or_diff $pager4->items->map(sub { $_->[0] })->to_a, [qw(
        6.3 6.2
    )];
}

# ------ Filtering ------

sub _filtered_items_no_args : Test(7) {
    my $pager = test::pager::3->new(
        _all_items => List::Rubyish->new([
            [1, 1, 1],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 1],
            [8, 8, 0],
            [9, 9, 1],
        ]),
        per_page => 3,
        item_filter => sub { $_[0]->[2] },
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        9 7 4
    )];

    my $pager2 = test::pager::3->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        item_filter => $pager->item_filter,
        reference_type => $pager->older_reference_type,
        reference_time => $pager->older_reference_time,
        reference_offset => $pager->older_reference_offset,
    );
    is $pager2->reference_time, 3;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        2 1
    )];
 
    my $pager3 = test::pager::3->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        item_filter => $pager->item_filter,
        reference_type => $pager2->older_reference_type,
        reference_time => $pager2->older_reference_time,
        reference_offset => $pager2->older_reference_offset,
    );
    is $pager3->reference_time, 1;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
}

sub _filtered_items_many_filtered : Test(13) {
    my $pager = test::pager::4->new(
        _all_items => List::Rubyish->new([
            [1, 1, 0],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 0],
            [8, 8, 0],
            [9, 9, 0],
            [10, 10, 0],
            [11, 11, 0],
            [12, 12, 0],
            [13, 13, 0],
            [14, 14, 1],
            [15, 15, 1],
            [16, 16, 0],
            [17, 17, 1],
        ]),
        per_page => 3,
        per_window => 5,
        item_filter => sub { $_[0]->[2] },
    );
    eq_or_diff $pager->window_items->map(sub { $_->[0] })->to_a, [qw(
        17 16 15 14 13
    )];
    eq_or_diff $pager->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        17 16 15 14 13
    )];
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        17 15 14
    )];

    my $pager2 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager->older_reference_type,
        reference_time => $pager->older_reference_time,
        reference_offset => $pager->older_reference_offset,
    );
    is $pager2->reference_time, 13;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->window_items->map(sub { $_->[0] })->to_a, [qw(
        12 11 10 9 8
    )];
    eq_or_diff $pager2->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        12 11 10 9 8
    )];
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
 
    my $pager3 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager2->older_reference_type,
        reference_time => $pager2->older_reference_time,
        reference_offset => $pager2->older_reference_offset,
    );
    is $pager3->reference_time, 8;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->window_items->map(sub { $_->[0] })->to_a, [qw(
        7 6 5 4 3
    )];
    eq_or_diff $pager3->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        7 6 5 4 3
    )];
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        4
    )];
}

sub _filtered_items_many_filtered_2 : Test(28) {
    my $pager = test::pager::4->new(
        _all_items => List::Rubyish->new([
            [1, 1, 0],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 0],
            [8, 8, 0],
            [9, 9, 0],
            [10, 10, 0],
            [11, 11, 0],
            [12, 12, 0],
            [13, 13, 0],
            [14, 14, 1],
            [15, 15, 1],
            [16, 16, 0],
            [17, 17, 1],
            [18, 18, 0],
            [19, 19, 1],
            [20, 20, 1],
        ]),
        per_page => 3,
        per_window => 7,
        item_filter => sub { $_[0]->[2] },
    );
    eq_or_diff $pager->window_items->map(sub { $_->[0] })->to_a, [qw(
        20 19 18 17 16 15 14
    )];
    eq_or_diff $pager->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        20 19 18 17 16
    )];
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        20 19 17
    )];

    my $pager2 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager->older_reference_type,
        reference_time => $pager->older_reference_time,
        reference_offset => $pager->older_reference_offset,
    );
    is $pager2->reference_time, 16;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->window_items->map(sub { $_->[0] })->to_a, [qw(
        15 14 13 12 11 10 9
    )];
    eq_or_diff $pager2->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        15 14 13 12 11 10 9
    )];
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        15 14
    )];
 
    my $pager3 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager2->older_reference_type,
        reference_time => $pager2->older_reference_time,
        reference_offset => $pager2->older_reference_offset,
    );
    is $pager3->reference_time, 9;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->window_items->map(sub { $_->[0] })->to_a, [qw(
        8 7 6 5 4 3 2
    )];
    eq_or_diff $pager3->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        8 7 6 5 4 3 2
    )];
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        4 2
    )];
 
    my $pager4 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager3->older_reference_type,
        reference_time => $pager3->older_reference_time,
        reference_offset => $pager3->older_reference_offset,
    );
    is $pager4->reference_time, 2;
    is $pager4->reference_offset, 1;
    eq_or_diff $pager4->window_items->map(sub { $_->[0] })->to_a, [qw(
        1
    )];
    eq_or_diff $pager4->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        1
    )];
    eq_or_diff $pager4->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    
    my $pager5 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager4->older_reference_type,
        reference_time => $pager4->older_reference_time,
        reference_offset => $pager4->older_reference_offset,
    );
    is $pager5->reference_time, 1;
    is $pager5->reference_offset, 1;
    eq_or_diff $pager5->window_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager5->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager5->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    
    my $pager6 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        reference_type => $pager5->older_reference_type,
        reference_time => $pager5->older_reference_time,
        reference_offset => $pager5->older_reference_offset,
    );
    is $pager6->reference_time, 1;
    is $pager6->reference_offset, 1;
    eq_or_diff $pager6->window_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager6->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager6->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
}

sub _filtered_items_xyz : Test(7) {
    my $pager = test::pager::3->new(
        _all_items => List::Rubyish->new([
            [1, 1, 1],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 1],
            [8, 8, 0],
            [9, 9, 1],
        ]),
        per_page => 3,
        item_filter => sub { $_[0]->[2] },
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        9 7 4
    )];

    my $pager2 = test::pager::3->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        item_filter => $pager->item_filter,
        reference_type => $pager->older_reference_type,
        reference_time => $pager->older_reference_time,
        reference_offset => $pager->older_reference_offset,
    );
    is $pager2->reference_time, 3;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        2 1
    )];
 
    my $pager3 = test::pager::3->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        item_filter => $pager->item_filter,
        reference_type => $pager2->older_reference_type,
        reference_time => $pager2->older_reference_time,
        reference_offset => $pager2->older_reference_offset,
    );
    is $pager3->reference_time, 1;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
}

sub _filtered_items_asc_many_filtered : Test(13) {
    my $pager = test::pager::4->new(
        _all_items => List::Rubyish->new([
            [1, 1, 0],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 0],
            [8, 8, 0],
            [9, 9, 0],
            [10, 10, 0],
            [11, 11, 0],
            [12, 12, 0],
            [13, 13, 0],
            [14, 14, 1],
            [15, 15, 1],
            [16, 16, 0],
            [17, 17, 1],
        ]),
        per_page => 3,
        per_window => 5,
        item_filter => sub { $_[0]->[2] },
        reference_type => 'after',
        order => 'asc',
    );
    eq_or_diff $pager->window_items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5
    )];
    eq_or_diff $pager->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5
    )];
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        2 4
    )];

    my $pager2 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager->newer_reference_type,
        reference_time => $pager->newer_reference_time,
        reference_offset => $pager->newer_reference_offset,
    );
    is $pager2->reference_time, 5;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->window_items->map(sub { $_->[0] })->to_a, [qw(
        6 7 8 9 10
    )];
    eq_or_diff $pager2->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        6 7 8 9 10
    )];
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
 
    my $pager3 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager2->newer_reference_type,
        reference_time => $pager2->newer_reference_time,
        reference_offset => $pager2->newer_reference_offset,
    );
    is $pager3->reference_time, 10;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->window_items->map(sub { $_->[0] })->to_a, [qw(
        11 12 13 14 15
    )];
    eq_or_diff $pager3->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        11 12 13 14 15
    )];
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        14 15
    )];
}

sub _filtered_items_asc_many_filtered_2 : Test(28) {
    my $pager = test::pager::4->new(
        _all_items => List::Rubyish->new([
            [1, 1, 0],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 0],
            [8, 8, 0],
            [9, 9, 0],
            [10, 10, 0],
            [11, 11, 0],
            [12, 12, 0],
            [13, 13, 0],
            [14, 14, 1],
            [15, 15, 1],
            [16, 16, 0],
            [17, 17, 1],
            [18, 18, 0],
            [19, 19, 1],
            [20, 20, 1],
        ]),
        per_page => 3,
        per_window => 7,
        item_filter => sub { $_[0]->[2] },
        reference_type => 'after',
        order => 'asc',
    );
    eq_or_diff $pager->window_items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5 6 7
    )];
    eq_or_diff $pager->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5 6 7
    )];
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        2 4
    )];

    my $pager2 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager->newer_reference_type,
        reference_time => $pager->newer_reference_time,
        reference_offset => $pager->newer_reference_offset,
    );
    is $pager2->reference_time, 7;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->window_items->map(sub { $_->[0] })->to_a, [qw(
        8 9 10 11 12 13 14
    )];
    eq_or_diff $pager2->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        8 9 10 11 12 13 14
    )];
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        14
    )];
 
    my $pager3 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager2->newer_reference_type,
        reference_time => $pager2->newer_reference_time,
        reference_offset => $pager2->newer_reference_offset,
    );
    is $pager3->reference_time, 14;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->window_items->map(sub { $_->[0] })->to_a, [qw(
        15 16 17 18 19 20
    )];
    eq_or_diff $pager3->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        15 16 17 18 19 
    )];
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        15 17 19
    )];
 
    my $pager4 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager3->newer_reference_type,
        reference_time => $pager3->newer_reference_time,
        reference_offset => $pager3->newer_reference_offset,
    );
    is $pager4->reference_time, 19;
    is $pager4->reference_offset, 1;
    eq_or_diff $pager4->window_items->map(sub { $_->[0] })->to_a, [qw(
        20
    )];
    eq_or_diff $pager4->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        20
    )];
    eq_or_diff $pager4->items->map(sub { $_->[0] })->to_a, [qw(
        20
    )];
    
    my $pager5 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager4->newer_reference_type,
        reference_time => $pager4->newer_reference_time,
        reference_offset => $pager4->newer_reference_offset,
    );
    is $pager5->reference_time, 20;
    is $pager5->reference_offset, 1;
    eq_or_diff $pager5->window_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager5->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager5->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    
    my $pager6 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager5->newer_reference_type,
        reference_time => $pager5->newer_reference_time,
        reference_offset => $pager5->newer_reference_offset,
    );
    is $pager6->reference_time, 20;
    is $pager6->reference_offset, 1;
    eq_or_diff $pager6->window_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager6->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager6->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
}

sub _filtered_items_asc_many_filtered_3 : Test(28) {
    my $pager = test::pager::4->new(
        _all_items => List::Rubyish->new([
            [1, 1, 0],
            [2, 2, 1],
            [3, 3, 1],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 1],
            [7, 7, 0],
            [8, 8, 1],
            [9, 9, 0],
            [10, 10, 0],
            [11, 11, 0],
            [12, 12, 0],
            [13, 13, 0],
            [14, 14, 1],
            [15, 15, 1],
            [16, 16, 1],
            [17, 17, 1],
            [18, 18, 0],
            [19, 19, 1],
            [20, 20, 1],
        ]),
        per_page => 3,
        per_window => 7,
        item_filter => sub { $_[0]->[2] },
        reference_type => 'after',
        order => 'asc',
    );
    eq_or_diff $pager->window_items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5 6 7
    )];
    eq_or_diff $pager->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        1 2 3 4 5
    )];
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        2 3 4
    )];

    my $pager2 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager->newer_reference_type,
        reference_time => $pager->newer_reference_time,
        reference_offset => $pager->newer_reference_offset,
    );
    is $pager2->reference_time, 5;
    is $pager2->reference_offset, 1;
    eq_or_diff $pager2->window_items->map(sub { $_->[0] })->to_a, [qw(
        6 7 8 9 10 11 12
    )];
    eq_or_diff $pager2->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        6 7 8 9 10 11 12
    )];
    eq_or_diff $pager2->items->map(sub { $_->[0] })->to_a, [qw(
        6 8
    )];
 
    my $pager3 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager2->newer_reference_type,
        reference_time => $pager2->newer_reference_time,
        reference_offset => $pager2->newer_reference_offset,
    );
    is $pager3->reference_time, 12;
    is $pager3->reference_offset, 1;
    eq_or_diff $pager3->window_items->map(sub { $_->[0] })->to_a, [qw(
        13 14 15 16 17 18 19
    )];
    eq_or_diff $pager3->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        13 14 15 16
    )];
    eq_or_diff $pager3->items->map(sub { $_->[0] })->to_a, [qw(
        14 15 16
    )];
 
    my $pager4 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager3->newer_reference_type,
        reference_time => $pager3->newer_reference_time,
        reference_offset => $pager3->newer_reference_offset,
    );
    is $pager4->reference_time, 16;
    is $pager4->reference_offset, 1;
    eq_or_diff $pager4->window_items->map(sub { $_->[0] })->to_a, [qw(
        17 18 19 20
    )];
    eq_or_diff $pager4->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        17 18 19 20
    )];
    eq_or_diff $pager4->items->map(sub { $_->[0] })->to_a, [qw(
        17 19 20
    )];
    
    my $pager5 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager4->newer_reference_type,
        reference_time => $pager4->newer_reference_time,
        reference_offset => $pager4->newer_reference_offset,
    );
    is $pager5->reference_time, 20;
    is $pager5->reference_offset, 1;
    eq_or_diff $pager5->window_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager5->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager5->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    
    my $pager6 = test::pager::4->new(
        _all_items => $pager->_all_items,
        per_page => $pager->per_page,
        per_window => $pager->per_window,
        item_filter => $pager->item_filter,
        order => $pager->order,
        reference_type => $pager5->newer_reference_type,
        reference_time => $pager5->newer_reference_time,
        reference_offset => $pager5->newer_reference_offset,
    );
    is $pager6->reference_time, 20;
    is $pager6->reference_offset, 1;
    eq_or_diff $pager6->window_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager6->relevant_items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
    eq_or_diff $pager6->items->map(sub { $_->[0] })->to_a, [qw(
        
    )];
}

sub _filtered_items_by_hashref : Test(1) {
    {
        package test::object::1;
        
        sub filter {
            return $_[1]->[2];
        }
    }

    my $pager = test::pager::3->new(
        _all_items => List::Rubyish->new([
            [1, 1, 1],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 1],
            [8, 8, 0],
            [9, 9, 1],
        ]),
        per_page => 3,
        item_filter => {object => 'test::object::1', method => 'filter'},
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [qw(
        9 7 4
    )];
}

sub _filtered_items_by_hashref_missing_weakref : Test(1) {
    my $v = {b => bless {}, 'test::class::1'};
    my $x = {object => $v->{b}, method => 'filter'};
    weaken $x->{object};
    $v = undef;
    my $pager = test::pager::3->new(
        _all_items => List::Rubyish->new([
            [1, 1, 1],
            [2, 2, 1],
            [3, 3, 0],
            [4, 4, 1],
            [5, 5, 0],
            [6, 6, 0],
            [7, 7, 1],
            [8, 8, 0],
            [9, 9, 1],
        ]),
        per_page => 3,
        item_filter => $x,
    );
    eq_or_diff $pager->items->map(sub { $_->[0] })->to_a, [];
}

# ------ URLs ------

sub _urls : Test(6) {
    my $u = Karasuma::URL->new(path => [qw/a b/]);
    my $pager = test::pager::1->new;
    $pager->unpaged_url($u);
    is $pager->get_url->as_absurl, q</a/b>;
    is $pager->get_url(
        reference_time => '32553',
    )->as_absurl, q</a/b?reftime=-32553>;
    is $pager->get_url(
        reference_type => 'before',
        reference_time => '32553',
        reference_offset => 12,
    )->as_absurl, q</a/b?reftime=-32553%2C12>;
    is $pager->get_url(
        reference_type => 'after',
        reference_time => '32553',
        reference_offset => 12,
    )->as_absurl, q</a/b?reftime=%2B32553%2C12>;
    $pager->{older_reference_type} = 'after';
    $pager->{older_reference_time} = 53232;
    $pager->{older_reference_offset} = 53;
    $pager->{newer_reference_type} = 'before';
    $pager->{newer_reference_time} = 532312;
    $pager->{newer_reference_offset} = 534;
    is $pager->older_url->as_absurl, q</a/b?reftime=%2B53232%2C53>;
    is $pager->newer_url->as_absurl, q</a/b?reftime=-532312%2C534>;
}

__PACKAGE__->runtests;

1;
