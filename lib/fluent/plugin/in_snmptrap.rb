require 'fluent/input'

module Fluent
# Read snmp trap messages as events in to fluentd
  class SnmpTrapInput < Input
    Fluent::Plugin.register_input('snmptrap', self)

    # Define default configurations
    config_param :tag, :string, :default => "alert.snmptrap"
    config_param :host, :string, :default => '0'
    config_param :port, :integer, :default => 1062
    config_param :community, :string, :default => "public"
    config_param :emit_event_format, :string, :default => 'jsonized'

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
      @record_generator = case @emit_event_format
                          when 'jsonized'
                            Proc.new { |trap|
                              {'value' => trap.inspect.to_json}
                            }
                          when 'record'
                            Proc.new { |trap|
                              {
                                'source_ip' => trap.source_ip,
                                'enterprise' => trap.enterprise,
                                'agent_addr' => trap.agent_addr.to_s,
                                'specific_trap' => trap.specific_trap,
                                'generic_trap' => trap.generic_trap.to_s,
                                'varbind_list' => trap.varbind_list,
                                'timestamp' => trap.timestamp.to_s
                              }
                            }
                          else
                            raise ConfigError, "Unknown emit_event_format: '#{@emit_event_format}'"
                          end
    end # def configure

    # Start SNMP Trap listener
    def start
      super
      @m = SNMP::TrapListener.new(:Host => @host,:Port => @port) do |manager|
        manager.on_trap_default do |trap|
          tag = @tag
          timestamp = Engine.now
          record = @record_generator.call(trap)
          record['tags'] = {'type' => 'alert' , 'host' => trap.source_ip}
          router.emit(tag, timestamp, record)
        end
      end
    end # def start

    # Stop Listener and cleanup any open connections.
    def shutdown
      super
      @m.exit
    end # def shutdown
  end # class SnmpTrapInput
end # module Fluent
