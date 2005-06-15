install:
	touch logs/all.log
	chmod 777 logs/all.log

documentation: 
	for i in *.p[lm]; do perltidy -ce -l 72 $$i -o doc/src/$$i; cd doc/src; perltidy -nnn -html -css=perl.css $$i; rm -f $$i; cd ..; cd ..; done;
	cd doc/src/;rm -f index.html;for i in *.html; do echo "<a href=\"$$i\">$$i</a><br />" >> index.html; done;	cd ../../
	cvs log > doc/CHANGELOG
test:
	./test.pl

cvsupdate:
	cvs -q update -d -P
