require 'spec_helper'

describe ReverseTunnel::CLI do

  describe "#debug=" do

    context "when true" do
      it "should change Logger level to debug" do
        ReverseTunnel.logger.level = Logger::INFO
        lambda {
          subject.debug = true
        }.should change(ReverseTunnel.logger, :level).to(Logger::DEBUG)
      end
    end

    context "when false" do
      it "should change Logger level to info" do
        ReverseTunnel.logger.level = Logger::DEBUG
        lambda {
          subject.debug = false
        }.should change(ReverseTunnel.logger, :level).to(Logger::INFO)
      end
    end

    after do
      ReverseTunnel.reset_logger!
    end

  end

  describe "#syslog=" do

    context "when true" do
      
      it "should change ReverseTunnel.logger to Syslog::Logger" do
        subject.syslog = true
        ReverseTunnel.logger.should be_instance_of(Syslog::Logger)
      end

      after do
        ReverseTunnel.reset_logger!
      end
                          
    end
    
  end

  



end


describe ReverseTunnel::CLI::Configurator do

  describe "#server=" do
    
    it "should parse ip and port" do
      subject.should_receive(:server_host=).with("host")
      subject.should_receive(:server_port=).with(4893)
      
      subject.server = "host:4893"
    end

  end
  
end

describe ReverseTunnel::CLI::Client do

  describe "#api=" do
    
    it "should parse ip and port" do
      subject.should_receive(:api_host=).with("host")
      subject.should_receive(:api_port=).with(4895)
      
      subject.api = "host:4895"
    end

  end

  describe "#token" do

    it "should use first argument" do
      subject.stub :arguments => [ "token"]
      subject.token.should == "token"
    end
    
  end

end

describe ReverseTunnel::CLI::Server do

  describe "#api=" do
    
    it "should parse ip and port" do
      subject.should_receive(:api_host=).with("host")
      subject.should_receive(:api_port=).with(4894)
      
      subject.api = "host:4894"
    end

  end

  describe "#local=" do
    
    it "should parse ip and port range" do
      subject.should_receive(:local_host=).with("host")
      subject.should_receive(:local_port_range=).with(123..456)
      
      subject.local = "host:123-456"
    end

  end

end
