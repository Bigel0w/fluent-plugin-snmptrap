module Fluent
# Read snmp trap messages as events in to fluentd
  class SnmpTrapInput < Input
    Fluent::Plugin.register_input('snmptrap', self)

    # Define default configurations
    config_param :tag, :string, :default => "alert.snmptrap"
    config_param :host, :string, :default => '0'
    config_param :port, :integer, :default => 1062
    config_param :community, :string, :default => "public"

    unless method_defined?(:router)
      define_method(:router) { Engine }
    end

    # Initialize and bring in dependencies
    def initialize
      super
      require 'snmp'
    end # def initialize

    # Load internal and external configs
    def configure(conf)
      super
      @conf = conf
    end # def configure

    # Start SNMP Trap listener
    def start
      super
      @m = SNMP::TrapListener.new(:Host => @host,:Port => @port) do |manager|
        manager.on_trap_default do |trap|
          tag = @tag 
          timestamp = Engine.now
          record = {"value"=> trap.inspect.to_json,"tags"=>{"type"=>"alert","host"=>trap.source_ip}}
          router.emit(tag, timestamp, record)
        end
      end
    end # def start

    # Stop Listener and cleanup any open connections.
    def shutdown
      @m.exit
    end # def shutdown
  end # class SnmpTrapInput
end # module Fluent
