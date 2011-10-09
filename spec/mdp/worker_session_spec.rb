require 'spec_helper'

describe MDP::WorkerSession do

  describe "#recv" do
    context "when no message has been sent or received" do
      it "sends a ready message on connecting to the broker"
      it "fails if trying to send a reply (since nothing to reply to)"
      it "sends a heartbeat after the right amount of time waiting for a request"
      it "handles timeout and try to reconnect to broker correctly"
      it "handles handle receiving a heartbeat from the broker"
      it "handles receiving a disconnect from the broker"
      it "raises if connecting to broker fails"
    end
  
    context "receiving message" do
      it "fails if the message is malformed"
      it "fails if the session is interrupted"
      it "raises if poll fails for other reasons"
    end
  
    context "when having received a request" do
      it "should send a reply"
      it "should fail if no reply is given"
      it "should send a reply and wait for the next request"
    end
  end

  describe "#shutdown" do
    it "closes 0mq socket and context if open"
  end

end
