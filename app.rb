# app.rb
require 'sinatra'
require 'faye/websocket'
require 'json'

Faye::WebSocket.load_adapter('thin')

KEEPALIVE_TIME = 15
CLIENTS = []

class WebSocketBackend
  def initialize(app)
    @app = app
  end

  def call(env)
    if Faye::WebSocket.websocket?(env) && env['PATH_INFO'] == '/websocket'
      ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })

      ws.on :open do |event|
        CLIENTS << ws
        puts "[WS OPEN] Total: #{CLIENTS.count}"
      end

      ws.on :message do |event|
        puts "[WS MSG] #{event.data}"
        begin
          data = JSON.parse(event.data)
          CLIENTS.each { |client| client.send({ content: data["content"] }.to_json) }
        rescue => e
          puts "[WS ERROR] #{e.message}"
        end
      end

      ws.on :close do |event|
        CLIENTS.delete(ws)
        puts "[WS CLOSE] Code: #{event.code}, Reason: #{event.reason}"
        ws = nil
      end

      return ws.rack_response
    else
      @app.call(env)
    end
  end
end

use WebSocketBackend

get '/' do
  erb :index
end
