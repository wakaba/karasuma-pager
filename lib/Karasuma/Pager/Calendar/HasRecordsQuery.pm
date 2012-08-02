package Karasuma::Pager::Calendar::HasRecordsQuery;
use strict;
use warnings;
use base qw(Karasuma::Pager::Calendar::HasMoCoQuery);
use Karasuma::Pager::Util::SQL qw(merge_where);

sub modify_query {
    my ($self, $query) = @_;
    my $where = merge_where $query->where, $self->date_as_where;
    $query->where = $where;
    return $query;
}

sub _get_has_data_in_days {
    my $self = shift;
    return if $self->{has_data_in_day};
    my $q = $self->query->clone;
    merge_where $q->where, $self->date_as_where_month;
    bless $q, 'DBIx::MoCo::Query';
    my $created_on = $self->created_on_column || 'created_on';
    # If timezone definition changes between the beginning and end of
    # the month (e.g. switched to DST), this would not work well...
    require DateTime::TimeZone;
    my $diff = DateTime::TimeZone->new(name => $self->locale_tz)->offset_for_datetime($self->date_as_datetime);
    $q->field(sprintf 'DISTINCT DATE(`' . $created_on . '` + INTERVAL %s SECOND) AS day', $diff); # !!! SQL injection unsafe !!!
    $q->search(offset => 0, limit => 400)->each(sub {
        $self->{has_data_in_day}->{$_->{day}} = 1;
    });
}

1;
