#!/bin/bash
case $1 in
	1) ./mcurl.pl --debug -D test1.log -dt "Sun, 01 Dec 2002 08:00:00 GMT" -tg "http://mementoproxy.lanl.gov/aggr/timegate" -L -o "t?e&s=t" "http://www.vqf.com:80/bbs/post.php3?board=VQF.comForum&irt=13920" ;;
	2) ./mcurl.pl --debug -dt "Sun, 01 Dec 2002 08:00:00 GMT" -L "http://www.vqf.com:80/bbs/post.php3?board=VQF.comForum&irt=13920" ;;
	3) ../warrick2/mcurl.pl --debug -dt "Sun, 01 Dec 2002 08:00:00 GMT" -L "http://www.vqf.com:80/bbs/post.php3?board=VQF.comForum&irt=13920" ;;
	*) echo "else" ;;
esac
