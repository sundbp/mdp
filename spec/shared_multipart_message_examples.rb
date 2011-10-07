require 'my-ffi-rzmq/multipart_message'

shared_examples_for "ZMQ::MultipartMessage" do
    
  it "should support pop'ing frames" do
    subject << "foo"
    size = subject.size
    subject.pop.to_s.should == "foo"
    subject.size.should == size-1
    subject << "bar" << "foo"
    subject.pop.to_s.should == "bar"
  end

  it "should be possible to access frames via []" do
    subject.size.should == 0
    subject << "foo" << "bar"
    subject[0].to_s.should == "foo"
    subject[1].to_s.should == "bar"
    subject[0..1].map {|f| f.to_s}.should == ["foo", "bar"]
  end

  it "should return first frame on #first" do
    subject << "foo"
    subject << "bar"
    subject.first.to_s.should == "foo"
  end

  it "should return last frame on #last" do
    subject << "foo"
    subject << "bar"
    subject.last.to_s.should == "bar"
  end

  it "should correctly wrap messages" do
    subject.size.should == 0
    subject << "foo"
    subject.wrap("bar")
    subject.size.should == 3
    subject[0].to_s.should == "bar"
    subject[1].to_s.should == ""
    subject[2].to_s.should == "foo"
  end
  
  it "should support enumeration via #each" do
    subject << "foo"
    subject << "bar"
    count = 0
    subject.each {|f| f.should_not be_nil; count += 1}
    count.should == 2
  end
  
  it "should correctly determine the number of frames in a message" do
    subject.size.should == 0
    subject << "foo"
    subject.size.should == 1
    subject << "bar"
    subject.size.should == 2
  end
  
  it "should know it's empty if it has no frames" do
    subject.should be_empty
    subject << "foo"
    subject.should_not be_empty
  end
  
  it "should have a string representation" do
    subject << "foo"
    subject.to_s.class.should == String
    subject.to_s.should match(/\(\d+ frames\)/)
  end

  it "should be able to duplicate itself" do
    subject << "foo"
    subject << "bar"
    copy = subject.duplicate
    copy.size.should == subject.size
    copy.each_with_index {|frame, index| frame.to_s.should == subject[index].to_s}
  end

end
