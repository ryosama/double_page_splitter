#!/usr/bin/perl

use strict;

use GD;
use Getopt::Long ;
use File::Copy;
use File::Path;
use File::Basename;

my %options = ();
GetOptions (\%options,'input-dir=s','input-file=s', 'output-dir=s', 'quality=i', 'japanese|j','crop|c', 'help|h','quiet|q') or die ;
print_help() if exists $options{'help'} ; # display a mesasge with available options
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

	my $output_dir = $options{'output-dir'}.'/'.dirname($options{'input-file'});
	if (!-d $output_dir) { mkpath($output_dir) or die "Unable to create dir '$output_dir' ($!)"; }

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
	my $src_image = myGDimageOpen($filename);

	# get image width
	my $width  = $src_image->width;
	my $height = $src_image->height;

	# if image is wide --> probably a double page
	if ($width > $height) {
		print "[+] Split '$filename'\n" unless $options{'quiet'};
		
		# create output obj
		my $out_image = GD::Image->new($width / 2 , $height);

		# copy left side
		$out_image->copy($src_image, 0, 0, 0, 0, $width / 2, $height); # left half image
		save_jpeg($out_image, $left_name);
		crop_image($left_name) if $options{'crop'};

		# copy right side
		$out_image->copy($src_image, 0, 0, $width / 2, 0, $width / 2, $height); # right half image
		save_jpeg($out_image, $right_name);
		crop_image($right_name) if $options{'crop'};

	# don't do anything, just copy the image
	} else {
		print "[ ] Skip  '$filename'\n" unless $options{'quiet'};

		$left_name =~  s/-left$//i;
		copy($filename,"${left_name}.jpg") or warn "Unable to copy $filename ($!)";
		crop_image("${left_name}.jpg") if $options{'crop'};
	}
}


# try to crop white zone on border of the image
sub crop_image($) {
	my $filename = shift;
	my $src_image = myGDimageOpen($filename);

	# get image width
	my $width  = $src_image->width;
	my $height = $src_image->height;

	# algo :
	# draw a square of 3x3 pixel, compute average color, compare color to white with tolerance to detect if white or not !
	my $pixel_to_crop_from_bottom 	= pixel_to_crop_from_bottom($src_image);
	my $pixel_to_crop_from_top 		= pixel_to_crop_from_top($src_image);
	my $pixel_to_crop_from_right 	= pixel_to_crop_from_right($src_image);
	my $pixel_to_crop_from_left		= pixel_to_crop_from_left($src_image);
	
	# create output obj
	my $crop_image = GD::Image->new($width - $pixel_to_crop_from_right - $pixel_to_crop_from_left,
									$height - $pixel_to_crop_from_bottom - $pixel_to_crop_from_top);

	# copy left side
	$crop_image->copy($src_image, 0, 0, # destX destY
						$pixel_to_crop_from_left, # srcX
						$pixel_to_crop_from_top, # srcY
						$width - $pixel_to_crop_from_right,	# width
						$height - $pixel_to_crop_from_bottom # height
				); # crop image
	save_jpeg($crop_image, $filename);
}


sub pixel_to_crop_from_bottom($) {
	my ($image) = @_;
	my $pixel_to_crop = 0;
	my $line_is_white = 1;

	for(my $y=$image->height -1 ; $y>0 ; $y--) {
		for(my $x=0 ; $x<$image->width ; $x++) {
			if (pixel_is_white($image, $x, $y , 1, 'vertical') == 0) { # is black
				$line_is_white = 0;
				last;
			}
		}

		if (!$line_is_white) {
			last;
		} else {
			$pixel_to_crop = $image->height - $y;
		}
	}

	return $pixel_to_crop;
}


sub pixel_to_crop_from_top($) {
	my ($image) = @_;
	my $pixel_to_crop = 0;
	my $line_is_white = 1;

	for(my $y=0 ; $y<$image->height -1 ; $y++) {
		for(my $x=0 ; $x<$image->width ; $x++) {
			if (pixel_is_white($image, $x, $y , 1, 'vertical') == 0) { # is black
				$line_is_white = 0;
				last;
			}
		}

		if (!$line_is_white) {
			last;
		} else {
			$pixel_to_crop = $y +1;
		}
	}

	return $pixel_to_crop;
}


sub pixel_to_crop_from_right($) {
	my ($image) = @_;
	my $pixel_to_crop = 0;
	my $line_is_white = 1;

	for(my $x=$image->width -1 ; $x>0 ; $x--) {
		for(my $y=0 ; $y<$image->height ; $y++) {
			if (pixel_is_white($image, $x, $y , 1, 'horizontal') == 0) { # is black
				$line_is_white = 0;
				last;
			}
		}

		if (!$line_is_white) {
			last;
		} else {
			$pixel_to_crop = $image->width - $x;
		}
	}

	return $pixel_to_crop;
}


