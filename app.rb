require 'sinatra/base'
require 'sinatra/activerecord'
require 'faye/websocket'
require 'json'
require 'thread'

class App < Sinatra::Base
  set :database, { adapter: "sqlite3", database: "db/development.sqlite3" }

  @connections = []

  get '/' do
    erb :index
  end

  def self.connections
    @connections
  end

  # Override instance method call
  def call(env)
    if Faye::WebSocket.websocket?(env) && env['PATH_INFO'] == '/websocket'
      puts "Incoming request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
      ws = Faye::WebSocket.new(env)

      ws.on :open do |_|
        self.class.connections << ws
        puts 'WebSocket opened'
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)
        msg = Message.create(content: data['content'])
        self.class.connections.each { |conn| conn.send({ id: msg.id, content: msg.content }.to_json) }
      end

      ws.on :close do |_|
        self.class.connections.delete(ws)
        puts 'WebSocket closed'
      end

      ws.rack_response
    else
      super(env)  # call Sinatra's normal handler
    end
  end
end
