require 'mdp/version'
require 'mdp/exceptions'

require 'mdp/broker'
require 'mdp/worker_session'
require 'mdp/client_session'
require 'mdp/async_client_session'

# MajorDomoProtocol module
#
# Contains all the classes used to participate in a majordomo
# service oriented system.
module MDP
  
  # Tag to identify a message as using the client protocol
  MDPC_CLIENT = "MDPC01"
  # Tag to identify a message as using the worker protocol
  MDPW_WORKER = "MDPW01"

  # Command to signify a worker has connected and is ready for requests
  MDPW_READY      = 1.chr
  # Command to signify a message is a request for a worker
  MDPW_REQUEST    = 2.chr
  # Command to signify a message is reply from a worker
  MDPW_REPLY      = 3.chr
  # Command to signify a heartbeat (either from broker to worker or the opposite)
  MDPW_HEARTBEAT  = 4.chr
  # Command to signify a worker is to disconnect from a broker
  MDPW_DISCONNECT = 5.chr
end
