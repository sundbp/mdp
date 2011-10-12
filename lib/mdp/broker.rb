require 'ffi-rzmq'
require 'mdp'

module MDP
  
  class Broker
    
    DEFAULTS = {
      :verbose => true,
      :heartbeat_interval => 2500, # in milliseconds
      :heartbeat_liveness => 3,
    }
    
    attr_reader :socket
  
    def initialize(endpoint = 'tcp://*:5555', options = {})
      @endpoint = endpoint
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
      @socket = @context.socket(ZMQ::ROUTER)
      
      @services = Hash.new
      @workers = Hash.new
      @waiting = []
    end
    
    def stop
      @run = false
      @logger.info "Service signalled to stop - #run will exit on next heartbeat."
    end
    
    def run
      @logger.info "Starting up broker on endpoint #{@endpoint}"
    
      @socket.bind(@endpoint)
      
      poller = ZMQ::Poller.new
      poller.register_readable(@socket)
      
      @next_heartbeat = next_heartbeat
      
      @run= true
      
      while @run do
        # num_workers = 0
        # @services.each do |name, svc|
        #   puts "service name: #{svc.name}\n"
        #   puts "num workers: #{svc.num_workers}\n"
        #   puts "num reqs: #{svc.requests.size}\n"
        #   svc.waiting.each do |w|
        #     puts "\tworker identity: #{w.identity}"
        #     puts "\tworker exp time: #{w.expiration_time}"
        #     num_workers += 1
        #   end
        # end
  
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
          break
        end
              
        if results == 1
    
          socket = poller.readables.first
    
          msg = ZMQ::StringMultipartMessage.new
          rc = socket.recv_strings(msg)
          if rc == -1
            if errno == ZMQ::EINTR
              log "Interrupted while reading msg. Shutting down.."
              break
            end
            log "zmq_recv() failed, going to skip this and see what happens.."
            process_heartbeat()
            next
          end
    
          sender = msg.pop
          empty  = msg.pop
          header = msg.pop
          
          case header
          when MDP::MDPC_CLIENT
            process_client(sender, msg)
          when MDP::MDPW_WORKER
            process_worker(sender, msg)
          else
            log "Invalid message found: #{header}"
            log "Skipping.."
          end
    
        elsif results > 1
          log "Somehow got more than 1 result from poll when listening to 1 socket - bailing!"
          break
        end
    
        process_heartbeat()
      end
      
      @logger.info "Told to stop in #run, shutting down.."
      shutdown()
      @logger.info "#run exiting"
    end
    
    def process_heartbeat
      if Time.now >= @next_heartbeat
        purge_workers()
        send_heartbeats()
        @next_heartbeat = next_heartbeat
      end
    end
    
    def heartbeat_interval
      @options[:heartbeat_interval]
    end
    
    def send_heartbeats
      @waiting.each {|worker| worker.send_heartbeat}
    end
    
    def log(msg)
      puts "#{Time.now} - #{msg}" if @options[:verbose]
    end
    
    def errno
      ZMQ::Util.errno
    end
    
    def shutdown
      @socket.close
      @context.terminate
    end
    
    def next_heartbeat
      Time.now + @options[:heartbeat_interval].to_f / 1000.0
    end
    
    def purge_workers
      @waiting.each do |worker|
        log "Removed expired worker" if worker.expired?
        delete_worker(worker, false) if worker.expired?
      end
    end
    
    def delete_worker(worker, disconnect)
      worker.send_disconnect if disconnect
      worker.service.remove_worker(worker) unless worker.service.nil?
      @waiting.delete(worker)
      @workers.delete(worker.identity)
    end
    
    def process_client(sender, msg)
      if msg.size < 2 # service_name and body
        reuturn
      end
    
      service_name = msg.pop
      service = require_service(service_name)
    
      msg.wrap(sender)
    
      if mmi_service? service_name
        internal_service(service_name, msg)
      else
        dispatch_service(service, msg)
      end
    end
    
    def dispatch_service(service, msg = nil)
      purge_workers()
      service.requests << msg unless msg.nil?
      
      while !service.waiting.empty? and !service.requests.empty?
        worker = service.require_worker()
        #log "Dispatching request for service #{service.name} to worker #{worker.identity}"
        @waiting.delete(worker)
        worker.send_request(service.requests.shift)
      end
    end
    
    def internal_service(service_name, msg)
      code = ""
      case service_name
      when "mmi.service"
        name = msg.last
        service = @services[name]
        code = if (service != nil) and (service.num_workers > 0)
          "200"
        else
          "404"
        end
      else
        code = "501"
      end
      
      client = msg.unwrap
      msg.push service_name
      msg.push MDP::MDPC_CLIENT
      msg.wrap(client)
      rc = @socket.send_messages(msg)
      log "Failed to send internal service reply! errno = #{errno}" if rc == -1
      rc
    end
    
    def strhex(str)
      ZMQ::Util.strhex(str)
    end
    
    def mmi_service?(name)
      name.size >= 4 and name.start_with? "mmi."
    end
      
    def require_service(service_name)
      if @services.has_key? service_name
        @services[service_name]
      else
        svc = Service.new(service_name)
        @services[service_name] = svc
        log "Added service: #{service_name}"
        svc      
      end
    end
    
    def process_worker(sender, msg)
      if msg.size < 1
        return
      end
    
      command = msg.pop
      identity = strhex(sender)
      existing_worker = @workers.has_key? identity
      worker = require_worker(sender)
      case command
      when MDP::MDPW_READY
        if existing_worker
          delete_worker(worker, true)
        elsif mmi_service? sender
          delete_worker(worker, true)
        else
          service_name = msg.pop
          worker.service = require_service(service_name)
          add_waiting_worker(worker)
        end
      when MDP::MDPW_REPLY
        if existing_worker
          client = msg.unwrap
          msg.push worker.service.name
          msg.push MDP::MDPC_CLIENT
          msg.wrap client
          @socket.send_strings(msg)
          add_waiting_worker(worker)
        else
          delete_worker(worker)
        end
      when MDP::MDPW_HEARTBEAT
        if existing_worker
          worker.expiration_time = next_expiry
        else
          delete_worker(worker, true)
        end
      when MDP::MDPW_DISCONNECT
          delete_worker(worker, false)
      else
        log "Invalid command: #{command}"
      end
    end
    
    def require_worker(address)
      identity = strhex(address)
      worker = @workers[identity]
      if worker.nil?
        worker = Worker.new(self, address, identity)
        @workers[identity] = worker
        log "Registered new worker #{identity}"
      end
      worker
    end
    
    def add_waiting_worker(worker)
      @waiting << worker
      worker.service.add_worker(worker)
      worker.expiration_time = next_expiry
      dispatch_service(worker.service)
    end
    
    def next_expiry
      Time.now + (@options[:heartbeat_interval] * @options[:heartbeat_liveness]).to_f / 1000.0
    end
  end
  
  ###################### PRIVATE ################################
  
  private
  
  class Service
    attr_reader :name
    attr_accessor :requests
    attr_accessor :waiting
    attr_accessor :num_workers
  
    def initialize(name)
      @name = name
      @requests = []
      @waiting = []
      @num_workers = 0
    end
  
    def add_worker(worker)
      @waiting.push worker
      @num_workers += 1
    end
  
    def remove_worker(worker)
      rc = @waiting.delete(worker)
      @num_workers -= 1 unless rc.nil?
    end
  
    def require_worker
      worker = @waiting.shift
      @num_workers -= 1 unless worker.nil?
      worker
    end
  end
  
  class Worker
    attr_accessor :expiration_time
    attr_accessor :service
    attr_reader :address
    attr_reader :identity
  
    def initialize(broker, address, identity)
      @broker = broker
      @address = address
      @identity = identity
      @service = nil
      @expiration_time = nil
    end
  
    def expired?
      @expiration_time < Time.now
    end
  
    def send_heartbeat
      send(MDP::MDPW_HEARTBEAT)
    end
  
    def send_disconnect
      send(MDP::MDPW_DISCONNECT)
    end
  
    def send_request(msg)
      send(MDP::MDPW_REQUEST, msg)
    end
  
    def send(command, input_msg = nil)
      msg = input_msg.nil? ? ZMQ::StringMultipartMessage.new : input_msg.duplicate
  
      msg.push command
      msg.push MDP::MDPW_WORKER
      msg.wrap(address)
  
      rc = @broker.socket.send_strings(msg)
      if rc == -1
        @broker.log "Failed to send message to worker! errno = #{ZMQ::Util.errno}"
      end
      rc
    end
  end
end
