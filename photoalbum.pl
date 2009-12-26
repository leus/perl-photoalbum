#!/usr/bin/perl
use strict;
use warnings;
use Switch 'Perl6';

use File::Find;
use PDF::Create;

sub get_images {
	my @ret;

	find({wanted => sub {
		if (/\.jpg/) {
			push @ret, $File::Find::name;
		}
	}, follow => 1}, './JPEG');
	return @ret;
}

sub scale {
	my ($w, $h, $default_width) = @_;
	my $ratio = $h / $w;
	return ($default_width, int($default_width * $ratio));
}

my $pagesize = 'Letter';
my $filename = 'album.pdf';
my $author = 'Leonardo Herrera';
my $title = '2009';
my $pdf = new PDF::Create(
	'filename'     => $filename,
	'Version'      => 1.2,
	'PageMode'     => 'UseOutlines',
	'Author'       => $author,
	'Title'        => $title,
	'CreationDate' => [ localtime ],
);
my $psz = $pdf->get_page_size($pagesize);

print "psz: ", join(', ', @$psz), "\n";
my $root = $pdf->new_page('MediaBox' => $psz);

my @images = (get_images)[0..20];
my $page = $root->new_page;
my ($accum, $y) = (0, 0);
my ($pw, $ph) = (@$psz)[2,3];

sub decide_layout {
	my $n = scalar @_;
	given ($n) {
		when 1 { return (1, 1); }
		when 2 { return (1, 2); }
		when 3 { return (1, 3); }
		when 4 { return (2, 2); }
		when 5 { return (2, 3); }
		when 6 { return (2, 3); }
		when 7 { return (2, 4); }
		when 8 { return (2, 4); }
		when 9 { return (3, 3); }
		when 12 { return (3, 4); }
		default { die "Wrong layout number: $_"; }
	}
}


sub max {
	my $max;
	foreach (@_) { $max = $_ unless $max && $max > $_; }
	return $max;
}


sub fit_img {
	my ($img, $slot_w, $slot_h) = @_;

	# aspect ratio
	my $ratio = $$img{height} / $$img{width};
	print "ratio: $ratio\n";
	return ($slot_w, int($slot_h * $ratio));
}


sub place_img {
	my ($page, $img, $w, $h, $x, $y) = @_;

	my $xscale = $w / $$img{width};

	print "Placing:  xpos => $x, ypos => $y\n";

	$page->image(image => $img,
		xpos => $x,
		ypos => $y,
		xscale => $xscale,
		yscale => $xscale,
	);
}

sub layout {
	my ($page, $pw, $ph, @images) = @_;
	my $max_width = max map { $$_{width} } @images;
	my $max_height = max map { $$_{height} } @images;
	my ($w, $h) = decide_layout(@images);
	my ($slot_w, $slot_h) = ($pw / $w, $ph / $h);

	# margins
	print "max: $max_width : $max_height - grid: $w x $h",
	    " ($slot_w x $slot_h)\n";
	my $margin = 20;

	for (my $j = 0; $j < $h; $j++) {
		for (my $i = 0; $i < $w; $i++) {
			my $im = shift @images;
			my ($w, $h) = fit_img($im, $slot_w, $slot_h);
			print "orig: $$im{width} x $$im{height} - $w x $h\n";
			place_img($page, $im, $w, $h, $i * $slot_w, $j * $slot_h);
		}
	}
}

while (@images) {
	my $n = 6;
	my @batch = map { $pdf->image($_) } splice @images, 0, $n;
	my $page = $root->new_page;

	layout($page, $pw, $ph, @batch);
}

$pdf->close;
