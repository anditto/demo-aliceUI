require 'sinatra'
require 'net/http'
require 'uri'
require 'json'
#require 'eventmachine'
#require 'em-http'
#require 'fiber'

#def async_fetch(url)
#  f = Fiber.current
#  http = EventMachine::HttpRequest.new(url).
#end

class BitcoinRPC
  def initialize(service_url)
    @uri = URI.parse(service_url)
  end

  def getwalletinfo
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = { 'method' => 'getwalletinfo', 'params' => ['*'], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(http.request(request).body)
    res['result']
  end

  def getnewaddress
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = { 'method' => 'getnewaddress', 'params' => [], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(http.request(request).body)
    blindedaddress = res['result']
    request.body = { 'method' => 'validateaddress', 'params' => [blindedaddress], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(http.request(request).body)
    unblindedaddress = res['result']['unconfidential']
    [blindedaddress, unblindedaddress]
  end

  def decoderawtransaction(tx)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = { 'method' => 'decoderawtransaction', 'params' => [tx], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(http.request(request).body)
    blindedaddress = res['result']
  end
end

set :public_folder, File.dirname(__FILE__) + '/public'

get '/' do
  alice = BitcoinRPC.new('http://user:password@localhost:10000')
  balance = alice.getwalletinfo
  newaddress = alice.getnewaddress

  # Filtering wallet balance
  wallet = []
  balance['balance'].each do |k, v|
    if k == "bitcoin"
      wallet << ["bitcoinSymbol.png",v]
    elsif k == "ANA"
      wallet << ["ANASymbol.png",v]
    elsif k == "suica"
      wallet << ["suicaSymbol.png",v]
    else
      wallet << ["unknownSymbol.png",v]
    end
  end

  erb :app, locals:{ 
    wallet:wallet,
    blindedaddress:newaddress[0],
    unblindedaddress:newaddress[1]
  }
end

get '/pointrequest' do
  ### Expecting to send:
  # {"request": {"suica":200}, "offer":"ANA"}
  #
  ### Expecting to receive:
  # {"fee":15, "assetid":"ANA", "cost":400, "tx":"0000132...."}

  # Dummy data
  requestexchange = {"request": {"suica":200}, "offer":"ANA"}
  response = {"fee":15, "assetid":"ANA", "cost":400, "tx":"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}
  post_data = ""
  response.each do |k,v|
    post_data = post_data + k.to_s + "=" + v.to_s + "&"
  end

  # Redirect on a success
  redirect '/confirm?' + post_data
  erb :pointrequest
end

# /transaction?response=reponse
get '/confirm' do
  ### Expecting to receive:
  # {"fee":15, "assetid":"ANA", "cost":400, "tx":"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}

  alice = BitcoinRPC.new('http://user:password@localhost:10000')
  receivedtxfragment = alice.decoderawtransaction(params['tx'])
  response = {"fee":15, "assetid":"ANA", "cost":400, "tx":"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}


  # Make sure contents are correct
  erb :confirm, locals:{
    cost:response["cost"],
    assetid:response['assetid'],
    tx:receivedtxfragment["txid"],
    fee:response['fee']
  }
end
