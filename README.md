# Sanford

Sanford TCP protocol server for hosting services.  Define hosts for versioned services.  Setup handlers for the services.  Run the host as a daemon.

Sanford uses [Sanford::Protocol](https://github.com/redding/sanford-protocol) to communicate with clients.  Check out [AndSon](https://github.com/redding/and-son) for a Ruby Sanford protocol client.

## Usage

```ruby
# define a host
class MyHost
  include Sanford::Host

  port 8000
  pid_file '/path/to/host.pid'

  # define some services
  version 'v1' do
    service 'get_user', 'MyHost::V1Services::GetUser'
  end

end

# define handlers for the services
class MyHost::V1Services::GetUser
  include Sanford::ServiceHandler

  def run!
    # process the service call and build a response
    # the return value of this method will be used as the response data
  end
end

```

## Hosts

To define a Sanford host, include the mixin `Sanford::Host` on a class and use the DSL to configure it. A few options can be set:

* `ip` - (string) A hostname or IP address for the server to bind to; default: `'0.0.0.0'`.
* `port` - (integer) The port number for the server to bind to.
* `pid_file` - (string) Path to where you want the pid file to be written.
* `logger`- (logger) A logger for Sanford to use when handling requests; default: `Logger.new`.

Any values specified using the DSL act as defaults for instances of the host. You can overwritten when creating new instances:

```ruby
host = MyHost.new({ :port => 12000 })
```

## Services

```ruby
class MyHost
  include Sanford::Host

  version 'v1' do
    service 'get_user', 'MyHost::ServicesV1::GetUser'
  end
end
```

Services are defined on hosts by version.  Each named service maps to a 'service handler' class.  The version and service name are used to 'route' requests to handler classes.

When defining services handlers, it's typical to organize them all under a common namespace. Use `service_handler_ns` to define a default namespace for all handler classes under the version:

```ruby
class MyHost
  include Sanford::Host

  version 'v1' do
    service_handler_ns 'MyHost::ServicesV1'

    service 'get_user',     'GetUser'
    service 'get_article',  'GetArticle'
    service 'get_comments', '::MyHost::OtherServices::GetComments'
  end
end
```

## Service Handlers

Define handlers by mixing in `Sanford::ServiceHandler` on a class and defining a `run!` method:

```ruby
class MyHost::Services::GetUser
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
class MyHost::Services::GetUser
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

## Running Host Daemons

Sanford comes with a CLI for running hosts:

* `sanford start` - spin up a background process running the host daemon.
* `sanford stop` - shutdown the background process running the host gracefully.
* `sanford restart` - "hot restart" the process running the host.
* `sanford run` - starts the server, but doesn't daemonize it (runs in the current ruby process). Convenient when using the server in a development environment.

The basic commands are useful if your application only has one host defined and if you only want to run the host on a single port. In the case you have multiple hosts defined or you want to run a single host on multiple ports, use environment variables to set custom configurations.

```bash
sanford start # starts the first defined host
SANFORD_HOST=AnotherHost SANFORD_PORT=13001 sanford start # choose a specific host and port to run on with ENV vars
```

The CLI allow using environment variables for specifying which host to run the command against and for overriding the host's configuration. They recognize the a number of environment variables, but the main ones are: `SANFORD_HOST`, `SANFORD_IP`, and `SANFORD_PORT`.

Define a `name` on a Host to set a string name for your host that can be used to reference a host when using the CLI.  If no name is set, Sanford will use the host's class name.

Alternatively, the CLI supports passing switches to override the host's configuration as well. Use `sanford --help` to see the options that are available.

### Loading An Application

Typically, a Sanford host is part of a larger application and parts of the application need to be initialized or loaded when you start your Sanford server. To support this, Sanford provides an `init` hook for hosts. The proc that is defined will be called before the Sanford server is started, properly running the server in your application's environment:

```ruby
class MyHost
  include Sanford::Host

  init do
    require File.expand_path("../config/environment", __FILE__)
  end

end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
