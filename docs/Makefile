.PHONY: all clean site

INDEX = index.adoc

SLACK_TOKEN 			?= 
ASCIIBUILD_OPTS 	?= -a enabled=true -a slack_token=$(SLACK_TOKEN) -r $(SLACK_TOKEN) 

site: $(INDEX)
	asciibuild -d . $(ASCIIBUILD_OPTS) $(INDEX)

clean: 
	rm -f index-*.html

all: clean site