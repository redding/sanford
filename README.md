# Sanford

Sanford is a framework for defining RPC service hosts. It provides an interface for defining and configuring a host and tools for running it.

## Usage

### Defining Hosts

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

* `hostname` - (string) The hostname or IP address for the server to bind to. This defaults to `'127.0.0.1'`.
* `port` - (integer) The port number for the server to bind to. This isn't defaulted and must be provided.
* `pid_dir` - (string) File path to where you want the pid file to be written. The pid file is named after the host's name: '<host.name>.pid'. This defaults to the current working directory (`Dir.pwd`).
* `logging` - (boolean) Whether or not you want the server to log output about receiving connections. Defaults to `true`.
* `logger`  - (logger) A logger for Sanford to use when handling requests. This should have a similar interface as ruby's standard logger. Defaults to an instance of ruby's logger.

These values act as defaults when building and running a service host. This is so that the same service host can be run on multiple ports. See the following 'Rake Tasks' section for an example of overwritting the port using the rake tasks.

### Rake Tasks

`Sanford` comes with rake tasks for starting and stopping a service host. These can be installed by requiring it's rake tasks into your `Rakefile`:

```ruby
require 'sanford/rake'
```

This will provide 4 tasks: starting, stopping, restarting and running. Replace `<service_host_name>` with the name of your service hosts you defined in your configuration file:

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

## Protocol

`Sanford` converts all requests and responses into a similar binary format. Every message is made up of 3 parts: the size, the protocol version and the body.

* **size** - (4 bytes, integer) The size of the message body in bytes. This should be read first and if it is not present or valid, the message should be rejected.
* **protocol version** - (1 byte, integer) The version number of the protocol. This is to ensure that a client and server are communicating under the same assumptions. If this value doesn't match the server's then the message is rejected.
* **body** - (variable bytes, BSON) The body of the message, serialized using [BSON](http://bsonspec.org/). This contains either request or response information.

### Request

A request is made up of 2 parts: the service name, and the params.

* **service name** - (string) The service that the request is calling. If a matching service can't be found, then the request is rejected.
* **params** - (array) Parameters to call the service with. This can contain any BSON serializable object.

The service name and params are always required. A BSON request should look like:

```ruby
{ 'name':   'a/service',
  'params': [ 'something' ]
}
```

### Response

A response is made up of 2 parts: the status and the result.

* **status** - (tuple) A number that determines whether the request was successful or not and a message that includes details about the status. See the `Status Code` section further down for a list of all the possible values.
* **result** - Result of running the service. This can be any BSON serializable object and won't be set if the request wasn't successful.

A response should always contain a status. The result is optional. A BSON response should look like:

```ruby
{ 'status': [ 200, 'The request was successful.' ]
  'result': true
}
```

#### Status Codes

This is the list of predefined status codes. In addition to using these, a service can return custom status codes, but they should be 600+ to avoid collisions with `Sanford`'s defined status codes. The list contains both the integer value and the name of the status code along with a description of what each code is intended for:

* `200` - `success` - The request was successful.
* `400` - `bad_request` - The request couldn't be read. This is usually because it was not formed correctly. This can mean a number of things, check the response message for details:
  * The message size couldn't be read or was invalid.
  * The protocol version couldn't be read or didn't match the servers.
  * The message body couldn't be deserialized.
  * The request didn't contain a service name or params.
* `401` - `unauthorized` - The request couldn't be authorized. Either the auth key wasn't present or it didn't pass authentication.
* `404` - `not_found` - The service name didn't match a configured service.
* `500` - `error` - An error occurred when calling the service. The message attribute of the response should be used to get more details.

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

