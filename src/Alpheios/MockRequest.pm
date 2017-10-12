package MockRequest;


sub new {
    my $class = shift;
    my $args = shift;
    my $self = {
        _words => $args
    };
    bless $self, $class;
    return $self;
}

sub args {
    my $self = shift;
    return
        join '&',
        map { "word=$_"}
        split /,/, $self->{_words};
}

sub content_type {
    # noop
}


1;
