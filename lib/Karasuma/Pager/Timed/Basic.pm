package Karasuma::Pager::Timed::Basic;
use strict;
use warnings;
use base qw(Karasuma::Pager);
use List::Rubyish;

sub is_timed { 1 }

sub max_reference_offset { 1000 }

sub set_params_by_req {
    my ($self, $req) = @_;
    my $ref = ref $req eq 'HASH' ? $req->{reftime} : $req->param('reftime');
    unless ($ref) {
        my $order = $self->{order} || (ref $req eq 'HASH' ? $req->{order} : $req->param('order')) || '';
        if ($order eq 'asc') {
            $self->reference_type('after');
        }
        return;
    }
    $self->reference_type($ref =~ /^-/ ? 'before' : 'after');
    $ref =~ s/^[+-]//;
    my ($reftime, $refoffset) = split /,/, $ref, 2;
    $self->reference_time($reftime);
    $self->reference_offset($refoffset);
}

sub reference_type {
    my $self = shift;
    if (@_) {
        $self->{reference_type} = shift;
    }
    my $rt = $self->{reference_type} || 'before';
    return $rt eq 'after' ? 'after' : 'before';
}

sub reference_type_as_order {
    my ($self) = @_;
    my $ref_type = $self->reference_type;
    if ($ref_type eq 'after') {
        return 'asc';
    }
    else {
        return 'desc';
    }
}

__PACKAGE__->mk_accessors(qw(default_reference_time));

sub reference_time {
    my $self = shift;
    if (@_) {
        $self->{reference_time} = shift;
    }
    return $self->default_reference_time || undef
        unless defined $self->{reference_time};
    my $time = ($self->{reference_time} || $self->default_reference_time || 0) + 0;
    return $time;
}

sub reference_time_as_datetime {
    my ($self) = @_;
    my $time = $self->reference_time or return undef;
    require DateTime;
    return DateTime->from_epoch(epoch => $time);
}

sub reference_offset {
    my $self = shift;
    if (@_) {
        $self->{reference_offset} = shift;
    }
    my $offset = int($self->{reference_offset} || 0);
    my $max = $self->max_reference_offset;
    $offset = $max if $max < $offset;
    $offset = 0 if $offset < 0;
    return $offset;
}

sub per_window {
    my $self = shift;
    if (@_) {
        $self->{per_window} = shift;
    }
    my $per_window = int($self->{per_window} || 1);
    $per_window = 1 if $per_window <= 0;
    return $per_window;
}

sub window_items : Caches {
    require Carp;
    die "not implemented", Carp::longmess();
}

sub per_page {
    my $self = shift;
    if (@_) {
        $self->{per_page} = shift;
    }
    my $per_page = int($self->{per_page} || 1);
    $per_page = 1 if $per_page <= 0;
    return $per_page;
}

__PACKAGE__->mk_accessors(qw(item_filter));

sub order {
    my $self = shift;
    if (@_) {
        $self->{order} = shift;
    }
    my $order = $self->{order} || 'desc';
    return $order eq 'desc' ? 'desc' : 'asc';
}

sub items : Caches {
    my $self = shift;
    my $items = List::Rubyish->new;
    my $relevant_items;
    my $i = 0;
    my $max_count = $self->per_page;
    my $filter = $self->item_filter;
    if ($filter) {
        if (ref $filter eq 'HASH') {
            my $method = $filter->{method};
            if ($filter->{object}) {
                my $obj = $filter->{object};
                $filter = sub { $obj->$method(@_) };
            } else {
                $filter = sub { 0 };
            }
        }
        $relevant_items = List::Rubyish->new;
        for my $item (@{$self->window_items}) {
            unless ($filter->($item)) {
                $relevant_items->push($item);
                next;
            } else {
                if ($i >= $max_count) {
                    last;
                }
            }
            $items->push($item);
            $relevant_items->push($item);
            $i++;
        }
    } else {
        for my $item (@{$self->window_items}) {
            $items->push($item);
            $i++;
            if ($i >= $max_count) {
                last;
            }
        }
    }

    if ($self->reference_type eq 'before') {
        if ($self->order eq 'asc') {
            $relevant_items = ($relevant_items or $items)->reverse;
            $items = $items->reverse;
        } else {
            $relevant_items ||= $items;
        }
    } else {
        if ($self->order eq 'desc') {
            $relevant_items = ($relevant_items or $items)->reverse;
            $items = $items->reverse;
        } else {
            $relevant_items ||= $items;
        }
    }

    $self->{relevant_items} = $relevant_items;
    return $items;
}

