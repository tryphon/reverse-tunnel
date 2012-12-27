require 'spec_helper'

require "rest_client"
require "json"

describe ReverseTunnel::Client::ApiServer do

  let(:tunnel) { mock :to_json => '{"token":"1008B1A077343ED8B7AAAC9BC580","local_port":22,"server_host":"localhost","server_port":4893,"local_connections":[],"connection":{"created_at":"2012-12-27 12:13:50 +0100"}}' }

  let(:api_host) { "127.0.0.1" }
  let(:api_port) { 38589 }

  def url(path)
    "http://#{api_host}:#{api_port}#{path}"
  end

  def get(path)
    JSON.parse RestClient.get url(path)
  end

  def wait_api
    5.times do
      begin
        s = TCPSocket.new(api_host, api_port)
        s.close
        return true
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
    end
  end

  def wait_api_stopped
    5.times do
      begin
        s = TCPSocket.new(api_host, api_port)
        s.close
        sleep 0.1
      rescue Errno::ECONNREFUSED
        return true
      end
    end
  end

  before do
    Thread.new do
      EventMachine.run do
        EventMachine.start_server api_host, api_port, ReverseTunnel::Client::ApiServer, tunnel
      end
    end

    wait_api
  end

  describe "GET '/status'" do
    
    it "should return tunnel description" do
      get("/status").should == JSON.parse(tunnel.to_json)
    end

    it "should accept requests on /tunnels.json" do
      get("/status.json").should == get("/status")
    end

  end

  after do
    EventMachine.stop
    wait_api_stopped
  end
  
end
