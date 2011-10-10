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
      @context = ZMQ::Context.new(1)
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
        raise "implement error handling - #{ZMQ::Util.errno}" if rc == -1
        
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
          
          header = reply.pop
          if header != MDP::MDPC_CLIENT
            log "Got a bad header, bailing out.."
            return nil
          end
          
          reply_service = reply.pop
          if reply_service != service
            log "Got reply from the wrong service, bailing out.."
            return nil
          end
          
          # success
          return reply
        
        elsif results > 1
          log "Somehow got more than 1 result from poll when listening to 1 socket - bailing!"
          return nil
          
        else # results == 0
          retries_left -= 1
          log "No reply, reconnecting.."
          poller.deregister_readable(@client)
          connect_to_broker()
        end
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
