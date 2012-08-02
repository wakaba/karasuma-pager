package Karasuma::Pager::Timed::HasMoCoQuery;
use strict;
use warnings;
use base qw(Karasuma::Pager::Timed::Basic);
use Karasuma::Pager::Util::SQL qw(merge_where);
use List::Rubyish;
use DateTime;
use DateTime::Format::MySQL;

__PACKAGE__->mk_accessors(qw(query items_preload));

sub date_column {
    my $self = shift;
    if (@_) {
        $self->{date_column} = shift;
    }
    return $self->{date_column} || 'created_on';
}

sub date_method {
    my $self = shift;
    if (@_) {
        $self->{date_method} = shift;
    }
    return $self->{date_method} || $self->date_column;
}

sub reference_time_as_mysql_datetime : Caches {
    my $self = shift;
    my $time = $self->reference_time or return undef;
    return eval { DateTime::Format::MySQL->format_datetime(DateTime->from_epoch(epoch => $time)) } || undef;
}

sub window_query : Caches {
    my $self = shift;
    my $query = $self->query->clone;
    my $column = $self->date_column;
    my $dt = $self->reference_time_as_mysql_datetime;
    my $where = $dt ? merge_where $query->where, {
        $column => {
            $self->reference_type eq 'before' ? '<=' : '>=',
            $dt,
        },
    } : $query->where;
    $query->where($where);
    if ($self->reference_type eq 'before') {
        if ($self->order eq 'asc') {
            $query->order($query->reverse_order);
        }
    } else {
        if ($self->order eq 'desc') {
            $query->order($query->reverse_order);
        }
    }
    return $query;
}

sub window_items : Caches {
    my $self = shift;
    my $list = $self->window_query->search(
        $self->reference_offset,
        $self->per_window,
    );

    if ($list->size == 0 && $self->reference_type eq 'before') {
        $list = $self->window_fallback_items;
    }

    my $items_preload = $self->items_preload;
    if ($items_preload) {
        if (ref $items_preload eq 'HASH') {
            my $object = $items_preload->{object};
            if ($object) {
                my $method = $items_preload->{method};
                $items_preload = sub { $object->$method($_[0]) };
            } else {
                $items_preload = sub { };
            }
        }
        $items_preload->($list);
    }
    return $list;
}

sub window_fallback_items {
    return List::Rubyish->new;
}

sub get_time_from_item {
    my ($self, $item) = @_;
    my $method = $self->date_method;
    my $value = $item->$method or return undef;
    return $value->epoch;
}

__PACKAGE__->cache_methods;

1;
