package DBICx::MaterializedPath;
use warnings;
use strict;
use parent "DBIx::Class";

our $VERSION = "0.01_01";

__PACKAGE__->mk_classdata( parent_column => "parent" );
__PACKAGE__->mk_classdata( path_column => "materialized_path" );
__PACKAGE__->mk_classdata( path_separator => "." );
__PACKAGE__->mk_classdata( max_depth => 500 );

# Max depth setting? See notes on sanity check inline below.

sub _compute_ancestors :method {
    my ( $self, @ancestors ) = @_;
    my $parent_column = $self->parent_column;
    my $parent = $self->$parent_column;
    return @ancestors unless $parent;
    unshift @ancestors, $parent;
    die "Circular lineage loop in $self suspected!" if @ancestors > $self->max_depth;
    $parent->_compute_ancestors(@ancestors);
}

sub ancestors :method {
    my $self = shift;
    my ( $pk_name ) = $self->primary_columns;
    my $path_column = $self->path_column;
    my @path = $self->_nodelist;
    pop @path;
    return unless @path;
    $self->result_source
        ->resultset
        ->search({ $pk_name => { -in => \@path } },
                 { order_by => \"LENGTH($path_column)" }); # "
}

sub node_depth :method {
    scalar(+shift->_nodelist);
}

sub _nodelist :method {
    my $self = shift;
    my $path_column = $self->path_column || "";
    my $separator = quotemeta( $self->path_separator );
    split($separator, $self->$path_column || "");
}

sub root_node :method {
    my $self = shift;
    my ( $root_id ) = $self->_nodelist;
    $self->find($root_id);
}

# Note caveat, instructions about setting up children method.

# How can order_by get into this mix?
sub grandchildren {
    my ( $self, @grandkids ) = @_;
    my @children;
    if ( $self->can("children") )
    {
        @children = $self->children;
    }
    else
    {
        my $parent_column = $self->parent_column;
        @children = $self->result_source->resultset->search({ $parent_column => $self->id });
    }

    for my $kid ( @children )
    {
        push @grandkids, $kid;
        push @grandkids, $kid->grandchildren();
    }
    return @grandkids;
}

sub set_materialized_path :method {
    my $self = shift;
    my $parent_column = $self->parent_column;
    my $path_column = $self->path_column;
    my @path_parts = map { $_->id } $self->_compute_ancestors;
    push @path_parts, $self->id;
    my $materialized_path = join( $self->path_separator, @path_parts );
    $self->$path_column( $materialized_path );
    return $materialized_path; # For good measure.
}

sub insert :method {
    my $self = shift;
    $self->next::method(@_);
    $self->set_materialized_path;
    $self->update;
}

sub update :method {
    my $self = shift;
    my %to_update = $self->get_dirty_columns;
    my $parent_column = $self->parent_column;
    return $self->next::method(@_) unless $to_update{$parent_column};

    # This should be configurable as a transaction I think. 321
    my $path_column = $self->path_column;
    for my $descendent ( $self->grandchildren )
    {
        $descendent->set_materialized_path;
        $descendent->update;
    }
    $self->next::method(@_);
}

# Previous and next support here.

sub siblings :method {
    my $self = shift;
    my $parent_column = $self->parent_column;
    my $sort = [ $self->_sibling_order || $self->primary_columns ];
    $self->result_source
        ->resultset
        ->search({ $parent_column => $self->$parent_column },
                 { order_by => $sort });
} 

1;

__END__

=pod

=head1 NAME

DBICx::MaterializedPath - (Pre-alpha!) L<DBIx::Class> plugin for automatically tracking lineage paths in simple data trees.

=head1 VERSION

0.01_01

=head1 SYNOPSIS


=head1 DESCRIPTION


=head2 METHODS

=over 4

=item ancestors

=item get_root

=item grandchildren

=item node_depth

=item root_node

=item set_materialized_path

=item siblings

=back

=head2 OVERRIDDEN METHODS

=over 4

=item insert

=item update

=back

=head1 CAVEATS

If your materialized path column is insufficiently large you're going to have problems. A C<VARCHAR(255)> is only wide enough to support a tree which is 35 nodes deep if the average PK is integers in the millions. This might be fine for your usage. Just be aware path tracking is not arbitrary, it's limited to the column's width.

=head1 TO DO

=over 4

=item Better documents; obviously.

=item More tests; what else is new?

=back

=head1 CODE REPOSITORY

L<http://github.com/pangyre/p5-dbicx-materializedpath>.

=head1 SEE ALSO

I<Trees in SQL: Nested Sets and Materialized Path>, Vadim Tropashko, L<http://www.dbazine.com/oracle/or-articles/tropashko4>.

L<DBIx::Class::Ordered>, L<DBIx::Class>.

=head2 WHY NOT DBIx::Class::Ordered?

There are data sets which have implicit, or even tacit, orderingE<mdash>E<rdquo>positionE<ldquo> in L<DBIx::Class::Ordered> parlanceE<ndash> in the data already. Published articles, for example, will be naturally ordered chronologically. Additional position tracking becomes complex and redundant in this kind of case. You can even run into cases where both types of ordering are necessary like a collection of dictionaries. Each dictionary's terms are ordered alphabetically while each term's definitions would be ordered by a position set at editorial discretion.

=head1 AUTHOR

Ashley Pond V E<middot> ashley.pond.v@gmail.com E<middot> L<http://pangyresoft.com>.

=head1 LICENSE

You may redistribute and modify this software under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

Because this software is licensed free of charge, there is no warranty
for the software, to the extent permitted by applicable law. Except when
otherwise stated in writing the copyright holders and other parties
provide the software "as is" without warranty of any kind, either
expressed or implied, including, but not limited to, the implied
warranties of merchantability and fitness for a particular purpose. The
entire risk as to the quality and performance of the software is with
you. Should the software prove defective, you assume the cost of all
necessary servicing, repair, or correction.

In no event unless required by applicable law or agreed to in writing
will any copyright holder, or any other party who may modify or
redistribute the software as permitted by the above license, be
liable to you for damages, including any general, special, incidental,
or consequential damages arising out of the use or inability to use
the software (including but not limited to loss of data or data being
rendered inaccurate or losses sustained by you or third parties or a
failure of the software to operate with any other software), even if
such holder or other party has been advised of the possibility of
such damages.

=cut
