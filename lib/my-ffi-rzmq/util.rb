module ZMQ
  module Util
    
    # Helper method to create a hex string of a byte sequence.
    #
    def self.strhex(str)
      hex_chars = "0123456789ABCDEF"
      msg_size = str.size
  
      result = ""
      str.each_byte do |num|
        i1 = num >> 4
        i2 = num & 15
        result << hex_chars[i1..i1]
        result << hex_chars[i2..i2]
      end    
      result      
    end
    
  end
end