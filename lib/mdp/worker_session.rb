require 'ffi-rzmq'
require 'my-ffi-rzmq/string_multipart_message' # until merged into gem
require 'mdp'

module MDP
  class WorkerSession
  
    attr_reader :service_name
    
    DEFAULTS = {
      :verbose => true,
      :heartbeat_interval => 2500, # in milliseconds
      :heartbeat_liveness => 3, # in milliseconds
      :reconnect_interval => 2500, # in milliseconds
    }
  
    def initialize(service_name, 
                   broker_endpoint = 'tcp://127.0.0.1:5555',
                   options = {})
      @service_name = service_name
      @broker_endpoint = broker_endpoint
      @options = DEFAULTS.merge(options)
      @context = ZMQ::Context.new(1)
      connect_to_broker()
    end
  
    def connect_to_broker
      @worker.close unless @worker.nil?
      @worker = @context.socket(ZMQ::DEALER)
      @worker.setsockopt(ZMQ::LINGER, 0)
      @worker.connect(@broker_endpoint)
      send_ready
      @liveness = @options[:heartbeat_liveness]
      @next_heartbeat = next_heartbeat
    end
  
    def send_ready
      send(MDP::MDPW_READY, self.service_name)
    end
  
    def send_reply(reply)
      send(MDP::MDPW_REPLY, nil, reply)
    end
    
    def send_heartbeat
      send(MDP::MDPW_HEARTBEAT)
    end
    
    def send(command, option = nil, input_msg = nil)
      msg = input_msg.nil? ? ZMQ::StringMultipartMessage.new : input_msg.duplicate
      msg.push option unless option.nil?
      msg.push command
      msg.push MDP::MDPW_WORKER
      msg.push ""
      rc = @worker.send_strings(msg)
      if rc == -1
        log "Failed to send message to broker! errno = #{ZMQ::Util.errno}"
      end
      rc
    end
    
    def next_heartbeat
      Time.now + @options[:heartbeat_interval].to_f / 1000.0
    end
  
    def heartbeat_interval
      @options[:heartbeat_interval]
    end
    
    def recv(reply = nil)
      return nil if reply.nil? and @expect_reply
  
      unless reply.nil?
        return nil if @reply_to.nil?
        reply.wrap(@reply_to)
        send_reply(reply)
      end
  
      @expect_reply = true
      
      poller = ZMQ::Poller.new
      poller.register_readable(@worker)
  
      loop do
        results = poller.poll(heartbeat_interval)
      
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
          msg = ZMQ::StringMultipartMessage.new
          rc = socket.recv_strings(msg)
          if rc == -1
            log "zmq_recv() failed, going to skip this and see what happens.."
            process_heartbeat()
            next
          end
          
          @liveness = @options[:heartbeat_liveness]
          
          # is it a valid message? if not just skip it
          if msg.size < 2
            log "Message too short (<2 frames), skipping it:\n#{msg}"
            next
          end
          
          # skip empty frame
          msg.pop
          
          header = msg.pop
          
          # is this a valid message? if not just skip it
          if header != MDP::MDPW_WORKER
            log "Received an invalid message - header not valid: #{header.copy_out_string}\n#{msg}"
            next
          end        
          
          command = msg.pop
          
          case command
          when MDP::MDPW_REQUEST
            @reply_to = msg.unwrap
            return msg
            
          when MDP::MDPW_HEARTBEAT
            # nothing needed
            
          when MDP::MDPW_DISCONNECT
            reconnect(poller)
            
          else
            log "Invalid input message received: #{command.copy_out_string}\n#{msg}"
          end
          
          # close the inputs
        
        elsif results == 0
          @liveness -= 1
          if @liveness == 0
            log "Disconnected from broker - retrying.." 
            sleep(@options[:reconnect_interval].to_f / 1000.0)
            reconnect(poller)
          end
          
        elsif results > 1
          log "Somehow got more than 1 result from poll when listening to 1 socket - bailing!"
          return nil
        end
        
        process_heartbeat()
      end
      
    end
  
    def reconnect(poller)
      poller.deregister_readable @worker
      connect_to_broker()
      poller.register_readable @worker
    end
    
    def log(msg)
      puts "#{Time.now} - #{msg}" if @options[:verbose]
    end
    
    def errno
      ZMQ::Util.errno
    end
    
    def process_heartbeat
      if Time.now > @next_heartbeat
        send_heartbeat()
        @next_heartbeat = next_heartbeat
      end
    end
    
    def shutdown
      @worker.close unless @worker.nil?
      @context.terminate
    end
  end
end
