#!/usr/bin/perl -w
# Created by Matthew Tarazi <mtarazi@emory.edu>, Jan 2003, last updated 2/21/03
# Program created for the NEH-EWWRP project.  It checks for mispelled filenames, skipped pages, and pads all TIFF files
# with appropriate number of zeroes. Optionally, it adds an offset (inputed by the user) to the page 
# number already contained within each TIFF filename.

## Added functionality contributed by:
## Rebecca Sutton Koeser <rsutton@emory.edu>, August 2003
## Added the capability to add a prefix to all files.

use strict;

my $book_name;
my $directory;
my $page_offset;

my @files_in_folder;
my @files_to_change;
my @unmatched_files;

my $first_page;
my $last_page;

## added by  Rebeca Sutton Koeser, July 25 2003.
my $prefix;
my $num_prefix_added = 0;

&intro;
&query_user;
&read_dir;
&get_files_to_change_and_pad;
if (@files_to_change == 0) { 
  die "\nABORT: There were no files in the directory that match the specified criteria.\n" 
}
# Order the array depending on whether file numbers needed to be added to or subtracted from
if ($page_offset > 0) {
	@files_to_change = reverse sort @files_to_change;
	$files_to_change[$#files_to_change] =~ /^$book_name(\d+)\.tiff?$/i;
	$first_page = $1;
	$files_to_change[0] =~ /^$book_name(\d+)\.tiff?$/i;
	$last_page = $1;
	&check_rename || exit 1;	
	&rename_matched_files; 
} else {
	@files_to_change = sort @files_to_change;
	$files_to_change[0] =~ /^$book_name(\d+)\.tiff?$/i;
	$first_page = $1;
	$files_to_change[$#files_to_change] =~ /^$book_name(\d+)\.tiff?$/i;
	$last_page = $1;
	if ($page_offset < 0) {
		&check_rename || exit 1;	
		&rename_matched_files;
	}
}

if ($prefix) {
  add_prefix();
}
&print_report;

#=================================================================================================

# Introduction to the program
sub intro {
	print "
This program pads the names of TIFF files with the appropriate
number of zeroes, and checks for mispelled filenames and pages
that may have been skipped in scanning.  Optionally, it adds a
specified offset number to the page numbers already contained 
within each TIFF filename.

Would you like to continue? [Y]es or [N]o > ";
	exit 1 unless (<STDIN>=~ /^[yY]/);
}

# Query the user for required information about the renaming of files
sub query_user {
	my $pass_check = "false";
	while ($pass_check ne "true") {
		print "
Please enter the name of the book as it appears in the filenames
(e.g., jmstar).  
(Note: if filenames use only numbers, hit enter here to leave blank
and input the correct filename as a prefix.)
Please enter book name  > ";
		$book_name = <STDIN>;
		$book_name =~ s/^\s*//;
		$book_name =~ s/\s*$//;
		print "
Please enter the directory in which the TIFF files are located.
E.g., enter /NEH-EWWRP/yourname/jmstar, or simply enter jmstar
if you are already in /NEH-EWWRP/yourname.

Please enter the directory in which the TIFF files are located > ";
		$directory = <STDIN>;
		$directory =~ s/^\s*//;
		$directory =~ s/\s*$//;
		print "
Please enter the page offset, i.e., the number to be added to
the page number already in the filename.  E.g., if the first
currently numbered file is jmstar003.tif, and it should be
jmstar009.tif, the offset should be 6.
(You can enter a positive or a negative number, depending on
whether the filename numbers need to be made larger or smaller.
You can also enter an offset of \"0\", in which case the program
will check for spelling inconsistencies and pad with zeroes, but 
will not change the numbers.)
Please enter the page offset > ";
		$page_offset = <STDIN>;
		$page_offset =~ s/^\s*//;
		$page_offset =~ s/\s*$//;

   print "
Please enter the prefix to prepend to all file names.
(Hit enter for none)
Please enter the prefix > ";
     $prefix = <STDIN>;
     chop($prefix);

		if ($page_offset =~ /\d+/) {
			print "
You have entered the following information:
\tName of book: $book_name
\tDirectory where files are located: $directory
\tOffset to be added to each page number in filename: $page_offset
\tPrefix to prepend to all filenames: $prefix
Has this information been entered correctly? [Y]es or [N]o > ";
			if (<STDIN> =~ /^[yY]/) {$pass_check = "true";}
        } else {
            print "You need to enter a numerical value for the page offset.\n"; }
	}
}

# Read filenames of directory into array
sub read_dir {
	chdir($directory) || die "The specified directory cannot be found. The program will terminate.\n";
	opendir(DIR, ".");
	@files_in_folder = readdir(DIR);
	closedir(DIR);
}

# Store all matching filenames to be changed in one array,
# and files that don't match in another.
# Rename files such that all page numbers in filenames that
# match are padded with leading zeroes where necessary.
sub get_files_to_change_and_pad {
	my $current_file;
	my $page_number;
	my $padded_file_name;
	foreach $current_file (@files_in_folder) {
		if ($current_file =~ /^$book_name(\d+)\.tiff?$/i) {
			$page_number = $1; 
			if (length($page_number) > 2) {
				push(@files_to_change, $current_file);	
			} elsif (length($page_number) == 1) {
				$page_number = "00" . $page_number;
				$padded_file_name = $book_name . $page_number . ".tif";
				rename($current_file, $padded_file_name);
				push(@files_to_change, $padded_file_name);
			} elsif (length($page_number) == 2) {
				$page_number = "0" . $page_number;
				$padded_file_name = $book_name . $page_number . ".tif";
				rename($current_file, $padded_file_name);
				push(@files_to_change, $padded_file_name);
			}
		} elsif ($current_file =~ /^\./) {
		} else {
			push(@unmatched_files, $current_file);
		}
	}
}

# Check with user that filenames will be renamed correctly
sub check_rename {
	my $new_first_page;
	my $first_file;
	my $new_first_file;
	
	$new_first_page = $first_page + $page_offset;
	$first_file = $book_name . $first_page . ".tif";
	$first_file = &pad_filename($first_file);
	$new_first_file = $book_name . $new_first_page . ".tif";
	$new_first_file = &pad_filename($new_first_file);
	print "
The filenames have been padded with zeroes. The first filename
currently numbered is \"$first_file\".
If the filenames are renamed with the offset added, this first 
file will become \"$new_first_file\".
Is this correct? Do you wish to proceed? [Y]es or [N]o > ";
	if (<STDIN> =~ /^[yY]/) {1} else {0}
}

# Rename all the matching filenames, adding the offset 
# to the number in each filename
sub rename_matched_files {
	my $current_file;
	my $page_number;	
	my $new_file;

	foreach $current_file (@files_to_change) {
		$current_file =~ /^$book_name(\d+)\.tiff?$/i;
		$page_number = $1; 
		$page_number += $page_offset;
		$new_file = $book_name . $page_number . ".tif";
		$new_file = &pad_filename($new_file);
		rename($current_file, $new_file);
	}
}

sub pad_filename {
	my ($file_to_pad) = @_;
	my $page;
	$file_to_pad =~ /^$book_name(\d+)\.tiff?$/i || return $file_to_pad;
	$page = $1; 
	if (length($page) == 1) {
		$page = "00" . $page;
	} elsif (length($page) == 2) {
		$page = "0" . $page;
	}
	$book_name . $page . ".tif";
}

# Print summary both to screen and to a file
sub print_report {
	my $today = localtime;
	my $num_files_changed = @files_to_change;
	my $num_unmatched_files = @unmatched_files;
	my $num_total_files = $num_files_changed + $num_unmatched_files;
	my $num_skipped_pages = ($last_page - $first_page + 1) - $num_files_changed;

	my $msg;
	my $current_file;
		
	open (LOGFILE, ">>../rename_log.txt");
	
	if ($page_offset == 0) {
		$msg = "\nThe files were only padded without an offset being added.\n" .
			"$num_total_files (non-hidden) files were in the directory.\n" .
			"There were $num_files_changed files that could have been padded.\n";
	} else {
		$msg = "\nThe files were both padded and renamed with the offset.\n" .
			"$num_total_files (non-hidden) files were found in the specified directory.\n" . 
			"$num_files_changed files had their filename changed.\n";
	}
	print "\n\nSUMMARY REPORT for ** $book_name **, performed on $today.\n";
	print LOGFILE "\nSummary Report for ** $book_name **, performed on $today.\n";
	print $msg;
	print LOGFILE $msg;
	if ($num_unmatched_files > 0) {
		print "There were $num_unmatched_files files that could be mispelled or have some other inconsistency.\n" .
			"These filenames were neither padded with zeroes, nor was the offset added to them.\n" .
			"Here is a list of the files that might be mispelled or need to be renamed:\n";
		print LOGFILE "There were $num_unmatched_files files that could be mispelled or have some other inconsistency.\n" .
			"These filenames were neither padded with zeroes, nor was the offset added to them.\n" .
			"Here is a list of the files that might be mispelled or need to be renamed:\n";
		foreach $current_file (@unmatched_files) {
			print "\t\"" . $current_file . "\"\n";
			print LOGFILE "\t\"" . $current_file . "\"\n";
		}
	}
	
	if ($num_skipped_pages > 0) {
		$msg = "ATTENTION: You may have skipped $num_skipped_pages pages that need to be scanned.\n" .
			"The following pages may have been skipped (listed by the  page numbers used BEFORE offset was added):\n";
		if ($page_offset > 0 ) { @files_to_change = sort @files_to_change; }
		my $page;
		my $prev_page = $first_page - 1;
		foreach $current_file (@files_to_change) {
			$current_file =~ /^$book_name(\d+)\.tiff?$/i;
			$page = $1;
			if ($page != ($prev_page + 1)) {
				for (my $i = $prev_page+1; $i < $page; $i++) { $msg = $msg . "\t" . $i; }
			}
			$prev_page = $page;
		}
		
		$msg = $msg . "\nSome of these pages may have been purposefully skipped by you.\n" .
			"Or else the program may think they were skipped because the files for these pages may have been named incorrectly.\n" .
			"Check the list of possible misspelled filenames given above. If the file for the page is listed, just change the name appropriately.\n" .
			"Otherwise, go and make sure you have scanned all these pages that may have been skipped.\n"; 


		print $msg;
		print LOGFILE $msg;
	}

## report any prefix changes
	print "$num_prefix_added files were renamed with the prefix '$prefix'\n";
	print LOGFILE "$num_prefix_added files were renamed with the prefix '$prefix'\n";


	
	print LOGFILE "\n===================================================================\n";
	close(LOGFILE);
	print "\nPLEASE VIEW THE LOG FILE: \"rename_log.txt\" in your working directory. It contains a summary of this info.\n\n";
}


## Function added by Rebecca Sutton Koeser, July 25 2003.
## add a prefix to all appropriate filenames
sub add_prefix {
	my $current_file;
	my $new_filename;
	my $rval;
	$num_prefix_added = 0;

	foreach $current_file (@files_to_change) {
		if ($current_file =~ /^$book_name(\d+)\.tiff?$/i) {
		  $new_filename = $prefix . $current_file;
		  $rval = rename($current_file, $new_filename);
		  $num_prefix_added++;
		}
	 }
}

