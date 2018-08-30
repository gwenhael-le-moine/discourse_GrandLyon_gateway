all: app

app: app.cr views/index.ecr
	crystal build --static $<

pull-deps:
	crystal deps install

clean:
	-rm app

clean-all:
	-rm -fr lib/
