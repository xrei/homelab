.POSIX:
.PHONY: *

install-collections:
	ansible-galaxy collection install -r requirements.yaml

cluster:
	make -C cluster

all: install-collections cluster

upgrade:
	make -C cluster upgrade
