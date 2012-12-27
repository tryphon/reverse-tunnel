require 'spec_helper'

describe ReverseTunnel::Client do
  
  describe "#server_host" do
    
    it "should be nil by default" do
      subject.server_host.should be_nil
    end

  end

  describe "#server_port" do
    
    it "should be 4893 by default" do
      subject.server_port.should == 4893
    end

  end

  describe "#local_port" do
    
    it "should be 22 by default" do
      subject.local_port.should == 22
    end

  end

  describe "#api_host" do
    
    it "should be nil by default" do
      subject.api_host.should be_nil
    end

  end

  describe "#api_port" do
    
    it "should be 4895 by default" do
      subject.api_port.should == 4895
    end

  end

  describe "#tunnel" do
    it "should use server_host" do
      subject.server_host = "localhost"
      subject.tunnel.host.should == "localhost"
    end

    it "should use server_port" do
      subject.server_port = 123
      subject.tunnel.port.should == 123
    end

    it "should use local_port" do
      subject.local_port = 123
      subject.tunnel.local_port.should == 123
    end
  end

  describe "#start_api" do
    it "should use api_host and api_port" do
      subject.api_host = "localhost"
      subject.api_port = 123

      EventMachine.should_receive(:start_server).with("localhost", 123, anything, anything)
      subject.start_api
    end

    it "should not start api if api_host is not defined" do
      subject.api_host = nil

      EventMachine.should_not_receive(:start_server)
      subject.start_api
    end
  end

end
