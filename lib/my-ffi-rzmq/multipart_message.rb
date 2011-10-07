module ZMQ

  # A base class for multi part messages.
  # 
  # This class implements useful common methods for dealing with
  # multipart messages.
  #
  # Particular type of messages would subclass this class and implement
  # a few missing methods that can vary depending on for example how
  # memory is managed.
  # 
  # Two provided alternatives are RawMultipartMessage where the message
  # frames are represented as Message objects (and hence there is a need
  # for explicit memory management), and StringMultipartMessage where the
  # frames are represented as ruby strings (and hence no explicit memory
  # management required from the users perspective).
  #
  # The methods to override are: #push(frame), #unwrap, #duplicate
  #
  class MultipartMessage
    include Enumerable
    
    # Create a multipart message.
    #
    # Can provide an array of message frames to initialize the message with.
    #
    def initialize(msg_frames = [])
      @msg_frames = msg_frames
    end

    # Remove the first frame of the message and return it.
    #
    def pop
      @msg_frames.shift
    end

    # Get a given frame by index (or indices by range).
    #
    def [](index)
      @msg_frames[index]
    end

    # Returns the first frame of the message
    #
    def first
      @msg_frames.first
    end

    # Returns the last frame of the message
    #
    def last
      @msg_frames.last
    end

    # Wrap the message with an address.
    #
    # Convencience method for pushing an empty frame and
    # then pushing the address.
    #
    # The frames are added to the front of the message.
    # 
    def wrap(address)
      push ""
      push address
    end

    # Iterate through the frames of the message.
    #
    def each
      @msg_frames.each {|frame| yield frame}
    end

    # Returns the number of frames in the message.
    def size
      @msg_frames.size
    end
    
    # Returns true if there are no frames in the message.
    def empty?
      @msg_frames.empty?
    end

    # Return a string representation of the message.
    #
    # Relies on the frames having a #to_s method.
    #
    def to_s
      result = "#{self.class} (#{size} frames)\n"
      @msg_frames.each_with_index do |frame, index|
        result << "Frame #{index}: #{frame.to_s}\n"
      end
      result
    end

    # Add a frame to the message (positioning it at the end of message).
    #
    def add(frame)
      raise RuntimeError.new("#add on base class not implemented, need to implement in child classes!")
    end

    # Redirect << operator to #add method
    #
    def <<(frame)
      add(frame)
    end

    # Add a frame ot the front of the message.
    #
    # Not implemented in the base class.
    #
    def push(frame)
      raise RuntimeError.new("#push on base class not implemented, need to implement in child classes!")
    end
    
    # Unwrap the address of a message.
    #
    # Not implemented in the base class.
    #    
    def unwrap
      raise RuntimeError.new("#unwrap on base class not implemented, need to implement in child classes!")
    end
  
    # Create a duplicate of the message.
    #
    # Not implemented in the base class.
    #
    def duplicate
      raise RuntimeError.new("#duplicate on base class not implemented, need to implement in child classes!")
    end
  
  end # class MultipartMessage
end # module ZMQ
