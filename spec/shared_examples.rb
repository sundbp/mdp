require 'my-ffi-rzmq/multipart_message'

shared_examples_for "ZMQ::MultipartMessage" do
  
  it "should be possible to add frames" do
    size_before = subject.size
    subject.add "foo"
    subject.size.should == size_before+1
    subject.last.should == "foo"
    subject << "bar"
    subject.size.should == size_before+2
    subject.last.should == "bar"
  end

  it "should support pop'ing frames" do
    subject << "foo"
    size = subject.size
    subject.pop.should == "foo"
    subject.size.should == size-1
    subject << "bar" << "foo"
    subject.pop.should == "bar"
  end

  it "should be possible to access frames via []" do
    subject.size.should == 0
    subject << "foo" << "bar"
    subject[0].should == "foo"
    subject[1].should == "bar"
    subject[0..1].should == ["foo", "bar"]
  end

end
