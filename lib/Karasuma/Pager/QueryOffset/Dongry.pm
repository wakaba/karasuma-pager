package Karasuma::Pager::QueryOffset::Dongry;
use strict;
use warnings;
use base qw(Karasuma::Pager::QueryOffset::MoCo);
use List::Rubyish;

sub items {
    my $self = shift;
    return $self->{_items} if exists $self->{_items};
    my $max_page = $self->max_page;
    if ($max_page) {
        if ($self->page > $max_page) {
            return $self->{_items} = List::Rubyish->new;
        }
    }
    my ($offset, $limit) = ($self->offset, $self->per_page);
    $self->{_items} = $self->query # $self->last_page_by_default is not supported
        ? $self->query->find_all(offset => $offset, limit => $limit)
        : List::Rubyish->new;
}

1;
