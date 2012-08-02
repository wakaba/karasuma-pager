package Karasuma::Pager::Timed::HasRecordsQuery;
use strict;
use warnings;
use base qw(Karasuma::Pager::Timed::HasMoCoQuery);
use Karasuma::Pager::Util::SQL qw(merge_where);

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
    $query->where = $where;
    if ($self->reference_type eq 'before') {
        if ($self->order eq 'asc') {
            $query->order = $query->reverse_order;
        }
    } else {
        if ($self->order eq 'desc') {
            $query->order = $query->reverse_order;
        }
    }
    return $query;
}

sub window_items : Caches {
    my $self = shift;
    my $list = $self->window_query->search(
        offset => $self->reference_offset,
        limit => $self->per_window,
    );
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

__PACKAGE__->cache_methods;

1;
