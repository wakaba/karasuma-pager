package Karasuma::Pager::Calendar::HasMoCoQuery;
use strict;
use warnings;
use base qw(Karasuma::Pager::Calendar::Basic);
use Karasuma::Pager::Util::SQL qw(merge_where);
use DateTime::TimeZone;
use DateTime::Format::MySQL;

# !!! |created_on_column| is SQL injection UNSAFE !!!
__PACKAGE__->mk_accessors(qw(created_on_column query));

sub date_as_where {
    my $self = shift;
    my $created_on = $self->created_on_column || 'created_on';
    my $d1 = $self->start_as_datetime->clone;
    $d1->set_time_zone('UTC');
    my $d2 = $self->end_as_datetime;
    $d2->set_time_zone('UTC');
    return {-and => [
        {$created_on => {'>=', DateTime::Format::MySQL->format_datetime($d1)}},
        {$created_on => {'<=', DateTime::Format::MySQL->format_datetime($d2)}},
    ]};
}

sub date_as_where_month {
    my $self = shift;
    my $created_on = $self->created_on_column || 'created_on';
    my $d1 = $self->start_as_datetime->clone;
    $d1->set_day(1);
    $d1->set_time_zone('UTC');
    my $d2 = $d1->clone;
    $d2->add(months => 1);
    $d2->subtract(seconds => 1);
    $d2->set_time_zone('UTC');
    return {-and => [
        {$created_on => {'>=', DateTime::Format::MySQL->format_datetime($d1)}},
        {$created_on => {'<=', DateTime::Format::MySQL->format_datetime($d2)}},
    ]};
}

sub modify_query {
    my ($self, $query) = @_;
    my $where = merge_where $query->where, $self->date_as_where;
    $query->where($where);
    return $query;
}

sub query_class {
    return 'DBIx::MoCo::Query';
}

sub _get_has_data_in_days {
    my $self = shift;
    return if $self->{has_data_in_day};
    my $q = $self->query->clone;
    merge_where $q->where, $self->date_as_where_month;
    bless $q, $self->query_class;
    my $created_on = $self->created_on_column || 'created_on';
    # If timezone definition changes between the beginning and end of
    # the month (e.g. switched to DST), this would not work well...
    my $diff = DateTime::TimeZone->new(name => $self->locale_tz)->offset_for_datetime($self->date_as_datetime);
    $q->field(sprintf 'DISTINCT DATE(`' . $created_on . '` + INTERVAL %s SECOND) AS day', $diff); # !!! SQL injection unsafe !!!
    $q->search(0, 400)->each(sub {
        $self->{has_data_in_day}->{$_->{day}} = 1;
    });
}

sub has_data_in_day {
    my $self = shift;
    my $day = shift or return 0;
    $self->_get_has_data_in_days;
    my $dt = $self->date_as_datetime->clone;
    $dt->set_day($day);
    return $self->{has_data_in_day}->{$dt->ymd('-')};
}

1;
