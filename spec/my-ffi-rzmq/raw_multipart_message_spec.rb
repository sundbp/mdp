require 'spec_helper'
require 'shared_examples'
require 'my-ffi-rzmq/raw_multipart_message'

describe ZMQ::RawMultipartMessage do
  
  it_behaves_like "ZMQ::MultipartMessage"
  
end