sub pixel_to_crop_from_left($) {
	my ($image) = @_;
	my $pixel_to_crop = 0;
	my $line_is_white = 1;

	for(my $x=0 ; $x<$image->width -1 ; $x++) {
		for(my $y=0 ; $y<$image->height ; $y++) {
			if (pixel_is_white($image, $x, $y , 1, 'horizontal') == 0) { # is black
				$line_is_white = 0;
				last;
			}
		}

		if (!$line_is_white) {
			last;
		} else {
			$pixel_to_crop = $x +1;
		}
	}

	return $pixel_to_crop;
}



sub pixel_is_white($$$$) {
	my ($image, $x, $y, $radius, $mode) = @_;
	$x=$radius if $x - $radius < 0;
	$y=$radius if $y - $radius < 0 ;
	$x=$image->width  - $radius -1 if $x + $radius > $image->width  -1 ;
	$y=$image->height - $radius -1 if $y + $radius > $image->height -1;

	# don't look 5% close from the border --> scanner imperfection
	if ($mode eq 'vertical') {
		my $x_close_from_border = $x * 100 / $image->width;
		if ($x_close_from_border < 5 || $x_close_from_border > 95) {
			return -2;
		}

	} elsif ($mode eq 'horizontal') {
		my $y_close_from_border = $y * 100 / $image->height;
		if ($y_close_from_border < 5 || $y_close_from_border > 95) {
			return -1;
		}
	}

	my $total_color = {'r'=>0, 'g'=>0, 'b'=>0};
	my $nb_pixel = 0;

	for(my $i=-1*$radius ; $i<=$radius ; $i++) {
		for(my $j=-1*$radius ; $j<=$radius ; $j++) {
			my $index = $image->getPixel($x + $i, $y + $j);
			my ($r,$g,$b) = $image->rgb($index);
			$total_color->{'r'} += $r;
			$total_color->{'g'} += $g;
			$total_color->{'b'} += $b;
			$nb_pixel++;
		}
	}

	# return average color
	return is_color_is_white({	'r'=>$total_color->{'r'}/$nb_pixel,
								'g'=>$total_color->{'g'}/$nb_pixel,
								'b'=>$total_color->{'b'}/$nb_pixel
							});
}

sub is_color_is_white($) {
	my $pixel = shift;
	my $is_white = 1;
	my $threshold_white = 200; # 20% from pure white due to scanner imperfection

	while (my ($color,$value) = each(%$pixel)) {
		if ($value < $threshold_white) {
			$is_white = 0;
			last;
		}
	}
	return $is_white;
}


# own newFrom because some times, GD don't reconize jpeg file
sub myGDimageOpen($) {
	my ($filename) = shift;

	$filename .= '.jpg' if $filename !~ /\.(jpe?g|gif|png|xbm)$/i; # add .jpg if needed

	my $gd_obj;
	if    ($filename =~ /\.jpe?g$/i) { $gd_obj = GD::Image->newFromJpeg($filename) or die "Unable to read JPEG image '$filename'"; }
	elsif ($filename =~ /\.gif$/i)   { $gd_obj = GD::Image->newFromGif($filename)  or die "Unable to read GIF image '$filename'"; }
	elsif ($filename =~ /\.png$/i)   { $gd_obj = GD::Image->newFromPng($filename)  or die "Unable to read PNG image '$filename'"; }
	elsif ($filename =~ /\.xbm$/i)   { $gd_obj = GD::Image->newFromXbm($filename)  or die "Unable to read XBM image '$filename'"; }

	return $gd_obj;
}

# check if filename is good
sub filename_is_image($) {
	my ($filename) = shift;
	return $filename =~ /\.(?:jpe?g|gif|png|xbm?)$/i;
}


# save GD Obj into a jpeg file
sub save_jpeg($$) {
	my ($gd_obj,$filename) = @_;
	
	$filename .= '.jpg' if $filename !~ /\.jpe?g$/i; # add .jpg if needed
	open (OUTPUT,"+>$filename") or die "Unable to save JPEG $filename ($!)";
	binmode OUTPUT;
	print OUTPUT $gd_obj->jpeg($options{'quality'});
	close OUTPUT;
}

# display the documentation
sub print_help {
	print <<EOT ;
--input-dir=dirname		Split all files in a directory
--input-file=filename	Split only one file
--output-dir=dirname 	Directory where the splited file are saved (default is 'split')
--quality=x 			JPEG output quality (default is 90)
--crop 					Try to remove white border around page
--japanese -j			Invert left and right side
--quiet -q 				Don't print anything
--help -h				Display this message

EOT
	exit;
}