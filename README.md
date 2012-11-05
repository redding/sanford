# Sanford

Sanford is a framework for defining versioned APIs. This is done by defining a service host and specifying the services it supports. Services are configured with a service handler class. This is built and run whenever the server receives a call to the matching service. In addition to defining services and their hosts, Sanford provides tools for starting and stopping the server as a daemon.

## Usage

### Defining Hosts

To define a Sanford host, include the mixin `Sanford::Host` on a class. You can then use the `name` and `configure` methods to define it:

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

The `name` method is optional, but can be used to set a string name for your host. This can be used with the rake tasks (see "Usage - Rake Tasks" further down) and is also used when writing the PID file. If a name is not set, then Sanford will use the class name.

Within the `configure` block, a few options can be set:

* `hostname` - (string) The hostname or IP address for the server to bind to. This defaults to `'0.0.0.0'`.
* `port` - (integer) The port number for the server to bind to. This isn't defaulted and must be provided.
* `pid_dir` - (string) Path to the directory where you want the pid file to be written. The pid file is named after the Sanford host class's name: '<host.name>.pid'. This defaults to the current working directory (`Dir.pwd`).
* `logger`- (logger) A logger for Sanford to use when handling requests. This should have a similar interface as ruby's standard logger. Defaults to an instance of ruby's logger.

These values act as defaults for instances of the Sanford host, but can be overwritten when creating a new instance of a Sanford host. For example:

```ruby
host = MyHost.new({ :port => 12000 })
```

This will overwrite the port value from `8000` to `12000`. This is useful when you want to run the same service host on multiple ports. Generally, there isn't a need to create an instance of a host directly, especially when using the rake tasks. In the case of the rake tasks, they allow setting ENV variables to overwrite a host's default configuration (again see "Usage - Rake Tasks" for more details).

### Adding Services

Once a Sanford host has been defined, you can specify the services it responds to. This is done using the `version` method to specify the version of the service and the `service` method to provide the name and service handler class for the service:

```ruby
class MyHost
  include Sanford::Host

  version 'v1' do
    service 'get_user', 'MyHost::Services::GetUser'
  end
end
```

The version and service name are used to find the service handler class when a matching request is received. The service handler class is 'constantized' and a new instance is built and run to handle the request.

When defining services, it's typical to organize them all similarly. Sanford provides the ability to provide version namespaces:

```ruby
class MyHost
  include Sanford::Host

  version 'v1' do
    service_handler_ns 'MyHost::Services::V1'

    service 'get_user',     'GetUser'
    service 'get_article',  'GetArticle'
    service 'get_comments', '::MyHost::Services::GetComments'
  end
end
```

In this example, `get_user` and `get_article` both use the namespace so their service handler class names are `MyHost::Services::V1::GetUser` and `MyHost::Services::V1::GetArticle`. For `get_comments`, because it's service handler class name is prepended with 2 colons (`::`), it will ignore the namespace and the class name will be used as is (`MyHost::Services::GetComments`).

### Defining Service Handlers

Once you've added some services, the handlers need to be defined. This can be done by mixing in `Sanford::ServiceHandler` on your class and defining a `run!` method:

```ruby
class MyHost::Services::GetUser
  include Sanford::ServiceHandler

  def run!
    # process the service call and generate a result
    # the return value of this method will be used as the result and sent to
    # the client
  end
end
```

This is the most basic way to define a service handler. In addition to this, the `init!` method can be overwritten. This will be called after an instance of the service handler is created. The `init!` method is intended as a hook to add initialization logic. The `initialize` method shouldn't be overwritten.

In addition to these, there are some helpers methods that can be used in your `run!` method:

```ruby
class MyHost::Services::GetUser
  include Sanford::ServiceHandler

  def run!
    # the `request` method will return a Sanford request object. The primary
    # use of this is to access the params, NOTE, all hash keys will be strings
    user = User.find(self.request.params['user_id'])
    # the `halt` method can be used to stop processing and return a result with
    # a status code and message
    halt :success, :result => user.attributes
  rescue NotFoundException => e
    halt :not_found, :message => e.message
  rescue Exception => e
    halt :error, :message => e.message
  end
end
```

As shown in the example, the `halt` method takes 3 arguments: a response status, message and the result of the service. This is used to build a valid response for clients (see "Protocol - Response"). The status indicates whether the request was successful or not and the message provides additional details. The result is the data to hand to the client. The call to `halt` passing it `:success` is not necessary and `user.attributes` could've simply been returned. Also, in the cases when an exception is thrown, no result is passed. Typically, when a request does not complete successfully, no result should be returned to the client. Finally, the `halt` method can also be given a specifc number instead of the name of a status (`halt 654`). This can be used to return your own custom status codes if desired.

