require 'ffi-rzmq'
require 'my-ffi-rzmq/string_multipart_message' # until merged into gem
require 'mdp'

module MDP
  
  # Represents a worker session.
  # 
  # A worker in MDP is something responding to requests for a given service.
  # A worker registers with a broker and will then be forwarded client requests. 
  # Many workers for the same service can be running to scale out performance.
  # The broker will ensure the client requests are shared among the workers in
  # a sensible way.
  #
  # The typical flow of a worker looks something like this:
  # @example
  #   class EchoWorker
  #     def initialize(broker_endpoint = 'tcp://127.0.0.1:5555')
  #       @session = MDP::WorkerSession.new("echo", :broker_endpoint => broker_endpoint)
  #     end
  #   
  #     def run
  #       reply = nil
  #       loop do
  #         request = @session.recv(reply)
  #         break if request.nil? # we got interrupted or failed
  #         reply = request
  #       end
  #       @session.shutdown
  #     end
  #   end
  #
  # On a multi-core machine there is nothing stopping us having one process
  # with several threads where each thread is a worker.
  class WorkerSession
    
    # @attr_reader [String] service_name The name of the service the worker serves requests for
    attr_reader :service_name
    
    # Defaults used for the worker
    #
    # Note that the worker settings around heartbeats should be
    # compatible with what the broker is expecting.
    DEFAULTS = {
      :verbose => true,
      :heartbeat_interval => 2500, # in milliseconds
      :heartbeat_liveness => 3, # in milliseconds
      :reconnect_interval => 2500, # in milliseconds
    }
  
    # Create a worker session
    #
    # Note this creates a 0mq context and attempts to connect a 0mq socket to the broker.
    #
    # @param [String] service_name the name of the service this worker serves requests for
    # @param [String] broker_endpoint where the broker to connect to lives
    # @param [Hash] options a hash of options to override the DEFAULTS
    # @option options [true|false] :verbose turn on verbose output via the logger
    # @option options [Fixnum] :hearbeat_interval the hearbeat intervall given in milliseconds
    # @option options [Fixnum] :hearbeat_liveness how many hearbeats can fail before we reconnect
    # @option options [Fixnum] :reconnect_interval how long to wait before reconnecting
    # @option options [#log] :logger a custom logger to be used by session
    def initialize(service_name, 
                   broker_endpoint = 'tcp://127.0.0.1:5555',
                   options = {})
      @service_name = service_name
      @broker_endpoint = broker_endpoint
      @options = DEFAULTS.merge(options)
      @context = ZMQ::Context.create(1)
      raise MDPError.new("Failed to create ZeroMQ context!") if @context.nil?
      connect_to_broker()
    end
  
    # Connect the worker session to the broker
    # 
    # This will close an already open socket, and create a new socket it connects
    # to the broker endpoint.
    #
    # Resets when the next heartbeat is to take place.
    # @return self
    def connect_to_broker
      @worker.close unless @worker.nil?
      @worker = @context.socket(ZMQ::DEALER)
      raise MDPError.new("Failed to create ZeroMQ socket!") if @worker.nil?
      rc = @worker.setsockopt(ZMQ::LINGER, 0)
      raise MDPError.new("Failed to set socket options!") unless ZMQ::Util.resultcode_ok?(rc)
      rc = @worker.connect(@broker_endpoint)
      raise MDPError.new("Failed to connect socket!") unless ZMQ::Util.resultcode_ok?(rc)
      send_ready
      @liveness = @options[:heartbeat_liveness]
      @next_heartbeat = next_heartbeat
      self
    end

    # Reconnect the worker session to the broker
    #
    # This essentially calls (#connect_to_broker) but also handles de/re-registering
    # the socket to a given poller.
    #
    # @param [ZMQ::Poller] poller an already existing poller used by the worker.
    # @return self
    def reconnect(poller)
      poller.deregister_readable @worker
      connect_to_broker()
      poller.register_readable @worker
      self
    end

    # Receive a client request (and deliver any existing reply)
    #
    # This method tends to be used in a loop like this:
    #
    # reply = nil
    # loop do
    #   request = @session.recv(reply)
    #   break if request.nil? # we got interrupted or failed
    #   reply = handle_request(request)
    # end
    # 
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
            raise MDPError.new("Invalid poll items!")
          when ZMQ::ETERM
            raise MDPError.new("A socket with terminated context detected!")
          else
            raise MDPError.new("zmq_poll() failed for unknown reason!")
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
            log "Received an invalid message - header not valid: #{header}\n#{msg}"
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
            log "Invalid input message received: #{command}\n#{msg}"
          end          
        
        elsif results == 0
          @liveness -= 1
          if @liveness == 0
            sleep(@options[:reconnect_interval].to_f / 1000.0)
            log "Disconnected from broker - retrying.." 
            reconnect(poller)
          end
          
        elsif results > 1
          raise MDPError.new("Somehow got more than 1 result from poll when listening to 1 socket - bailing!")
        end
        
        process_heartbeat()
      end
      
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
      raise MDPError.new("Trying to send msg on socket that isn't open!") if @worker.nil?
      rc = @worker.send_strings(msg)
      raise MDPError.new("Failed to send msg!") unless ZMQ::Util.resultcode_ok?(rc)
      rc
    end
    
    def next_heartbeat
      Time.now + heartbeat_interval.to_f / 1000.0
    end
  
    def heartbeat_interval
      @options[:heartbeat_interval]
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
      @context.terminate unless @context.nil?
    end
    
  end # class WorkerSession
end # module MDP
