require 'ffi-rzmq/message'
require 'my-ffi-rzmq/util'

module ZMQ
  class Message
  
    # Convenience method that calls ZMQ::Util.strhex.
    #
    def strhex
      ZMQ::Util.strhex(self.copy_out_string)
    end
  
    # Create a dubplicate of this message.
    #
    # This creates a new Message instance and copy the content of
    # this message to the new instance (via #close/zmq_msg_copy).
    #
    def duplicate
      dup = ZMQ::Message.new
      dup.copy(self)
      dup
    end
  
    # Return the data of this message as a string.
    # 
    # What is returned is a normal ruby string and user does
    # not need to worry about any memory management issues.
    #
    def to_s
      copy_out_string
    end
    
  end # class Message
end # module ZMQ