package Karasuma::Pager::Role::HasQueryTimedPager;
use strict;
use warnings;
use base qw(Class::Data::Inheritable);
use Carp;
use Scalar::Util qw(weaken);

# ------ Setting parameters ------

sub set_pager_params_by_req {
    my ($self, $req) = @_;
    for my $name (qw(
        page
        reftime
        date date_delta
        per_page
        order
    )) {
        my $value = $req->param($name);
        if (defined $value) {
            $self->$name($value);
            my $n = 'has_' . $name;
            $self->$n(1);
        }
    }
    my $value = $req->epoch_param('since');
    if ($value) {
        $self->page_since($value);
        $self->has_page_since(1);
    }
}

# ------ Query objects ------

sub orig_query {
    my $class = shift;
    die "$class->orig_query is not implemented\n", Carp::longmess;
}

# Query, modified by Calendar pager if necessary.
sub query {
    my $self = shift;
    return $self->{_query} ||= do {
        if ($self->use_calendar_filter) {
            my $pager = $self->calendar_filter;
            $pager->modify_query($self->orig_query->clone);
        } else {
            $self->orig_query;
        }
    };
}

# ------ URLs for pagers ------

sub unpaged_url {
    my $self = shift;
    if (@_) {
        $self->{unpaged_url} = shift;
    }
    return $self->{unpaged_url} || do {
        require Karasuma::URL;
        Karasuma::URL->new;
    };
}

sub filtered_unpaged_url {
    my $self = shift;
    my $u;
    if ($self->use_calendar_filter) {
        $u = $self->calendar_filter->current_url->clone;
    } else {
        $u = $self->unpaged_url->clone;
    }
    $u->set_qparam(order => $self->order) if $self->has_order;
    $u->set_qparam(per_page => $self->per_page) if $self->has_per_page;
    $u->set_qparam(since => $self->page_since->epoch)
        if $self->has_page_since and $self->page_since;
    return $u;
}

sub filtered_unpaged_url_as_string {
    my $self = shift;
    return $self->{_filtered_unpaged_url_as_string} ||= $self->filtered_unpaged_url->as_absurl;
}

# ------ Common parameters ------

sub order {
    if (@_ > 1) {
        $_[0]->{order} = $_[1];
    }
    return $_[0]->{order};
}

sub has_order {
    if (@_ > 1) {
        $_[0]->{has_order} = $_[1];
    }
    return $_[0]->{has_order};
}

sub item_filter {
    if (@_ > 1) {
        $_[0]->{item_filter} = $_[1];
    }
    return $_[0]->{item_filter};
}

sub has_per_page {
    if (@_ > 1) {
        $_[0]->{has_per_page} = $_[1];
    }
    return $_[0]->{has_per_page};
}

__PACKAGE__->mk_classdata(default_per_page => 20);
__PACKAGE__->mk_classdata(default_mobile_per_page => 10);
__PACKAGE__->mk_classdata(default_order => undef);

sub device_for_pager {
    if (@_ > 1) {
        $_[0]->{device_for_pager} = $_[1];
    }
    return $_[0]->{device_for_pager};
}

sub per_page {
    my $self = shift;
    if (@_) {
        $self->{per_page} = shift;
    }
    if ($self->{per_page}) {
        my $mpp = $self->max_per_page;
        if ($self->{per_page} < $mpp) {
            return 0+$self->{per_page} || 1;
        } else {
            return $mpp;
        }
    }
    my $device = $self->device_for_pager || '';
    if ($device eq 'mobile') {
        return $self->default_mobile_per_page;
    } else {
        return $self->default_per_page;
    }
}

sub date_column { 'created_on' }
sub date_method { undef }

sub pager {
    my $self = shift;
    return $self->{_pager} ||= do {
        if ($self->page or $self->page_since or $self->force_offset_pager) {
            $self->offset_pager;
        } else {
            $self->timed_pager;
        }
    };
}

sub force_offset_pager {
    return 0;
}

# ------ Calendar filter ------

sub date {
    if (@_ > 1) {
        $_[0]->{date} = $_[1];
    }
    return $_[0]->{date};
}

sub date_delta {
    if (@_ > 1) {
        $_[0]->{date_delta} = $_[1];
    }
    return $_[0]->{date_delta};
}

sub date_level_default {
    if (@_ > 1) {
        $_[0]->{date_level_default} = $_[1];
    }
    return $_[0]->{date_level_default};
}

sub has_date {
    if (@_ > 1) {
        $_[0]->{has_date} = $_[1];
    }
    return $_[0]->{has_date};
}

