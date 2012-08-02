package Karasuma::Pager::QueryOffset::MoCo;
use strict;
use warnings;
use base qw(Karasuma::Pager);
use List::Rubyish;
use POSIX qw/ceil/;
use Carp;
use URI;
use URI::QueryParam;
use DateTime::Format::MySQL;
use Karasuma::Pager::Util::SQL;

sub is_query_offset { 1 }

__PACKAGE__->mk_accessors(qw(
    per_page uri pages_in_range query page_param fragment max_page
    last_page_by_default smart_default_page
    count_cache_key_suffix
    since duration created_on_column
));

sub default_per_page { 30 }

sub new {
    my $class = shift;
    my @args = ref $_[0] eq 'HASH' ? @$_[0] : @_;
    @args % 2 and croak __PACKAGE__ . ': You gave me an odd number of parameters to new()';
    my $self = $class->SUPER::new({ @args });
       $self->uri(UNIVERSAL::isa($self->uri, 'URI') ? $self->uri : URI->new(($self->uri || '').''));
       $self->page($self->page || 1);
       $self->per_page($self->per_page || $class->default_per_page);
       $self->page_param($self->page_param || 'page');

       $self->created_on_column($self->created_on_column || 'created_on');

    my $query = $self->query;
    if ($query) {
        my $since = $self->since;
        if ($since) {
            my $duration = $self->duration;
            my $until;
            if ($duration) {
                if ($duration =~ /^([0-9]+)([smhdwMy])$/) {
                    my $unit = {
                        s => 'seconds',
                        m => 'minutes',
                        h => 'hours',
                        d => 'days',
                        w => 'weeks',
                        M => 'months',
                        y => 'years',
                    }->{$2};
                    $until = $since->clone->add($unit => $1);
                }
            }
            if ($until) {
                $query->{where}->{$self->created_on_column} = {
                    '>', DateTime::Format::MySQL->format_datetime($since),
                    '<=', DateTime::Format::MySQL->format_datetime($until),
                };
            } else {
                $query->{where}->{$self->created_on_column} = {
                    ">" => DateTime::Format::MySQL->format_datetime($since),
                };
            }
        }
    }

    $self;
}

sub page {
    my $self = shift;
    if (@_) {
        $self->{page} = shift;
    }
    $self->{page} || ($self->last_page_by_default ? $self->total_pages || 1 : 1);
}

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
    $self->{_items} = $self->query
        ? ($self->last_page_by_default and $self->query->can('reverse_search'))
            ? $self->query->reverse_search($offset, $limit)
            : $self->query->search($offset, $limit)
        : List::Rubyish->new;
}

sub offset {
    my $self = shift;
    return $self->{offset} || ($self->page - 1) * $self->per_page;
}

sub count {
    my $self = shift;
    return $self->{_count} if exists $self->{_count};
    $self->{_count} = $self->_postprocess_count('_count');
}

# 個数をキャッシュしたいときなどに子クラスで上書きする
sub _postprocess_count {
    my ($self, $method) = @_;
    return $self->$method;
}

sub _count {
    my $self = shift;
    $self->query && $self->query->count || 0;
}

sub has_prev {
    my $self = shift;
    $self->page > 1;
}

sub has_next {
    my $self = shift;
    my $class = ref $self;

    return $self->page * $self->per_page < $self->count;
    #($self->page - 1) * $self->per_page + $self->items->size < $self->count;
}

sub total_pages {
    my $self = shift;
    ceil $self->count / $self->per_page;
}

sub next_of {
    my $self = shift;
    my $item = shift or return;
    my ($key, $dir) = $self->query->order =~ /(.+) (DESC|ASC)$/ or carp sprintf 'Cannot handle order "%s"', $self->query->order;
    my ($param_key) = $key =~ /([^.]+)$/;

    my $extra_item;
    if (!grep { $_ eq $param_key } @{$item->columns} || $self->query->model->table ne $item->table) {
        $extra_item = (ref $self->query)->new(
            %{$self->query},
            field => "$key AS $param_key",
            where => merge_where($self->query->where, $item->unique_where),
            order => undef,
            group => undef,
        )->find;
    }

    (ref $self->query)->new(
        %{$self->query},
        where => merge_where(
            $self->query->where,
            { $key => { $dir eq 'DESC' ? '<' : '>', $extra_item ? $extra_item->{$param_key} : $item->param($param_key) } }
        ),
    )->find;
}

sub prev_of {
    my $self = shift;
    my $item = shift or return;
    my ($key, $dir) = $self->query->order =~ /(.+) (DESC|ASC)$/ or carp sprintf 'Cannot handle order "%s"', $self->query->order;
    my ($param_key) = $key =~ /([^.]+)$/;

    my $extra_item;
    if (not grep { $_ eq $param_key } @{$item->columns} or $self->query->model->table ne $item->table) {
        $extra_item = (ref $self->query)->new(
            %{$self->query},
            field => "$key AS $param_key",
            where => merge_where($self->query->where, $item->unique_where),
            order => undef,
            group => undef,
        )->find;
    }

    (ref $self->query)->new(
        %{$self->query},
        order  => $key . ' ' . ($dir eq 'DESC' ? 'ASC' : 'DESC'),
        where => merge_where(
            $self->query->where,
            { $key => { $dir eq 'DESC' ? '>' : '<', $extra_item ? $extra_item->{$param_key} : $item->param($param_key) } }
        ),
    )->find;
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

    if ($page > 1 or
        (($self->last_page_by_default or $self->smart_default_page) and
         $page > 0)) {
        $params{$self->page_param} = $page;
    } else {
        delete $params{$self->page_param};
    }

    my $params = []; # リファレンスでないとqueryにゴミが残る場合あり
    foreach (sort keys %params) {
        push @$params, $_ => $params{$_};
    }

    $uri->query_form($params);

    my $path = URI->new($uri->path_query);
       $path->fragment($uri->fragment || $self->fragment);
    $path;
}

sub prev {
    my $self = shift;
    my $class = ref $self;
    return unless $self->has_prev;
    $self->page_uri($self->page - 1);
}

sub next {
    my $self = shift;
    my $class = ref $self;
    return unless $self->has_next;
    $self->page_uri($self->page + 1);
}

sub first {
    my $self = shift;
    my $class = ref $self;
    $self->page_uri(1);
}

sub last {
    my $self = shift;
    my $class = ref $self;
    $self->page_uri($self->total_pages);
}

sub is_required {
    my $self = shift;
    !! ($self->has_next || $self->has_prev);
}

sub range {
    my $self = shift;
    my $pages = $self->pages_in_range || 10;
    my $startpage = $self->page - int($pages / 2);
       $startpage = 1 if $startpage < 1;
    my $endpage   = $startpage + $pages - 1;
       $endpage   = $self->total_pages if $endpage > $self->total_pages;
    return [
        map {
            {
                page => $_,
                uri  => $self->page_uri($_),
            }
        } ($startpage .. $endpage)
    ];
}

1;
