mcurl
=====

A slightly-bugfixed and generally refactored branch of the original mcurl, designed to handle being used by warrick for retrieving archived content containing query strings.

This may or may not be useful to anyone. I am likely to be responsive to easily testable bug reports, however.

This project is kind of a quick stub to permit integration with my warrick bugfix.

A quickly-testable command line which fails on other branches of mcurl but presents functionality warrick depends on is:

> ./mcurl.pl --debug -dt "Sun, 01 Dec 2002 08:00:00 GMT" -L "http://www.vqf.com:80/bbs/post.php3?board=VQF.comForum&irt=13920" 
