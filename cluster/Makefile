.POSIX:

export KUBECONFIG="$(shell pwd)/kubeconfig.yaml"

default: setup

setup:
	ansible-playbook \
		--inventory inventory/hosts.yml \
		cluster.yml

upgrade:
	ansible-playbook \
		--inventory inventory/hosts.yml \
		upgrade.yml