#!/usr/bin/perl

use strict;

use Data::Dumper;
use GD;
use Getopt::Long ;
use File::Copy;
use File::Path;

my %options = ();
GetOptions (\%options,'input-dir=s','input-file=s', 'output-dir=s', 'quality=i', 'japanese|j','help|h','quiet|q') or die ;
print_help() if exists $options{'help'} ; # affiche le message avec les options dispo
die "You can't use --input-dir and --input-file at the same time" if exists $options{'input-dir'} && exists $options{'input-file'};

# default values
$options{'output-dir'} 	||= 'split';
$options{'quality'} 	||= 90 ;

# japanese style or occidentale style
my $left_side_sufixe = '1-left';
my $right_side_sufixe = '2-right';
if (exists $options{'japanese'}) {
	$left_side_sufixe = '2-left';
	$right_side_sufixe = '1-right';
}


# split only one image
if (exists $options{'input-file'} && length($options{'input-file'})>0) {
	die "Image '".$options{'input-file'}."' don't exist " if !-e $options{'input-file'};
	die "Image name '".$options{'input-file'}."' is not an image" if !filename_is_image($options{'input-file'});

	if (!-d $options{'output-dir'}) { mkpath($options{'output-dir'}) or die "Unable to create dir '".$options{'output-dir'}."' ($!)"; }

	my $filename_without_ext = $options{'input-file'} ;
	$filename_without_ext =~ s/\.(?:jpe?g|gif|png|tiff?)$//i;
	split_image($options{'input-file'}, $options{'output-dir'}."/${filename_without_ext}-$left_side_sufixe", $options{'output-dir'}."/${filename_without_ext}-$right_side_sufixe");

# split a directory
} elsif (exists $options{'input-dir'} && length($options{'input-dir'})>0) {
	my $output_dir = $options{'output-dir'}.'/'.$options{'input-dir'};
	if (!-d $output_dir) { mkpath($output_dir) or die "Unable to create dir $output_dir ($!)"; }

	opendir(DIR,$options{'input-dir'}) or die "Unable to open directory ".$options{'input-dir'}." ($!)";
	while(readdir(DIR)) {
		next if $_ eq '.' || $_ eq '..' || -d $options{'input-dir'}."/$_";
		warn "Image name '$_' is not an image" if !filename_is_image($_);

		my $filename_without_ext = $_;
		$filename_without_ext =~ s/\.(?:jpe?g|gif|png|tiff?)$//i;
		split_image($options{'input-dir'}."/$_", "$output_dir/${filename_without_ext}-$left_side_sufixe", "$output_dir/${filename_without_ext}-$right_side_sufixe");
	}
	closedir(DIR);

} else {
	die "Unable to understand what to do";
}



######################################################################################################
sub split_image($$$) {
	my ($filename, $left_name, $right_name) = @_;
	my $src_image = GD::Image->new($filename) or die "Unable to read image '$filename'";

	# get image width
	my $width  = $src_image->width;
	my $height = $src_image->height;

	# probably a double page
	if ($width > $height) {
		print "[+] Split '$filename'\n" unless $options{'quiet'};
		
		# create output obj
		my 	$out_image = GD::Image->new($width / 2 , $height);

		# copy left side
		$out_image->copy($src_image, 0, 0, 0, 0, $width / 2, $height); # left half image
		save_jpeg($out_image,  $left_name);

		# copy right side
		$out_image->copy($src_image, 0, 0, $width / 2, 0, $width / 2, $height); # right half image
		save_jpeg($out_image,  $right_name);

	# don't do anything, just copy the image
	} else {
		print "[ ] Skip  '$filename'\n" unless $options{'quiet'};

		$left_name =~  s/-left$//i; #$options{input-dir}/split/${filename}-left
		copy($filename,"${left_name}.jpg") or warn "Unable to copy $filename ($!)";
	}
}

sub filename_is_image($) {
	my ($filename) = shift;
	return $filename =~ /\.(?:jpe?g|gif|png|tiff?)$/i;
}

sub save_jpeg($$) {
	my ($gd_obj,$filename) = @_;
	
	$filename .= '.jpg' if $filename !~ /\.jpe?g$/i; # add .jpg if needed
	open (OUTPUT,"+>$filename") or die "Unable to save JPEG $filename ($!)";
	binmode OUTPUT;
	print OUTPUT $gd_obj->jpeg($options{'quality'});
	close OUTPUT;
}

sub print_help {
	print <<EOT ;
--input-dir=dirname		Split all files in a directory
--input-file=filename	Split only one file
--output-dir=dirname 	Directory where the splited file are saved (default is 'split')
--quality=x 			JPEG output quality (default is 90)
--japanese -j			Invert left and right side
--quiet -q 				Don't print anything
--help -h				Display this message

EOT
	exit;
}