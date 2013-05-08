use v5.14;
use utf8;      # so literals and identifiers can be in UTF-8
use strict;
use warnings;
use warnings  qw(FATAL utf8);    # fatalize encoding glitches
use open      qw(:std :utf8);    # undeclared streams in UTF-8
use Data::Dumper;
use File::Slurp;
use HTML::Strip;
use Try::Tiny;

use Lucy::Analysis::PolyAnalyzer;
use Lucy::Index::Indexer;
use Lucy::Plan::Schema;
use Lucy::Plan::FullTextType;
use Lucy::Search::IndexSearcher;

my $index = 'html.idx';



my $docs = get_docs();
make_index( $index, $docs );
search($index );

sub get_docs {#{{{
    my $kandi = HTML::Strip->new();
    my $docs = {};
    foreach my $f(glob("*.html")) {
        my $html = read_file($f);
        my $contents = $kandi->parse( $html );
        $kandi->eof;
        $docs->{$f} = $contents;
    }
    return $docs;
}#}}}
sub make_index {#{{{
    my $index = shift;
    my $docs  = shift;

    # Create a Schema which defines index fields.
    my $schema = Lucy::Plan::Schema->new;
    my $polyanalyzer = Lucy::Analysis::PolyAnalyzer->new(
        language => 'en',
    );
    my $type = Lucy::Plan::FullTextType->new(
        analyzer => $polyanalyzer,
    );
    $schema->spec_field( name => 'title',   type => $type );
    $schema->spec_field( name => 'content', type => $type );
    
    # Create the index and add documents.
    my $indexer = Lucy::Index::Indexer->new(
        schema => $schema,  
        index  => $index,
        create => 1,
        truncate => 1,  # if index already exists with contents, trash them before adding more.
    );

    while ( my ( $filename, $content ) = each %$docs ) {
        $indexer->add_doc({
            title   => $filename,
            content => $content,
        });
    }
    $indexer->commit;
}#}}}
sub search {#{{{
    my $index = shift;

    my $searcher = Lucy::Search::IndexSearcher->new(
        index => $index
    );
    my $hits = $searcher->hits( query => "gogopuffs" );
    while ( my $hit = $hits->next ) {
        say "$hit->{title} ($hit->{'content'})";
        say "--------------------------------------------";
    }
}#}}}

