require 'spec_helper'

describe Message do
  
end

describe Message::Data do
  subject { Message::Data.new(123, "dummy") }

  its(:type) { should == :data }

  it { should be_data }

  it "should have the same session_id after pack/unpack" do
    Message.unpack(subject.pack).session_id.should == subject.session_id
  end

  it "should have the same data after pack/unpack" do
    Message.unpack(subject.pack).data.should == subject.data
  end
end

describe Message::OpenSession do
  its(:type) { should == :open_session }

  it { should be_open_session }

  it "should have the same session_id after pack/unpack" do
    subject.session_id = 123
    Message.unpack(subject.pack).session_id.should == subject.session_id
  end
end

describe Message::OpenTunnel do
  its(:type) { should == :open_tunnel }

  it { should be_open_tunnel }

  it "should have the same token after pack/unpack" do
    subject.token = 123
    Message.unpack(subject.pack).token.should == subject.token
  end
end

