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
      msg.close
    end
  end
  
  it "should be able duplicate itself" do
    begin
      msg = ZMQ::Message.new("foo")
      msg2 = msg.duplicate
      msg2.copy_out_string.should == msg.copy_out_string
    ensure
      msg.close
      msg2.close
    end
  end
  
  it "should have a string representation via #to_s" do
    begin
      msg = ZMQ::Message.new("foobar")
      msg.to_s.should match(/foobar/)
    ensure
      msg.close
    end
  end
  
end