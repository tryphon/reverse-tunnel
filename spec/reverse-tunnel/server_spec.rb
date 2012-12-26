require 'spec_helper'

describe ReverseTunnel::Server do
  
  describe "#server_host" do
    
    it "should be '0.0.0.0' by default" do
      subject.server_host.should == '0.0.0.0'
    end

  end

  describe "#server_port" do
    
    it "should be 4893 by default" do
      subject.server_port.should == 4893
    end

  end

  describe "#start_server" do
    it "should use server_host and server_port" do
      subject.server_host = "localhost"
      subject.server_port = 123

      EventMachine.should_receive(:start_server).with("localhost", 123, anything, anything)
      subject.start_server
    end
  end

  describe "#api_host" do
    
    it "should be '127.0.0.1' by default" do
      subject.api_host.should == '127.0.0.1'
    end

  end

  describe "#api_port" do
    
    it "should be 4894 by default" do
      subject.api_port.should == 4894
    end

  end

  describe "#start_api" do
    it "should use api_host and api_port" do
      subject.api_host = "localhost"
      subject.api_port = 123

      EventMachine.should_receive(:start_server).with("localhost", 123, anything, anything)
      subject.start_api
    end
  end

end
