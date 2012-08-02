package Karasuma::Pager;
use strict;
use warnings;
use base qw(Object::CachesMethod);

sub new {
    my $class = shift;
    if (@_ == 1 and ref $_[0] eq 'HASH') {
        return bless $_[0], $class;
    } else {
        return bless {@_}, $class;
    }
}

sub is_finite_list { 0 }
sub is_query_offset { 0 }
sub is_timed { 0 }
sub is_calendar { 0 }

sub mk_accessors {
    my $class = shift;
    for my $method (@_) {
        eval sprintf q{
            sub %s::%s {
                if (@_ > 1) {
                    $_[0]->{%s} = $_[1];
                }
                return $_[0]->{%s};
            }
            1;
        }, $class, $method, $method, $method or die $@;
    }
}

1;
