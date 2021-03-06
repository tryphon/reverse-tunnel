# Reverse::Tunnel

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'reverse-tunnel'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install reverse-tunnel

## Usage

    reverse-tunnel server --public=88.190.240.120:4893 --api=172.20.11.9:3000 --range=172.20.11.9:10000-10100

    reverse-tunnel client --server=88.190.240.120:4893 --local-port=22 6B833D3F561369156820B4240C7C2657

    reverse-tunnel rt://console.tryphon.eu:4893/6B833D3F561369156820B4240C7C2657/22
    reverse-tunnel cnQ6Ly9jb25zb2xlLnRyeXBob24uZXU6NDg5My82QjgzM0QzRjU2MTM2OTE1NjgyMEI0MjQwQzdDMjY1Ny8yMg==

## API

Create a new tunnel :

    $ curl -X POST -d '{"token":"156820B4240C7C26576B833D3F561369","local_port":10001}' http://localhost:5000/tunnels.json
    {
        "token": "156820B4240C7C26576B833D3F561369",
        "local_port": 10001
    }

Retrieve current tunnels :

    $ curl http://localhost:5000/tunnels.json
    [
        {
            "token": "6B833D3F561369156820B4240C7C2657",
            "local_port": 10000,
        },
        {
            "token": "156820B4240C7C26576B833D3F561369",
            "local_port": 10001,
            "connection": {
                "peer": "127.0.0.1:42782",
                "created_at": "2012-12-22 17:29:55 +0100"
            }
        }
    ]


## Protocol

### Create tunnel

* POST /tunnels on server API (with optional token and local port)
* API returns token and local port

### Open tunnel

* client send tunnel token to server (on public ip:port)
* server opens a tcp server on local port (associated to token)
* client receives a confirmation message

### Ping tunnel

* every 30s (?) client sends a ping message
* server responds a pong message

### Use tunnel

* server receives a connection on tcp server on local port
* server creates a session (with id)
* server sends received data to client
* client creates local connection to local port (if not exist)
* client send received data to local connection
* client send back to server data received on local connection

### Messages

* OPEN_TUNNEL:tunnel_token
* PING
* PONG
* OPEN_SESSION:session_id
* DATA:session_id:data
* CLOSE_SESSION:session_id

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