sub has_date_delta {
    if (@_ > 1) {
        $_[0]->{has_date_delta} = $_[1];
    }
    return $_[0]->{has_date_delta};
}

sub use_calendar_filter {
    my $self = shift;
    return $self->date || $self->date_level_default;
}

sub calendar_locale {
    my $self = shift;
    return $self->locale;
}

__PACKAGE__->mk_classdata(calendar_filter_class => 'Karasuma::Pager::Calendar::HasMoCoQuery');

sub calendar_filter {
    my $self = shift;
    return $self->{_calendar_filter} ||= do {
        my $pager_class = $self->calendar_filter_class;
        eval qq{ require $pager_class } or die $@;
        
        my $pager = $pager_class->new(
            date => $self->date,
            date_delta => $self->date_delta,
            date_level_default => $self->date_level_default,
            locale => $self->calendar_locale,
            unpaged_url => $self->unpaged_url,
            created_on_column => $self->date_column,
        );
        
        $pager;
    };
}

# ------ Offset-based pager ------

__PACKAGE__->mk_classdata(max_page => 200);
__PACKAGE__->mk_classdata(max_per_page => 200);

sub page {
    if (@_ > 1) {
        $_[0]->{page} = $_[1];
    }
    return $_[0]->{page};
}

sub page_since {
    if (@_ > 1) {
        $_[0]->{page_since} = $_[1];
    }
    return $_[0]->{page_since};
}

sub has_page {
    if (@_ > 1) {
        $_[0]->{has_page} = $_[1];
    }
    return $_[0]->{has_page};
}

sub has_page_since {
    if (@_ > 1) {
        $_[0]->{has_page_since} = $_[1];
    }
    return $_[0]->{has_page_since};
}

__PACKAGE__->mk_classdata(offset_pager_class => 'Karasuma::Pager::QueryOffset::MoCo');

sub offset_pager {
    my $self = shift;
    return $self->{_offset_pager} ||= do {
        my $pager_class = $self->offset_pager_class;
        eval qq{ require $pager_class } or die $@;
        
        my $pager = $pager_class->new(
            uri => $self->filtered_unpaged_url_as_string,
            page => $self->page,
            max_page => $self->max_page,
            per_page => $self->per_page,
            since => $self->page_since, # DEPRECATED
            query => $self->query,
            # XXX order には未対応
            created_on_column => $self->date_column,
        );
        $pager;
    };
}

# ------ Time-based pager ------

sub reftime {
    if (@_ > 1) {
        $_[0]->{reftime} = $_[1];
    }
    return $_[0]->{reftime};
}

sub has_reftime {
    if (@_ > 1) {
        $_[0]->{has_reftime} = $_[1];
    }
    return $_[0]->{has_reftime};
}

sub per_window {
    my $self = shift;
    return $self->per_page * 5;
}

__PACKAGE__->mk_classdata(timed_pager_class => 'Karasuma::Pager::Timed::HasMoCoQuery');

sub timed_pager {
    my $self = shift;
    return $self->{_timed_pager} ||= do {
        my $pager_class = $self->timed_pager_class;
        eval qq{ require $pager_class } or die $@;
        
        my $item_filter;
        if ($self->can('item_filter')) {
            my $value = {object => $self, method => 'item_filter'};
            weaken $value->{object};
            $item_filter = $value;
        }
        
        my $items_preload;
        if ($self->can('items_preload')) {
            my $value = {object => $self, method => 'items_preload'};
            weaken $value->{object};
            $items_preload = $value;
        }
        
        my $additional_parameters;
        if ($self->can('additional_timed_pager_parameters')) {
            $additional_parameters = $self->additional_timed_pager_parameters;
        }
        
        my $pager = $pager_class->new(
            query => $self->query,
            unpaged_url => $self->filtered_unpaged_url,
            per_page => $self->per_page,
            per_window => $self->per_window,
            order => $self->order || $self->default_order,
            item_filter => $item_filter,
            items_preload => $items_preload,
            date_column => $self->date_column,
            date_method => $self->date_method,
            %$additional_parameters,
        );
        $pager->set_params_by_req({reftime => $self->reftime});
        
        $pager;
    };
}

# ------ Lists ------

sub items {
    my $self = shift;
    return $self->{_items} ||= do {
        my $pager = $self->pager;
        my $list = $pager->items;
        unless ($pager->can('is_timed') and $pager->is_timed) {
            if ($self->can('items_preload')) {
                $self->items_preload($list);
            }
            if ($self->can('item_filter')) {
                $list = $list->grep(sub { $self->item_filter($_) });
            }
        }
        $list;
    };
}

1;
