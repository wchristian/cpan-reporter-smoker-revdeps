#!/usr/bin/perl

use 5.10.1;
use strict;
use warnings;

use Time::HiRes  1.97 ();
use CPANDB ();
use CPAN::Reporter::History 'have_tested';
use Capture::Tiny 'capture';
use Term::ProgressBar::Simple;
use File::Slurp 'read_dir';


run();

exit;

sub run {

    my %args = ( perl => '', archname => '', osvers => '' );
    
	say "### finding non-PASS dists from cpanreporter db";
    my @results = map { have_tested( grade => $_, %args ) } qw( FAIL NA UNKNOWN );
    
	say "### loading CPANDB";
    load_cpandb( 1 );
	
	say "### loading dist objects by name, discarding those without CPANDB entries";
	my $dist_bar = new_prog_bar( scalar @results );
	my @dists = map get_dist( $dist_bar, $_ ), @results;
	
	say "### filtering dists that are already graphed";
	@dists = filter_done_dists( @dists );
	
	say "### graphing dists";
	my $graph_bar = new_prog_bar( scalar @dists );
    do_both( $graph_bar, $_ ) for @dists;
    
    return;
}

sub filter_done_dists {
	my ( @dists ) = @_;
	
	my @files = read_dir( "graphs" );
	$_ =~ s/^\d{5}-// for @files;
	$_ =~ s/.png$// for @files;
	my %files = map { $_ => 1 } @files;
	
	@dists = grep { !$files{$_->[0]} } @dists;
	
	return @dists;
}

sub do_both {
	my ( $bar, $dist ) = @_;
	
    my $graph = get_rev_dep_graph( $dist );
	print_graph( $graph );
	
	$bar->increment;
	
	return;
}

sub new_prog_bar {
	my ( $count, $name ) = @_;
	
	$name ||= $count;
    
	my $params = { name => $name, ETA => 'linear', max_update_rate => '0.00001' };
	$params->{count} = $count;
	return Term::ProgressBar::Simple->new( $params );
}

sub load_cpandb {
	my ( $VERBOSE ) = @_;
	
	$VERBOSE ||= 0;

	CPANDB->import( { show_progress => $VERBOSE } );
	
	return;
}

sub print_graph {
	my ( $graph ) = @_;
	
	my $node_count = sprintf "%05d", scalar @{ $graph->{NODELIST} };
	
	my $graph_name = "graphs/$node_count-$graph->{NODELIST}[0].png";
	# silence warnings
	capture {
		$graph->as_png( $graph_name );
	};
	
	return;
}

sub get_rev_dep_graph {
	my ( $dist ) = @_;
	
	my $graph = $dist->dependants_graphviz( rankdir => 1 );
	
	return $graph;
}

sub get_dist {
	my ( $bar, $raw_dist ) = @_;
    
	my $name = $raw_dist->{dist};
    $name =~ s/-[^-]+$//;

	my $dist = eval {
		CPANDB->distribution($name)
	};
	
	$bar->increment;
	
	return if !$dist;
	return $dist;
}
