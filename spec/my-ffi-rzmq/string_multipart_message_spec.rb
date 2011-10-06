require 'spec_helper'
require 'shared_examples'
require 'my-ffi-rzmq/string_multipart_message'

describe ZMQ::StringMultipartMessage do
  
  it_behaves_like "ZMQ::MultipartMessage"
  
end

