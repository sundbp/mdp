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
      @context = ZMQ::Context.new(1)
      connect_to_broker()
    end
  
    def connect_to_broker
      @client.close unless @client.nil?
      @client = @context.socket(ZMQ::DEALER)
      @client.setsockopt(ZMQ::LINGER, 0)
      @client.connect(@broker_endpoint)
    end
  
    def send(service, request = nil)
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
          log "Interrupted while in poll. Shutting down.."
        when ZMQ::EFAULT
          log "Invalid poll items! Shutting down.."
        when ZMQ::ETERM
          log "A socket with terminated context detected! Shutting down.."
        else
          log "zmq_poll() failed for unknown reason! Shutting down.."
        end
        return nil
      end
      
      if results == 1
        socket = poller.readables.first
        reply = ZMQ::StringMultipartMessage.new
        rc = socket.recv_strings(reply)
        if rc == -1
          log "zmq_recv() failed, baling out.."
          return nil
        end
        
        #log "Received message from broker:\n#{reply}"
        
        if reply.size < 3
          log "Invalid reply received (<3 parts), bailing out.."
        end
        
        # empty frame
        reply.pop
        
        header = reply.pop
        if header != MDP::MDPC_CLIENT
          log "Got a bad header, bailing out.."
          return nil
        end
        
        reply_service = reply.pop
        
        # success
        return reply
      
      elsif results > 1
        log "Somehow got more than 1 result from poll when listening to 1 socket - bailing!"
        return nil      
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
      @context.terminate
    end
  end
end
