require 'my-ffi-rzmq/multipart_message'

module ZMQ
  
  class StringMultipartMessage < ZMQ::MultipartMessage
    
    # Create a new message.
    # 
    # If msg_frames is provided the message will be initialized
    # to contain those message frames.
    #
    def initialize(msg_frames = [])
      super
    end
    
    # Add a frame to the front of the message.
    # 
    # Frame can be either a string or a ZMQ::Message. The method
    # copies out any string given in a ZMQ::Message (and the user
    # is still in charge of properly closing such a message).
    #
    def push(frame)
      msg_frame = case frame
      when String
        frame
      when ZMQ::Message
        frame.copy_out_string
      else
        raise ZMQ::MessageError.new("Tried to push a message from of unknown type: #{frame.class}")
      end
      @msg_frames.unshift(msg_frame)
    end
    
    # Remove the address from the front of a message.
    # 
    # Takes care of also removing any empty frame.
    #
    def unwrap
      frame = pop
      if @msg_frames.first.size == 0
        pop
      end
      frame
    end
  
    # Create a duplicate of the message.
    #
    def duplicate
      dup_frames = @msg_frames.map {|frame| frame.dup}
      ZMQ::StringMultipartMessage.new(dup_frames)
    end
    
  end # class StringMultipartMessage
end # module ZMQ
