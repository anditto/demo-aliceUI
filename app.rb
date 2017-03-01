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

  def dumpassetlabels
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = {
      'method' => 'dumpassetlabels',
      'params' => [],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(http.request(request).body)
    res['result']
  end

  def addassetlabel(id,label)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = {
      'method' => 'addassetlabel',
      'params' => [id,label],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(http.request(request).body)
    res['result']
  end

  def getwalletinfo
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = {
      'method' => 'getwalletinfo',
      'params' => ['*'],
      'id' => 'jsonrpc'
    }.to_json
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
    res['result']
  end

  def listunspent(assetid)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = { 
      'method' => 'listunspent',
      'params' => [1,9999999,[],assetid],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(http.request(request).body)
    res['result']
  end

  def gettransaction(txid)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = { 
      'method' => 'gettransaction',
      'params' => [txid],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(http.request(request).body)
    res['result']
  end
end

set :public_folder, File.dirname(__FILE__) + '/public'

assetlabels = {}

get '/' do
  alice = BitcoinRPC.new('http://user:password@localhost:10000')
  fred  = BitcoinRPC.new('http://user:password@localhost:10040')

  # Get asset IDs & labels
  # I guess we get these somehow anyways
  assetlabels = fred.dumpassetlabels
  assetlabels.each do |label,id|
    alice.addassetlabel(id,label)
  end

  # Get current balance
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
    post_data += k.to_s + "=" + v.to_s + "&"
  end

  # Redirect on a success
  redirect '/confirm?' + post_data
  erb :pointrequest
end

# /transaction?response=reponse
get '/confirm' do
  ### Expecting to receive:
  # {"fee":15, "assetid":"ANA", "cost":400, "tx":"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}
  response = {"fee"=>15, "assetid"=>"ANA", "cost"=>400, "tx"=>"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}

  # Make sure contents are correct
  erb :confirm, locals:{
    cost:response['cost'].to_s,
    assetid:response['assetid'].to_s,
    fee:response['fee'].to_s,
    tx:response['tx'].to_s
  }
end

get '/process' do
  # TODO
  # Need to move this into the URL parameters
  requestexchange = {"request"=>{"suica"=>200}, "offer"=>"ANA"}
  # Need to do this more elegantly
  assetlabels = {
    "ANA" => "018440844f994e0a3d95dd5b01f79d81a312a603a8bfa8293cc33fef0f39cae5",
    "bitcoin" => "09f663de96be771f50cab5ded00256ffe63773e2eaa9a604092951cc3d7c6621",
    "suica" => "e01e93d251c364a2918990e565ef8b0dd0be4c73740858a4759f213067bc1064"
  }

  # Start
  tx = params['tx']
  alice = BitcoinRPC.new('http://user:password@localhost:10000')

  # Run listunspent
  list = alice.listunspent(params['assetid'])

  # Find appropriate inputs that suffice #TODO
  # For now we're assuming the first one will suffice
  vin_tx = alice.decoderawtransaction(alice.gettransaction(list[0]['txid'])['hex'])
  vin_tx_index = 0
  vin_amount = 0
  change = 0
  vin_tx['vout'].each do |vout|
    if vout['value'] != nil
      if ( (vout['assetid'] == assetlabels[params['assetid']]) && (vout['value'] >= (params['fee'].to_f+params['cost'].to_f)) )
        change = vout['value'] - (params['fee'].to_f+params['cost'].to_f)
        vin_amount = vout['value']
        break
      end
    end
    vin_tx_index += 1
  end

  # Add necessary Vin
  tx += " in=" + list[0]['txid'] + ":" + vin_tx_index.to_s + ":" + vin_amount.to_s

  # Run getnewaddress
  unblinded_points_addr = alice.getnewaddress[1]
  unblinded_change_addr = alice.getnewaddress[1]

  # Add necessary Vout
  # Suica Points for self
  tx += " outaddr=" + requestexchange['request']['suica'].to_s + ":" +
    unblinded_points_addr + ":" +
    assetlabels[requestexchange['request'].first[0]]

  # Change
  tx += " outaddr=" + change.to_s + ":" +
    unblinded_change_addr + ":" +
    assetlabels[params['assetid']]

  # Fee
  tx += " outscript=" + params['fee'].to_s + ':"":' + assetlabels[params['assetid']]

  p tx
  
  # Sign the transaction

  # Send to Charlie

  erb :process
end
