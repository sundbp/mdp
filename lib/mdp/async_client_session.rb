require 'ffi-rzmq'
require 'mdp'

module MDP
  class AsyncClientSession
  
    DEFAULTS = {
      :verbose => true,
      :timeout => 5000, # in milliseconds
      :retries => 3,
    }
  
    def initialize(broker_endpoint = 'tcp://127.0.0.1:5555', options = {})
      @broker_endpoint = broker_endpoint
      @options = DEFAULTS.merge(options)
      @logger = if @options.has_key? :logger
        @options[:logger]
      else
        Logger.new(STDOUT)
      end        

      @context = if @options.has_key? :context
        @owner_of_context = false
        @options[:context]
      else
        @owner_of_context = true
        ZMQ::Context.create(1)
      end
      raise MDPError.new("Failed to create ZeroMQ context!") if @context.nil?
      connect_to_broker()
    end
  
    def connect_to_broker
      @client.close unless @client.nil?
      @client = @context.socket(ZMQ::DEALER)
      @client.setsockopt(ZMQ::LINGER, 0)
      @client.connect(@broker_endpoint)
    end
  
    def send(service, request)
      request.push service
      request.push MDP::MDPC_CLIENT
      request.push ""
      @client.send_strings(request)
    end
    
    def recv
      poller = ZMQ::Poller.new
  
      poller.register_readable(@client)
      results = poller.poll(@options[:timeout])
        
      if results == -1
        case errno
        when ZMQ::EINTR
          @logger.fatal "Interrupted while in poll. Shutting down.."
        when ZMQ::EFAULT
          @logger.fatal "Invalid poll items! Shutting down.."
        when ZMQ::ETERM
          @logger.fatal "A socket with terminated context detected! Shutting down.."
        else
          @logger.fatal "zmq_poll() failed for unknown reason! Shutting down.."
        end
        raise MDPError.new("Unrecoverable 0mq error when polling for replies")
      end
      
      if results == 1
        socket = poller.readables.first
        reply = ZMQ::StringMultipartMessage.new
        rc = socket.recv_strings(reply)
        if rc == -1
          case errno
          when ZMQ::EINTR
            @logger.fatal "Interrupted while in poll. Shutting down.."
          when ZMQ::EFAULT
            @logger.fatal "Invalid poll items! Shutting down.."
          when ZMQ::ETERM
            @logger.fatal "A socket with terminated context detected! Shutting down.."
          else
            @logger.fatal "zmq_poll() failed for unknown reason! Shutting down.."
          end
          raise MDPError.new("Unrecoverable 0mq error when receiving reply")
        end
        
        #log "Received message from broker:\n#{reply}"
        
        if reply.size < 3
          @logger.fatal "Invalid reply received (<3 parts)."
          return nil
        end
        
        # empty frame
        reply.pop
        
        header = reply.pop
        if header != MDP::MDPC_CLIENT
          @logger.fatal "Received invalid header, bailing out.."
          return nil
        end
        
        reply_service = reply.pop
        
        # success
        return reply
      
      elsif results > 1
        @logger.fatal "Somehow got more than 1 result from poll when listening to 1 socket - bailing!"
        raise MDPError.new("Very confused, getting more results from poll than I'm looking for")
      end
      
      nil    
    end
  
    def log(msg)
      puts msg if @options[:verbose]
    end
    
    def errno
      ZMQ::Util.errno
    end
    
    def shutdown
      @client.close unless @client.nil?
      if @owner_of_context
        @context.terminate unless @context.nil?
      end
    end
  end
end
