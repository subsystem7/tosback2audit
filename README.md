TOSBack2 Audit System - Analyzer
================================

These scripts are used in order to extract snapshots from the TOSBack2 git repository and 
generate a set of audit files and folders for the [TOSAudit API](https://docs.google.com/document/d/1IOij45-aDX7Emb1WOaWzDZGe2-NrlOYZbgk3zZ-qM8I).





DEPENDENCIES
============

This is a list of dependencies external to ruby and the ruby GEMs used for the project.

prettify
--------
Prettify is a python script used to simplify the HTML code extracted from the TOSBack2 git repository.
https://github.com/subsystem7/prettify


xidel
-----
"Xidel is a command line tool to download and extract data from html/xml pages."  It is used in this project to
extract a portion of an HTML source document that contains the most relevant policy text. When a xidel template is
specified for a specific TOSBack2 policy document, it is run before prettify. This process usually makes the comparison
between versions of the tracked policy documents more accurate as it excludes things like advertising and navigation.
http://videlibri.sourceforge.net/xidel.html#home

