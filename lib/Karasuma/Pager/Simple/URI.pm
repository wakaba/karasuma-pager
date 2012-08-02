package Karasuma::Pager::Simple::URI;
use strict;
use warnings;
use base qw(Karasuma::Pager);
use List::Rubyish;
use POSIX;
use URI;

sub is_finite_list { 1 }

__PACKAGE__->mk_accessors(qw(
    per_page
    page
    offset
    all_items
    uri
));

sub new {
    my $class = shift;
    my @args = ref $_[0] eq 'HASH' ? @$_[0] : @_;
    my $self = $class->SUPER::new(@args);
    $self->{page} = ($self->{page} || 1) + 0 || 1;
    $self->{page} = 1 if $self->{page} =~ /[^0-9]/;
    $self->per_page($self->per_page || 10);
    return $self;
}

sub items : Caches {
    my $self = shift;
    my $start = $self->{offset} || $self->per_page * ($self->page - 1);
    my $end   = $start + $self->per_page - 1;
    return List::Rubyish->new unless $self->all_items;
    return $self->all_items->slice($start, $end);
}

sub count : Caches {
    my $self = shift;
    return 0 unless $self->all_items;
    return $self->all_items->size;
}

sub has_prev : Caches {
    my $self = shift;
    return $self->page > 1;
}

sub has_next : Caches {
    my $self = shift;
    return $self->page * $self->per_page < $self->count;
}

sub total_pages : Caches {
    my $self = shift;
    return ((ceil $self->count / $self->per_page) || 1);
}

sub page_uri {
    my $self = shift;
    my $page = shift || 1;
    my $uri = $self->uri;
    $uri = UNIVERSAL::isa($uri, 'URI') ? $uri : URI->new($uri);
    $uri = $uri->clone;

    my %params;
    my @query_form = map { utf8::downgrade($_, 1); $_ } $uri->query_form;
    while (my ($key, $value) = splice @query_form, 0, 2) {
        if (ref $params{$key} eq 'ARRAY') {
            push @{$params{$key}}, $value;
        } elsif (exists $params{$key}) {
            $params{$key} = [$params{$key}, $value];
        } else {
            $params{$key} = $value;
        }
    }
    $params{page} = $page;

    my $params = []; 
    foreach (sort keys %params) {
        push @$params, $_ => $params{$_};
    }

    $uri->query_form($params);

    my $path = URI->new($uri->path_query);
    $path;
}

sub next {
    my $self = shift;
    my $class = ref $self;
    return unless $self->has_next;
    $self->page_uri($self->page + 1);
}

sub prev {
    my $self = shift;
    my $class = ref $self;
    return unless $self->has_prev;
    $self->page_uri($self->page - 1);
}

__PACKAGE__->cache_methods;

1;
