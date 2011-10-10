require 'rubygems'
require 'bundler/setup'

require 'mdp'

session = MDP::ClientSession.new

num_msgs = 1000

t1 = Time.now
num_msgs.times do |index|
  request = ZMQ::StringMultipartMessage.new
  the_message = "hello world #{index}"
  request.push the_message
  reply = session.send("echo", request)
  if reply.nil?
    puts "No reply - giving up and shutting down!"
    session.shutdown
    break
  end
  
  rep = reply.pop
  raise "incorrect reply" if rep != the_message
end
session.shutdown

t2 = Time.now
puts "Time elapsed: #{t2-t1}"
puts "msgs/second: #{num_msgs.to_f / (t2-t1).to_f}"
