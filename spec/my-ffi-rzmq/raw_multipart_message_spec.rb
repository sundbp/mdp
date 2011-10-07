require 'spec_helper'
require 'shared_multipart_message_examples'
require 'my-ffi-rzmq/message'
require 'my-ffi-rzmq/raw_multipart_message'

describe ZMQ::RawMultipartMessage do

  after(:each) do
    subject.close
  end
  
  it_behaves_like "ZMQ::MultipartMessage"

  it "should be possible to add string frames" do
    subject.size.should == 0
    subject.add "foo"
    subject.size.should == 1
    subject.last.class.should == ZMQ::Message
    subject.last.to_s.should == "foo"
    subject.add "bar"
    subject.size.should == 2
    subject.last.class.should == ZMQ::Message
    subject.last.to_s.should == "bar"
  end

  it "should be possible to add ZMQ::Message frames" do
    subject.size.should == 0
    subject.add ZMQ::Message.new("foo")
    subject.size.should == 1
    subject.last.class.should == ZMQ::Message
    subject.last.to_s.should == "foo"
    subject.add ZMQ::Message.new("bar")
    subject.size.should == 2
    subject.last.class.should == ZMQ::Message
    subject.last.to_s.should == "bar"
  end
    
  it "should be possible to push string frames" do
    subject.size.should == 0
    subject.push "foo"
    subject.size.should == 1
    subject.first.class.should == ZMQ::Message
    subject.first.to_s.should == "foo"
    subject.push "bar"
    subject.size.should == 2
    subject.first.class.should == ZMQ::Message
    subject.first.to_s.should == "bar"
  end

  it "should be possible to push ZMQ::Message frames" do
    subject.size.should == 0
    subject.push ZMQ::Message.new("foo")
    subject.size.should == 1
    subject.first.class.should == ZMQ::Message
    subject.first.to_s.should == "foo"
    subject.push ZMQ::Message.new("bar")
    subject.size.should == 2
    subject.first.class.should == ZMQ::Message
    subject.first.to_s.should == "bar"
  end

  it "should correctly unwrap messages when a blank frame exists" do
    begin
      empty_frame = ZMQ::Message.new("")
      # make sure it's closed, will prob cause test to leak but no big deal
      closed = false
      empty_frame.should_receive(:close) do
        closed = true
      end
      subject.push "foo"
      subject.push empty_frame
      subject.push "bar"
      result = subject.unwrap
      result.to_s.should == "bar"
      subject.size.should == 1
      subject.first.to_s.should == "foo"
      closed.should be_true
    ensure
      result.close unless result.nil?
    end
  end

  it "should correctly unwrap messages when a blank frame does not exists" do
    begin
      subject.push "foo"
      subject.push "bar"
      result = subject.unwrap
      result.to_s.should == "bar"
      subject.size.should == 1
      subject.first.to_s.should == "foo"
    ensure
      result.close unless result.nil?
    end    
  end
  
  it "should close it's frames when closed" do
    msg1 = ZMQ::Message.new("foo")
    msg2 = ZMQ::Message.new("bar")
    msg1_closed = false
    msg2_closed =false
    msg1.stub(:close) {msg1_closed = true}
    msg2.stub(:close) {msg2_closed = true}    
    subject << msg1 << msg2
    subject.close
    msg1_closed.should be_true
    msg2_closed.should be_true
  end
end
