require 'rubygems'
require 'bundler/setup'

require 'mdp'

session = MDP::AsyncClientSession.new

num_msgs = 1000

t1 = Time.now
num_msgs.times do |index|
  request = ZMQ::StringMultipartMessage.new
  the_message = "hello world #{index}"
  request.push the_message
  session.send("echo", request)
end

t2 = Time.now

puts "Time elapsed: #{t2-t1}"

num_msgs.times do |index|
  reply = session.recv
  if reply.nil?
    puts "No reply - giving up and shutting down!"
    session.shutdown
    break
  en  
  rep = reply.pop
end
session.shutdown

t3 = Time.now

puts "Time elapsed: #{t3-t1}"
puts "msgs/second: #{num_msgs.to_f / (t3-t1).to_f}"
