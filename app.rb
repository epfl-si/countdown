#
# (c) All rights reserved. ECOLE POLYTECHNIQUE FEDERALE DE LAUSANNE, Switzerland, VPSI, 2017
#
require 'yaml'
# ------------------------------------------------------------ Countdown App
class RedisCountdown
  def initialize
    # App configuration precedence: default -> config/app.yml -> ENV vars
    conf_dflt = {
      "redis"     => "redis://localhost:6379/15",
      "maxkeylen" => 32,
      "expire"    => 7200,
    }
    conf_env = {
      "redis"     => ENV['CDWN_REDIS'],
      "maxkeylen" => ENV['CDWN_MAXKEYLEN'],
      "expire"    => ENV['CDWN_EXPIRE'],
    }.delete_if { |k, v| v.nil? }
    cfp=File.expand_path(File.dirname(__FILE__))+"/config/app.yml"
    conf_file = File.exist?(cfp) ? YAML.load_file(cfp) : {}

    @config = conf_dflt.merge(conf_file).merge(conf_env)
    set_redis
  end

  def call(env)
    req = Rack::Request.new env
    unless validate_id_format(req)
      return @err
    end

    case req.path_info
    when /set/
      set(req)
    when /get/
      get(req)
    when /register/
      register(req)
    when /del/
      del(req)
    when /check/
      check(req)
    else
      [404, {"Content-Type" => "text/html"}, ["Not Found!"]]
    end
  end

  def set_redis
    url = @config["redis"]
    @redis = Redis.new(
      :connect_timeout => 0.2,
      :read_timeout    => 1.0,
      :write_timeout   => 0.5,
      url: url,
    )
    ping(true)
  end

  def ping(or_die=false)
    begin
      @redis.ping
    rescue Exception => e
      e.inspect
      e.message
      if ord_die
        raise "Redis does not respond"
      else
        set_redis
      end
    end
  end

  def validate_id_format(req)
    id = req.params["id"]
    if id.nil?
      @err = [400, {"Content-Type" => "text/html"}, ["Err: id not provided"]]
      return false
    end
    mxl=@config["maxkeylen"]
    unless id =~ /^[A-Za-z0-9_]{1,#{mxl}}$/
      @err = [400, {"Content-Type" => "text/html"}, ["Err: invalid Id format"]]
      return false
    end
    true
  end

  def set(req)
    id=req.params["id"]
    ns=req.params["count"]
    n=ns.to_i
    unless n > 0 and n < 1001
      return [400, {"Content-Type" => "text/html"}, ["Err: invalid count"]]
    end
    ping
    if @redis.get(id)
      @err = [400, {"Content-Type" => "text/html"}, ["Err: invalid Id: already taken"]]
      return @err
    end
    @redis.set(id, n)
    ns = @redis.get(id)
    unless ns.to_i == n
      return [500, {"Content-Type" => "text/html"}, ["Err: internal error"]]
    end
    [200, {"Content-Type" => "text/html"}, ["Ok"]]
  end

  def check(req)
    id=req.params["id"]
    n = @redis.get(id)
    if n.nil?
      return [404, {"Content-Type" => "text/html"}, ["Err: id not found"]]
    end
    [200, {"Content-Type" => "text/html"}, ["Ok"]]
  end

  def get(req)
    id=req.params["id"]
    n = @redis.get(id)
    if n.nil?
      return [404, {"Content-Type" => "text/html"}, ["Err: id not found"]]
    end
    [200, {"Content-Type" => "text/html"}, [n]]
  end

  def del(req)
    id=req.params["id"]
    n = @redis.get(id)
    if n.nil?
      return [404, {"Content-Type" => "text/html"}, ["Err: id not found"]]
    end
    @redis.del(id)
    [200, {"Content-Type" => "text/html"}, ["Ok: #{n}"]]
  end


  def register(req)
    id = req.params["id"]
    n = @redis.get(id)
    if n.nil?
      return [404, {"Content-Type" => "text/html"}, ["Err: id not found"]]
    end
    n = n.to_i
    if n > 0
      n = @redis.decr(id)
      if n == 0
        @redis.expire(id, @config["expire"])
      end
    end
    [200, {"Content-Type" => "text/html"}, ["Ok"]]
  end

end
