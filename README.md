# Sanford

TODO: Write a gem description

## Usage

### Defininig Hosts

To define a `Sanford` host, include the module `Sanford::Host` on a class. You can then use the `name` and `configure` methods to define it:

```ruby
class MyHost
  include Sanford::Host

  name 'my_host'

  configure do
    port 8000
    pid_dir '/path/to/pids'
  end
end
```

The name method is optional, but can be used to set a string name for your host. This can be used with the rake tasks and is also used when writing the PID file. If a name is not set, then `Sanford` will stringify the class name and use it.

Within the `configure` block, a few options can be set:

* `hostname`  - (string) The hostname or IP address for the server to bind to. This defaults to `'127.0.0.1'`.
* `port`      - (integer) The port number for the server to bind to. This isn't defaulted and must be provided.
* `pid_dir`   - (string) File path to where you want the pid file to be written. The pid file is named after the host's name: '<host.name>.pid'. This defaults to the current working directory (`Dir.pwd`).
* `logging`   - (boolean) Whether or not you want the server to log output about receiving connections. Defaults to `true`.
* `logger`    - (logger) A logger for Sanford to use when handling requests. This should have a similar interface as ruby's standard logger. Defaults to an instance of ruby's logger.

These values act as defaults when building and running a service host. This is so that the same service host can be run on multiple ports. See the following 'Rake Tasks' section for an example of overwritting the port using the rake tasks.

### Rake Tasks

`Sanford` comes with rake tasks for starting and stopping a service host. These can be installed by requiring it's rake tasks into your `Rakefile`:

```ruby
require 'sanford/rake'
```

This will provide 3 tasks: starting, stopping and running. Replace `<service_host_name>` with the name of your service hosts you defined in your configuration file:

* `rake sanford:start` - Start the service host server as a daemon. This will spin up a background process running the server.
* `rake sanford:stop` - Stop the service host server that was started using the previous task. This will shutdown the background process gracefully.
* `rake sanford:restart` - Restart the service host server. Essentially runs the stop and then the start tasks.
* `rake sanford:run` - Run the service host server in the current ruby process. This starts the server, but doesn't daemonize it. This is convenient when using the server in a development environment.

The basic rake tasks are useful if your application only has one host defined and if you only want to run the host on a single port. In the case you have multiple hosts defined or want to run a single host on multiple ports, additional options can be passed. Assuming the following hosts are defined:

```ruby
class MyHost
  include Sanford::Host

  configure do
    port 12000
  end
end

class AnotherHost
  include Sanford::Host

  configure do
    port 13000
  end
end
```

Then they can be managed using the rake tasks like so:

```bash
rake sanford:start # starts the first defined host `MyHost`
rake sanford:start[AnotherHost] # starts `AnotherHost`
rake sanford:start[MyHost,12001] # starts `MyHost` on port 12001
SANFORD_NAME=AnotherHost SANFORD_PORT=13001 rake sanford:start # ENV vars work as well
```

The rake tasks optionally accept 3 arguments: name, port and hostname. In addition to allowing these arguments, they will also recognize these environment variables: `SANFORD_NAME`, `SANFORD_HOSTNAME`, and `SANFORD_PORT`.

## Advanced

### Daemonizing

`Sanford` uses the [daemons](https://github.com/ghazel/daemons) gem to daemonize it's server process. This is done using the daemons gem's `run_proc` method and starting the server in it:

```ruby
task :start do
  ::Daemons.run_proc(host.name, { :ARGV => [ 'start' ] }) do
    server.start
  end
end
```

Using daemons' `run_proc` and specifying `ARGV` runs daemons different actions: starting, stopping, running, etc. With this, `Sanford` provides rake tasks that wrap this behavior for easily managing your hosts.

### Registering Hosts

`Sanford` registers all classes that include it's `Host` mixin. For example:

```ruby
class MyHost
  include Sanford::Host

  name 'my_host'
end
```

With this, `Sanford` stores your class for reference later in `Sanford::Hosts`. They can be viewed by calling the `set` on the hosts class:

```ruby
Sanford::Hosts.set # => #<Set: {MyHost}>
```

The host name (`'my_host'` in the example) can be used with the rake tasks to manage a specific host:

```bash
rake sanford:start[my_host]
rake sanford:restart[my_host]
rake sanford:stop[my_host]
```

With this, multiple hosts can be defined and managed independently.

