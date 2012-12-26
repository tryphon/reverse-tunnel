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


end
