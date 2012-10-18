# Sanford

TODO: Write a gem description

## Usage

### Defininig Service Hosts

TODO

* When defining a service host, give it a name (or use the class name, like we do in I-Resque)

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

With this, `Sanford` stores your class for reference later. The class `Sanford::Hosts` keeps track of all the registered hosts. They can be viewed by calling the `set` on the hosts class:

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

