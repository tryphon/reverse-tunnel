require 'spec_helper'

describe ReverseTunnel::Server::Tunnels do
  
  describe "#create_token" do
    
    it "should be very long" do
      subject.create_token.size.should >= 28
    end

  end

  describe "#available_local_port" do
    
    before do
      subject.local_port_range = 1000..1001
      subject.stub :used_local_ports => 1000
      subject.available_local_port.should == 1001
    end

  end

  describe "#create" do

    it "should create a default token when no specified" do
      subject.stub :create_token => "dummy"
      subject.create.token.should == "dummy" 
    end

    it "should use available local port when no specified" do
      subject.stub :available_local_port => 123
      subject.create.local_port.should == 123
    end

    it "should add tunnel" do
      tunnel = subject.create "token" => "test"
      subject.find("test").should == tunnel
    end

  end

end
