require 'logger'
require 'ffi-rzmq'
require 'mdp'

module MDP
  class ClientSession
  
    DEFAULTS = {
      :verbose => true,
      :timeout => 2500, # in milliseconds
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
      @client = @context.socket(ZMQ::REQ)
      @client.setsockopt(ZMQ::LINGER, 0)
      @client.connect(@broker_endpoint)
    end
  
    def send(service, request = nil)
      request.push service
      request.push MDP::MDPC_CLIENT
      
      retries_left = @options[:retries]
  
      poller = ZMQ::Poller.new
  
      while retries_left > 0
        msg = request.duplicate
        rc = @client.send_strings(msg)
        if rc == -1
          case errno
          when ZMQ::ENOTSUP
            @logger.fatal "Can't send messages on this socket."
          when ZMQ::EFSM
            @logger.fatal "Can't send messages on this socket in it's current state."
          when ZMQ::ETERM
            @logger.fatal "The associated 0mq context is terminated."
          when ZMQ::EINTR
            @logger.fatal "The operation was interrupted."
          when ZMQ::EFAULT
            @logger.fatal "Invalid message."
          end
          raise MDPError.new("Unrecoverable 0mq error when sending request")
        end
        
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
          raise MDPError.new("Unrecoverable 0mq error when polling for reply")
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
          
          if reply.size < 3
            @logger.fatal "Invalid reply received (<3 parts)."
            return nil
          end
          
          header = reply.pop
          if header != MDP::MDPC_CLIENT
            @logger.fatal "Received invalid header, bailing out.."
            return nil
          end
          
          reply_service = reply.pop
          if reply_service != service
            @logger.fatal "Got reply from the wrong service."
            return nil
          end
          
          # success
          return reply
        
        elsif results > 1
          @logger.fatal "Somehow got more than 1 result from poll when listening to 1 socket - bailing!"
          raise MDPError.new("Very confused, getting more results from poll than I'm looking for")
          
        else # results == 0
          retries_left -= 1
          @logger.info "No reply, reconnecting and retrying.."
          poller.deregister_readable(@client)
          connect_to_broker()
        end
      end
      nil
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
