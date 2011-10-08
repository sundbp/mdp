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
  MDPC_CLIENT = "MDPC01"
  MDPW_WORKER = "MDPW01"

  MDPW_READY      = 1.chr
  MDPW_REQUEST    = 2.chr
  MDPW_REPLY      = 3.chr
  MDPW_HEARTBEAT  = 4.chr
  MDPW_DISCONNECT = 5.chr
end
