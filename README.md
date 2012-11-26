# Sanford

Sanford: simple hosts for Sanford services.  Define hosts for versioned services.  Setup handlers for the services.  Run the host as a daemon.

Sanford uses [Sanford::Protocol](https://github.com/redding/sanford-protocol) to communicate with clients.

## Usage

```ruby
# define a host
class MyHost
  include Sanford::Host

  configure do
    port 8000
    pid_dir '/path/to/pids'
  end

  # define some services
  version 'v1' do
    service 'get_user', 'MyHost::V1Services::GetUser'
  end

end

# define handlers for the services
class MyHost::V1Services::GetUser
  include Sanford::ServiceHandler

  def run!
    # process the service call and generate a result
    # the return value of this method will be used as the response data
  end
end

```

## Hosts

To define a Sanford host, include the mixin `Sanford::Host` on a class and use the DSL to configure it.


Within the `configure` block, a few options can be set:

* `hostname` - (string) The hostname or IP address for the server to bind to; default: `'0.0.0.0'`.  # TODO: chang to `ip` to not conflict with naming host objects.
* `port` - (integer) The port number for the server to bind to.
* `pid_dir` - (string) Path to the directory where you want the pid file to be written; default: `Dir.pwd`.
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
* `halt`: stop processing and return a result with a status code and message

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

Sanford comes with rake tasks for running hosts:

* `rake sanford:start` - spin up a background process running the host daemon.
* `rake sanford:stop` - shutdown the background process running the host gracefully.
* `rake sanford:restart` - runs the stop and then the start tasks.
* `rake sanford:run` - starts the server, but don't daemonize it (runs in the current ruby process). Convenient when using the server in a development environment.

These can be installed by requiring it's rake tasks in your `Rakefile`:

```ruby
require 'sanford/rake'
```

The basic rake tasks are useful if your application only has one host defined and if you only want to run the host on a single port. In the case you have multiple hosts defined or you want to run a single host on multiple ports, use environment variables to set custom configurations.

```bash
rake sanford:start   # starts the first defined host
SANFORD_NAME=AnotherHost SANFORD_PORT=13001 rake sanford:start # choose a specific host and port to run on with ENV vars
```

The rake tasks allow using environment variables for specifying which host to run the command against and for overriding the host's configuration. They recognize the following environment variables: `SANFORD_NAME`, `SANFORD_HOSTNAME`, and `SANFORD_PORT`.

Define a `name` on a Host to set a string name for your host that can be used to reference a host when using the rake tasks.  If no name is set, Sanford will use the host's class name.

### Loading An Application

Typically, a Sanford host is part of a larger application and parts of the application need to be setup or loaded when you start your Sanford server. The task `sanford:setup` is called before running any start, stop, or restart task; override it to hook in your application setup code:

```ruby
# In your Rakefile
namespace :sanford do
  task :setup do
    require 'config/environment'
  end
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
