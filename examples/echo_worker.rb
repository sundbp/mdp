require 'rubygems'
require 'bundler/setup'

require 'mdp'

class EchoWorker
  
  def initialize(broker_endpoint = 'tcp://127.0.0.1:5555')
    @session = MDP::WorkerSession.new("echo", :broker_endpoint => broker_endpoint)
  end
  
  def run
    reply = nil
    loop do
      request = @session.recv(reply)
      break if request.nil? # we got interrupted or failed
      #sleep 2
      reply = request
    end
    @session.shutdown
  end
  
end

worker = EchoWorker.new
worker.run