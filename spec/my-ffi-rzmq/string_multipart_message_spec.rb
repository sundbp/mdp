require 'spec_helper'
require 'shared_multipart_message_examples'
require 'my-ffi-rzmq/message'
require 'my-ffi-rzmq/string_multipart_message'

describe ZMQ::StringMultipartMessage do
  
  it_behaves_like "ZMQ::MultipartMessage"

  it "should be possible to add string frames" do
    subject.size.should == 0
    subject.add "foo"
    subject.size.should == 1
    subject.last.class.should == String
    subject.last.to_s.should == "foo"
    subject.add "bar"
    subject.size.should == 2
    subject.last.class.should == String
    subject.last.to_s.should == "bar"
  end

  it "should be possible to add ZMQ::Message frames" do
    begin
      subject.size.should == 0
      msg1 = ZMQ::Message.new("foo")
      subject.add msg1
      subject.size.should == 1
      subject.last.class.should == String
      subject.last.to_s.should == "foo"
      msg2 = ZMQ::Message.new("bar")
      subject.add msg2
      subject.size.should == 2
      subject.last.class.should == String
      subject.last.to_s.should == "bar"
    ensure
      msg1.close unless msg1.nil?
      msg2.close unless msg2.nil?
    end
  end
    
  it "should be possible to push string frames" do
    subject.size.should == 0
    subject.push "foo"
    subject.size.should == 1
    subject.first.class.should == String
    subject.first.to_s.should == "foo"
    subject.push "bar"
    subject.size.should == 2
    subject.first.class.should == String
    subject.first.to_s.should == "bar"
  end

  it "should be possible to push ZMQ::Message frames" do
    begin
      subject.size.should == 0
      msg1 = ZMQ::Message.new("foo")
      subject.push msg1
      subject.size.should == 1
      subject.first.class.should == String
      subject.first.to_s.should == "foo"
      msg2 = ZMQ::Message.new("bar")
      subject.push msg2
      subject.size.should == 2
      subject.first.class.should == String
      subject.first.to_s.should == "bar"
    ensure
      msg1.close unless msg1.nil?
      msg2.close unless msg2.nil?
    end
  end

  it "should correctly unwrap messages when a blank frame exists" do
    subject.push "foo"
    subject.push ""
    subject.push "bar"
    result = subject.unwrap
    result.to_s.should == "bar"
    subject.size.should == 1
    subject.first.to_s.should == "foo"
  end

  it "should correctly unwrap messages when a blank frame does not exists" do
    subject.push "foo"
    subject.push "bar"
    result = subject.unwrap
    result.to_s.should == "bar"
    subject.size.should == 1
    subject.first.to_s.should == "foo"
  end
  
end
