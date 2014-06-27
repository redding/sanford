# Sanford

Sanford TCP protocol server for hosting services. Define servers for services. Setup handlers for the services. Run the server as a daemon.

Sanford uses [Sanford::Protocol](https://github.com/redding/sanford-protocol) to communicate with clients.  Check out [AndSon](https://github.com/redding/and-son) for a Ruby Sanford protocol client.

## Usage

```ruby
# define a server
class MyServer
  include Sanford::Server

  port 8000
  pid_file '/path/to/server.pid'

  # define some services
  router do
    service 'get_user', 'MyServer::GetUser'
  end

end

# define handlers for the services
class MyServer::GetUser
  include Sanford::ServiceHandler

  def run!
    # process the service call and build a response
    # the return value of this method will be used as the response data
  end
end

```

## Servers

To define a Sanford server, include the mixin `Sanford::Server` on a class and use the DSL to configure it. A few options can be set:

* `name` - (string) A name for the server, this is used to set the process name
and in logging.
* `ip` - (string) A hostname or IP address for the server to bind to; default: `'0.0.0.0'`.
* `port` - (integer) The port number for the server to bind to.
* `pid_file` - (string) Path to where you want the pid file to be written.
* `logger`- (logger) A logger for Sanford to use when handling requests; default: `Logger.new`.

## Services

```ruby
class MyServer
  include Sanford::Server

  router do
    service 'get_user', 'MyServer::GetUser'
  end
end
```

Services are defined on servers via a router block.  Each named service maps to a 'service handler' class.  The service name is used to 'route' requests to handler classes.

When defining services handlers, it's typical to organize them all under a common namespace. Use `service_handler_ns` to define a default namespace for all handler classes under the version:

```ruby
class MyServer
  include Sanford::Server

  router do
    service_handler_ns 'MyServer'

    service 'get_user',     'GetUser'
    service 'get_article',  'GetArticle'
    service 'get_comments', '::OtherServices::GetComments'
  end
end
```

## Service Handlers

Define handlers by mixing in `Sanford::ServiceHandler` on a class and defining a `run!` method:

```ruby
class MyServer::GetUser
  include Sanford::ServiceHandler

  def run!
    # process the service call and generate a response
    # the return value of this method will be used as
    # the response data returned to the client
  end
end
```

This is the most basic way to define a service handler. In addition to this, the `init!` method can be overwritten. This will be called after an instance of the service handler is created. The `init!` method is intended as a hook to add constructor logic. The `initialize` method should not be overwritten.

In addition to these, there are some helpers methods that can be used in your `run!` method:

* `request`: returns the request object the host received
* `params`: returns the params payload from the request object
* `halt`: stop processing and return response data with a status code and message

```ruby
class MyServer::GetUser
  include Sanford::ServiceHandler

  def run!
    User.find(params['user_id']).attributes
  rescue NotFoundException => e
    halt :not_found, :message => e.message, :data => request.params
  rescue Exception => e
    halt :error, :message => e.message
  end
end
```

## Running Servers

To run a server, Sanford needs a config file to be defined:

```ruby
require 'my_server'
run MyServer.new
```

This file works like a rackup file. You require in your server and call `run`
passing an instance of the server. To use these files, Sanford comes with a CLI:

* `sanford CONFIG_FILE start` - spin up a background process running the server.
* `sanford CONFIG_FILE stop` - shutdown the background process running the server gracefully.
* `sanford CONFIG_FILE restart` - "hot restart" the process running the server.
* `sanford CONFIG_FILE run` - starts the server, but doesn't daemonize it (runs in the current ruby process). Convenient when using the server in a development environment.

Sanford will use the configuration of your server to either start a process or manage an existing one. A servers ip and port can be overwritten using environment variables:

```bash
sanford my_server.sanford start # starts a process for `MyServer`
SANFORD_IP="1.2.3.4" SANFORD_PORT=13001 sanford my_server.sanford start # run the same server on a custom ip and port
```

This allows running multiple instances of the same server on ips and ports that are different than its configuration if needed.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
