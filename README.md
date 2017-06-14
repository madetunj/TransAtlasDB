# TransAtlasDB

## Introduction

TransAtlasDB is an integrated database system from transcriptome analysis data. 

This is the GitHub repository for the documentation of the TransAtlasDB software.

If you like this repository, please click on the "Star" button on top of this page, to show appreciation to the repository maintainer. If you want to receive notifications on changes to this repository, please click the "Watch" button on top of this page.

---

## TransAtlasDB main package

The TransAtlasDB toolkit is written in Perl and can be run on diverse hardware systems where standard Perl modules and the Perl-DBD module are installed. The package consist of the following files:

- **INSTALL-tad.pL**: install TransAtlasDB system.

- **connect-tad.pL**: verify connection details or create connection details (used only when requested).

- **tad-import.pl**: import samples metadata and RNAseq data into the database. 

- **tad-interact.pl**: interactive interface to explore database content.

- **tad-export.pl**: view or export reports based on user-defined queries.

- **other folders**:
	* schema : contains the TransAtlasDB relational database schema.
	* example : contains sample files and templates.
	* lib : contains required Perl Modules.
	* web : TransAtlasDB web portal ( is visible after executing INSTALL-tad.pl )
---

## TransAtlasDB installation
- Requirements:
	* Operating System :
		* Linux / Mac (tested and verified)

	
	* Databases :
		* MySQL
		* FastBit

	
	* Perl Modules needed :
		* DBD::mysql
		* Spreadsheet::Read
		* Spreadsheet::XLSX
		* Text::TabularDisplay
		* Sort::Key
		
- Quick Guide:
	* To install [RECOMMENDED: with root priviledges]
	```
	INSTALL-tad.pl -password <mysql-password>
	```
	
	* More details and instructions are provided at https://modupeore.github.io/TransAtlasDB/tutorial.html

---

## TransAtlasDB web portal
- Requirements:
	* Requirements in the above section (TransAtlasDB installation).
	* PHP (at least version 5.5.38)
	* Apache (at least version 2.4.18)
	
- Guide:
	* After installation of the TransAlasDB databases and dependencies (as show above). The **web** folder is provided and should be moved to your localhost or apache location.

---

If you have questions, comments and bug reports, please email me directly.
Thank you very much for your help and support!
