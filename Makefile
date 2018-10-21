.PHONY: test

test:
	mix test --trace

rabbit.reset:
	sudo rabbitmqctl stop_app
	sudo rabbitmqctl reset    # Be sure you really want to do this!
	sudo rabbitmqctl start_app
