require 'spec_helper'
require 'my-ffi-rzmq/message'

describe ZMQ::Message do
  
  it "should handle #strhex via ZMQ::Util.strhex" do
    str = "foobar"
    begin
      msg = ZMQ::Message.new(str)
      ZMQ::Util.stub(:strhex).and_return("ok")
      msg.strhex.should == "ok"
    ensure
      msg.close unless msg.nil?
    end
  end
  
  it "should be able duplicate itself" do
    begin
      msg = ZMQ::Message.new("foo")
      msg2 = msg.duplicate
      msg2.copy_out_string.should == msg.copy_out_string
    ensure
      msg.close unless msg.nil?
      msg2.close unless msg2.nil?
    end
  end
  
  it "should have a string representation via #to_s" do
    begin
      msg = ZMQ::Message.new("foobar")
      msg.to_s.should match(/foobar/)
    ensure
      msg.close unless msg.nil?
    end
  end
  
  it "should know if it is empty or not" do
    begin
      msg = ZMQ::Message.new
      msg.should be_empty
      msg2 = ZMQ::Message.new("")
      msg2.should be_empty
      msg3 = ZMQ::Message.new("foo")
      msg3.should_not be_empty
    ensure
      msg.close unless msg.nil?
      msg2.close unless msg.nil?
      msg3.close unless msg.nil?
    end
  end
  
end