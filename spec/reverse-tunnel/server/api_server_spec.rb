require 'spec_helper'

require "rest_client"
require "json"

describe ReverseTunnel::Server::ApiServer do

  let(:server) { ReverseTunnel::Server.new }

  let(:api_host) { "127.0.0.1" }
  let(:api_port) { 38589 }

  def url(path)
    "http://#{api_host}:#{api_port}#{path}"
  end

  def get(path)
    JSON.parse RestClient.get url(path)
  end

  def post(path, params)
    JSON.parse RestClient.post url(path), params.to_json
  end

  def delete(path)
    JSON.parse RestClient.delete url(path)
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
        EventMachine.start_server api_host, api_port, ReverseTunnel::Server::ApiServer, server
      end
    end

    wait_api
  end

  describe "GET '/tunnels'" do
    
    it "should return an empty array without tunnels" do
      get("/tunnels").should be_empty
    end

    it "should return tunnels description" do
      tunnel = server.tunnels.create
      get("/tunnels").should include("token" => tunnel.token, "local_port" => tunnel.local_port)
    end

    it "should accept requests on /tunnels.json" do
      get("/tunnels.json").should == get("/tunnels")
    end

  end

  describe "POST '/tunnels'" do

    it "should create a new tunnel" do
      post("/tunnels", :token => "dummy")
      server.tunnels.find("dummy").should_not be_nil
    end

    it "should return new tunnel description" do
      post("/tunnels", :token => "dummy")["token"].should == "dummy"
    end
    
  end

  describe "GET '/tunnels/:id'" do
    
    it "should return tunnel description" do
      tunnel = server.tunnels.create
      get("/tunnels/#{tunnel.token}")["local_port"].should == tunnel.local_port
    end

    it "should return a 404 when tunnel doesn't exist" do
      lambda { get("/tunnels/123") }.should raise_error(RestClient::ResourceNotFound)
    end

  end

  describe "DELETE '/tunnels/:id'" do
    
    it "should delete the specified tunnel" do
      tunnel = server.tunnels.create
      delete("/tunnels/#{tunnel.token}")
      server.tunnels.find(tunnel.token).should be_nil
    end

    it "should return a 404 when tunnel doesn't exist" do
      lambda { delete("/tunnels/123") }.should raise_error(RestClient::ResourceNotFound)
    end

  end

  after do
    EventMachine.stop
    wait_api_stopped
  end
  
end
