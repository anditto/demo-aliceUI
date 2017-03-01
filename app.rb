require 'sinatra'
require 'net/http'
require 'uri'
require 'json'

class BitcoinRPC
  def initialize(service_url)
    @uri = URI.parse(service_url)
  end

  def setup
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    [http,request]
  end

  def dumpassetlabels
    conn = setup
    conn[1].body = {
      'method' => 'dumpassetlabels',
      'params' => [],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def addassetlabel(id,label)
    conn = setup
    conn[1].body = {
      'method' => 'addassetlabel',
      'params' => [id,label],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def getwalletinfo
    conn = setup
    conn[1].body = {
      'method' => 'getwalletinfo',
      'params' => ['*'],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def getnewaddress
    conn = setup
    conn[1].body = { 'method' => 'getnewaddress', 'params' => [], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    blindedaddress = res['result']
    conn[1].body = { 'method' => 'validateaddress', 'params' => [blindedaddress], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    unblindedaddress = res['result']['unconfidential']
    [blindedaddress, unblindedaddress]
  end

  def decoderawtransaction(tx)
    conn = setup
    conn[1].body = { 'method' => 'decoderawtransaction', 'params' => [tx], 'id' => 'jsonrpc' }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def listunspent(assetid)
    conn = setup
    conn[1].body = { 
      'method' => 'listunspent',
      'params' => [1,9999999,[],assetid],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def gettransaction(txid)
    conn = setup
    conn[1].body = { 
      'method' => 'gettransaction',
      'params' => [txid],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def mutatetx(dataarray)
    conn = setup
    conn[1].body = { 
      'method' => 'mutatetx',
      'params' => dataarray,
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end

  def signrawtransaction(txdata)
    conn = setup
    conn[1].body = { 
      'method' => 'signrawtransaction',
      'params' => [txdata],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']['hex']
  end

  def sendtoaddress(address, amount, assetid)
    conn = setup
    conn[1].body = { 
      'method' => 'sendtoaddress',
      'params' => [address, amount, "", "", false, assetid],
      'id' => 'jsonrpc'
    }.to_json
    res = JSON.parse(conn[0].request(conn[1]).body)
    res['result']
  end
end

set :public_folder, File.dirname(__FILE__) + '/public'

assetlabels = {}

get '/' do
  alice = BitcoinRPC.new('http://user:pass@localhost:10000')
  #fred  = BitcoinRPC.new('http://user:pass@10.4.2.2:10040')

  # Get asset IDs & labels
  # Assume Alice knows all labels & ID. I guess we get these somehow anyways
  assetlabels = alice.dumpassetlabels

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
  requestexchange = {"request"=>{"suica"=>200}, "offer"=>"ANA"}
  shopaddress = params['shopaddress']
  #shopaddress = "2dZjSp7W7WVo7f1njRM24teQR4B6kQ8yH4j"

  #Sends request to Charlie
  url = URI.parse("http://10.4.2.2:8020/getexchangeoffer/")
  request = Net::HTTP::Post.new(url)
  request.content_type = "text/plain;"
  request.body = JSON.dump(requestexchange)

  req_options = {
    use_ssl: url.scheme == "https",
  }

  response = Net::HTTP.start(url.hostname, url.port, req_options) do |http|
    http.request(request)
  end
  parsed_response = JSON.parse(response.body)
  
  get_data = ""
  get_data += "request_assetid=" + requestexchange['request'].first[0] +
    "&request_amount=" + requestexchange['request'].first[1].to_s +
    "&offer=" + requestexchange['offer'] + "&shopaddress=" + shopaddress.to_s
  parsed_response.each do |k,v|
    get_data += "&" + k.to_s + "=" + v.to_s
  end

  erb :pointrequest

  # Redirect on a success
  redirect '/confirm?' + get_data

  # Dummy Data
  #txfragment = "0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"
  #response = {"fee"=>15, "assetid"=>"ANA", "cost"=>400, "tx"=>txfragment}
end

# /transaction?response=reponse
get '/confirm' do
  ### Expecting to receive:
  # {"fee":15, "assetid":"ANA", "cost":400, "tx":"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}
  #response = {"fee"=>15, "assetid"=>"ANA", "cost"=>400, "tx"=>"0100000001a0f9836b4ba55bccb6ebf9e199899d446e532008784cf439d24bd82cd1c182ab0100000000ffffffff02016410bc6730219f75a4580874734cbed00d8bef65e5908991a264c351d2931ee00100000002540be4001976a914d4391f69c20725f7811f44acc062107c2c94e74b88ac01e5ca390fef3fc33c29a8bfa803a612a3819df7015bdd953d0a4e994f844084010100000009502f90001976a914a1798cc6ee314d3daa4d530c3da7dd9bb5b10f4788ac00000000"}

  # TODO Make sure contents are correct
  erb :confirm, locals:{
    request_assetid:params['request_assetid'].to_s,
    request_amount:params['request_amount'].to_s,
    offer:params['offer'].to_s,
    fee:params['fee'].to_s,
    assetid:params['assetid'].to_s,
    cost:params['cost'].to_s,
    tx:params['tx'].to_s,
    shopaddress:params['shopaddress'].to_s
  }
end

get '/process' do
  # TODO Need to do this more elegantly
  if assetlabels.empty?
    assetlabels = alice.dumpassetlabels
  end

  # Start
  tx = [params['tx']]
  alice = BitcoinRPC.new('http://user:pass@localhost:10000')

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
  tx << "in=" + list[0]['txid'] + ":" + vin_tx_index.to_s + ":" + vin_amount.to_s

  # Run getnewaddress
  unblinded_change_addr = alice.getnewaddress[1]

  # Add necessary Vout
  # Suica Points for self
  tx << "outaddr=" + params['request_amount'].to_s + ":" +
    params['shopaddress'] + ":" +
    assetlabels[params['request_assetid']]

  # Change
  tx << "outaddr=" + change.to_s + ":" +
    unblinded_change_addr + ":" +
    assetlabels[params['assetid']]

  # Fee
  tx << "outscript=" + params['fee'].to_s + '::' + assetlabels[params['assetid']]

  # Construct the transaction
  full_tx = alice.mutatetx(tx)
  
  # Sign the transaction
  signed_tx = alice.signrawtransaction(full_tx)

  #Send to Charlie
  url = URI.parse("http://10.4.2.2:8020/submitexchange/")
  request = Net::HTTP::Post.new(url)
  request.content_type = "text/plain;"
  request.body = JSON.dump({
    "tx" => signed_tx
  })
  req_options = {
    use_ssl: url.scheme == "https",
  }

  response = Net::HTTP.start(url.hostname, url.port, req_options) do |http|
    http.request(request)
  end

  erb :process, locals:{
    signed_tx:signed_tx,
    response:response.body
  }
end

post '/sendtoaddress' do
  alice = BitcoinRPC.new('http://user:pass@localhost:10000')
  res = alice.sendtoaddress(params['address'], params['amount'], params['assetid'])
  redirect to('/sendtoaddress')
end

get '/sendtoaddress' do
  erb :sendtoaddress
end
