require 'sinatra/base'
require 'sinatra/activerecord'
require 'faye/websocket'
require 'json'

class App < Sinatra::Base
  set :database, { adapter: 'sqlite3', database: 'db/development.sqlite3' }
  
  @connections = []

  def self.connections
    @connections
  end

  get '/' do
    erb :index
  end

  def call(env)
    if Faye::WebSocket.websocket?(env) && env['PATH_INFO'] == '/websocket'
      puts "Incoming request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
      ws = Faye::WebSocket.new(env, nil, ping: 15)

      ws.on :open do |_|
        self.class.connections << ws
        puts "WebSocket opened"
      end

      ws.on :message do |event|
        begin
          data = JSON.parse(event.data)
          msg = Message.create(content: data['content'])
          self.class.connections.each do |conn|
            conn.send({ id: msg.id, content: msg.content }.to_json)
          end
        rescue => e
          puts "Error in message handler: #{e.message}"
        end
      end

      ws.on :close do |event|
        self.class.connections.delete(ws)
        puts "WebSocket closed, code=#{event.code}, reason=#{event.reason}"
        ws = nil
      end

      ws.on :error do |event|
        puts "WebSocket error: #{event.message}"
      end

      return ws.rack_response
    else
      super(env)
    end
  end
end
