package Karasuma::Pager::Util::SQL;
use strict;
use warnings;
use SQL::Abstract;
use Exporter::Lite;

our @EXPORT = qw(merge_where);

my $sqla = SQL::Abstract->new;
sub merge_where {
    my $where = [];
    foreach my $w (@_) {
        next unless $w;
        $w = [$w] unless ref $w;
        if (ref $w eq 'ARRAY') {
            $where->[0] = join ' AND ', $where->[0] || (), $w->[0];
            push @$where, @$w[1..$#$w];
        } elsif (ref $w eq 'HASH') {
            my ($stmt, @bind) = $sqla->_recurse_where($w);
            $where->[0] = join ' AND ', $where->[0] || (), $stmt;
            push @$where, @bind;
            #while (my ($key, $value) = each %$w) {
            #    $where->[0] = join ' AND ', $where->[0] || (), $key;
            #    push @$where, $value;
            #}
        }
    }
    $where;
}

1;
