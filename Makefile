all: app

app: app.cr views/index.ecr shard.lock shard.yml
	crystal build app.cr

# static: app.cr views/index.ecr shard.lock shard.yml
#	crystal build --static app.cr --link-flags -L`pwd`/lib64

pull-deps:
	shards install

clean:
	-rm app

clean-all:
	-rm -fr lib/

install: app discourse_GrandLyon_gateway.service
	mkdir -p /usr/local/bin/
	cp app /usr/local/bin/discourse_GrandLyon_gateway
	mkdir -p /etc/systemd/system/
	cp systemd/discourse_GrandLyon_gateway.service /etc/systemd/system/
