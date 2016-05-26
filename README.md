# Double page splitter
----------------------
Perl script to split double pages scans.

When I read comics or manga on my tablet, sometimes scanners don't split the pages.
This program makes the job for you

![Basic Example](gfx/basic_usage.jpg?raw=true "Basic Example")

# Usage
-------
Options :
`--input-dir=dirname`
	Split all files in a directory

`--input-file=filename`
	Split only one file

`--output-dir=dirname`
	Directory where the splited file are saved (default is 'split')

`--quality=x`
	JPEG output quality (default is 90)

`--japanese` or `-j`
	Invert left and right side

`--quiet` or `-q`
	Don't print anything

`--help` or `-h`
	Display this message

# Examples
----------
`perl double_page_splitter.pl --input-file=*good-manga-page-011.jpg*`

`perl double_page_splitter.pl --input-dir=*Good-Manga-vol_01* --japanese`