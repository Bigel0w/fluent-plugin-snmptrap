module Fluent
  class SnmpTrapInput < Input
    Plugin.register_input('snmptrap', self)

    def initialize
      super
      require 'snmp'
    end

    config_param :tag, :string, :default => "alert.snmptrap"
    config_param :host, :integer, :default => 0
    config_param :port, :integer, :default => 1062
    config_param :community, :string, :default => "public"

    def configure(conf)
      super
    end

    def start
      super
      m = SNMP::TrapListener.new(:Host => @host,:Port => @port) do |manager|
        manager.on_trap_default do |trap|
          tag = @tag 
          timestamp = Engine.now
          record = {"value"=> trap.inspect.to_json,"tags"=>{"type"=>"alert","host"=>trap.source_ip}}
          Engine.emit(tag, timestamp, record)
        end
      end
      trap("INT") { m.exit }
      m.join
    end

    def shutdown
      m.exit
    end
  end
end
