require 'my-ffi-rzmq/multipart_message'

module ZMQ
  
  # A class for dealing with multipart messages where each frame is
  # an instance of ZMQ::Message.
  # 
  # This requires the least copying and object creation but leaves
  # the user to explicitly close messages in order to ensure
  # correct memory management.
  #
  class RawMultipartMessage < ZMQ::MultipartMessage
    
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
    # wraps any string given in a ZMQ::Message for the user.
    #
    def push(frame)
      msg_frame = case frame
      when String
        ZMQ::Message.new(frame)
      when ZMQ::Message
        frame
      else
        raise ZMQ::MessageError.new("Tried to push a message from of unknown type: #{frame.class}")
      end
      @msg_frames.unshift(msg_frame)
    end
  
    # Remove the address from the front of a message.
    # 
    # Takes care of also removing any empty frame and properly close such a frame.
    #
    def unwrap
      frame = pop
      if @msg_frames.first.size == 0
        empty = pop
        empty.close
      end
      frame
    end

    # Create a duplicate of the message.
    #
    def duplicate
      dup_frames = @msg_frames.map {|frame| frame.duplicate}
      ZMQ::RawMultipartMessage.new(dup_frames)
    end
  
    # Close the message, which closes all its frames.
    #
    # Closing a message frees up any memory associated with the message
    # so any data is considered void after #close has finished.
    #
    def close
      @msg_frames.each {|frame| frame.close}
    end
    
  end # class MultipartRawMessage
end # module ZMQ