sub relevant_items {
    my $self = shift;
    $self->items unless $self->{relevant_items};
    return $self->{relevant_items};
}

sub get_time_from_item {
    my ($self, $item) = @_;
    die "not implemented";
}

sub _older_reference {
    my $self = shift;
    $self->{older_reference_type} = 'before';
    my $items = $self->relevant_items;
    if ($items->length) {
        my $oldest;
        my $offset = 0;
        if ($self->order eq 'asc') {
            $oldest = $self->get_time_from_item($items->first);
            for (@$items) {
                if ($oldest == $self->get_time_from_item($_)) {
                    $offset++;
                } else {
                    last;
                }
            }
        } else {
            $oldest = $self->get_time_from_item($items->last);
            for (reverse @$items) {
                if ($oldest == $self->get_time_from_item($_)) {
                    $offset++;
                } else {
                    last;
                }
            }
        }
        if ($offset == $self->per_page and
            # 先へ先へと進む途中で古い方に戻ろうとするとうまく動かない
            # ことがある。
            $self->reference_time and
            $self->reference_time == $oldest) {
            $offset += $self->reference_offset;
        }
        $self->{older_reference_time} = $oldest;
        $self->{older_reference_offset} = $offset;
    } else {
        $self->{older_reference_time} = $self->reference_time;
        $self->{older_reference_offset} = $self->reference_offset;
    }
}

sub older_reference_type {
    my $self = shift;
    $self->_older_reference unless $self->{older_reference_type};
    return $self->{older_reference_type};
}

sub older_reference_time {
    my $self = shift;
    $self->_older_reference unless $self->{older_reference_type};
    return $self->{older_reference_time};
}

sub older_reference_offset {
    my $self = shift;
    $self->_older_reference unless $self->{older_reference_type};
    return $self->{older_reference_offset};
}

sub _newer_reference {
    my $self = shift;
    $self->{newer_reference_type} = 'after';
    my $items = $self->relevant_items;
    if ($items->length) {
        my $newest;
        my $offset = 0;
        if ($self->order eq 'asc') {
            $newest = $self->get_time_from_item($items->last);
            for (reverse @$items) {
                if ($newest == $self->get_time_from_item($_)) {
                    $offset++;
                } else {
                    last;
                }
            }
        } else {
            $newest = $self->get_time_from_item($items->first);
            for (@$items) {
                if ($newest == $self->get_time_from_item($_)) {
                    $offset++;
                } else {
                    last;
                }
            }
        }
        if ($offset == $self->per_page and
            $self->reference_time and
            $self->reference_time == $newest) {
            # 昔へ昔へと戻る途中で新しい方に戻ろうとするとうまく動かな
            # いことがある。
            $offset += $self->reference_offset;
        }
        $self->{newer_reference_time} = $newest;
        $self->{newer_reference_offset} = $offset;
    } else {
        $self->{newer_reference_time} = $self->reference_time;
        $self->{newer_reference_offset} = $self->reference_offset;
    }
}

sub newer_reference_type {
    my $self = shift;
    $self->_newer_reference unless $self->{newer_reference_type};
    return $self->{newer_reference_type};
}

sub newer_reference_time {
    my $self = shift;
    $self->_newer_reference unless $self->{newer_reference_type};
    return $self->{newer_reference_time};
}

sub newer_reference_offset {
    my $self = shift;
    $self->_newer_reference unless $self->{newer_reference_type};
    return $self->{newer_reference_offset};
}

# ------ URLs ------

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

sub get_url {
    my ($self, %args) = @_;
    my $u = $self->unpaged_url->clone;
    my $reftime = $args{reference_time};
    if ($reftime) {
        my $type = $args{reference_type} || 'before';
        $reftime = ($type eq 'before' ? '-' : '+') . $reftime;
        $reftime .= ',' . $args{reference_offset} if $args{reference_offset};
        $u->set_qparam(reftime => $reftime);
    }
    return $u;
}

sub older_url : Caches {
    my $self = shift;
    return $self->get_url(
        reference_type => $self->older_reference_type,
        reference_time => $self->older_reference_time,
        reference_offset => $self->older_reference_offset,
    );
}

sub newer_url : Caches {
    my $self = shift;
    return $self->get_url(
        reference_type => $self->newer_reference_type,
        reference_time => $self->newer_reference_time,
        reference_offset => $self->newer_reference_offset,
    );
}

__PACKAGE__->cache_methods;

1;