### Rake Tasks

Sanford comes with rake tasks for starting and stopping a service host. These can be installed by requiring it's rake tasks in your `Rakefile`:

```ruby
require 'sanford/rake'
```

This will provide 4 tasks: starting, stopping, restarting and running.

* `rake sanford:start` - Start the service host server as a daemon. This will spin up a background process running the server.
* `rake sanford:stop` - Stop the service host server that was started using the previous task. This will shutdown the background process gracefully.
* `rake sanford:restart` - Restart the service host server. Essentially runs the stop and then the start tasks.
* `rake sanford:run` - Run the service host server in the current ruby process. This starts the server, but doesn't daemonize it. This is convenient when using the server in a development environment.

The basic rake tasks are useful if your application only has one host defined and if you only want to run the host on a single port. In the case you have multiple hosts defined or want to run a single host on multiple ports, additional options can be passed. For example, given the following host definitions:

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

### Loading An Environment

Typically, a Sanford host is part of a larger application and parts of the application need to be setup or loaded when you start your Sanford server. To handle this, Sanford provides a rake task that can be overwritten:

```ruby
# In your Rakefile
namespace :sanford do
  task :setup do
    require 'config/environment'
  end
end
```

By defining the task `sanford:setup`, this is automatically called before running any of the Sanford rake tasks. This way a Sanford server can use application code.

## Protocol

Sanford converts all requests and responses into a similar binary format. Every message is made up of 3 parts: the size, the protocol version and the body.

* **size** - (4 bytes, integer) The size of the message body in bytes. This should be read first and if it is not present or valid, the message should be rejected.
* **protocol version** - (1 byte, integer) The version number of the protocol. This is to ensure that a client and server are communicating under the same assumptions. If this value doesn't match the server's then the message is rejected.
* **body** - (variable bytes, BSON) The body of the message, serialized using [BSON](http://bsonspec.org/). This contains either request or response information.

### Request

A request is made up of 3 parts: the service name, the service version and the params.

* **service name** - (string) The service that the request is calling. This is used with the service version to find a matching service handler. If one isn't found, then the request is rejected.
* **service version** - (string) The version of the service that the request is calling. This is used with the service name to find a matching service handler. If one isn't found, then the request is rejected.
* **params** - Parameters to call the service with. This can be any BSON serializable object.

The service name, version and params are always required. A BSON request should look like:

```ruby
{ 'name':     'some_service',
  'version':  'v1'
  'params':   'something'
}
```

### Response

A response is made up of 2 parts: the status and the result.

* **status** - (tuple) A number that determines whether the request was successful or not and a message that includes details about the status. See the "Protocol - Status Codes" section further down for a list of all the possible values.
* **result** - Result of running the service. This can be any BSON serializable object and won't be set if the request wasn't successful.

A response should always contain a status, but the result is optional. A BSON response should look like:

```ruby
{ 'status': [ 200, 'The request was successful.' ]
  'result': true
}
```

#### Status Codes

This is the list of predefined status codes. In addition to using these, a service can return custom status codes, but they should use a number greater than or equal to 600 to avoid collisions with Sanford's defined status codes. The list contains both the integer value and the name of the status code along with a description of what each code is intended for:

* `200` - `success` - The request was successful.
* `400` - `bad_request` - The request couldn't be read. This is usually because it was not formed correctly. This can mean a number of things, check the response message for details:
  * The message size couldn't be read or was invalid.
  * The protocol version couldn't be read or didn't match the servers.
  * The message body couldn't be deserialized.
* `404` - `not_found` - The service name didn't match a configured service.
* `500` - `error` - An error occurred when calling the service. The message attribute of the response should be used to get more details.

## Advanced

### Daemonizing

Sanford uses the [daemons](https://github.com/ghazel/daemons) gem to daemonize it's server process. This is done using the daemons gem's `run_proc` method and starting the server in it:

```ruby
task :start do
  ::Daemons.run_proc(host.name, { :ARGV => [ 'start' ] }) do
    server.start
  end
end
```

Using daemons' `run_proc` and specifying `ARGV` runs daemons different actions: starting, stopping, running, etc. With this, `Sanford` provides rake tasks that wrap this behavior for easily managing your hosts.

