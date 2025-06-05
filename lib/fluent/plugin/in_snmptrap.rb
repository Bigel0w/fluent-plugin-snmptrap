require 'fluent/plugin/input'
require 'json'

module Fluent
  module Plugin
    class SnmpTrapInput < Input
      Fluent::Plugin.register_input('snmptrap', self)

      helpers :event_emitter

      config_param :tag, :string, default: 'alert.snmptrap'
      config_param :host, :string, default: '0'
      config_param :port, :integer, default: 1062
      config_param :community, :string, default: 'public'
      config_param :emit_event_format, :string, default: 'jsonized'

      def initialize
        super
        require 'snmp'
      end

      def configure(conf)
        super
        @record_generator = case @emit_event_format
                            when 'jsonized'
                              ->(trap) { { 'value' => trap.inspect.to_json } }
                            when 'record'
                              lambda do |trap|
                                {
                                  'source_ip' => trap.source_ip,
                                  'enterprise' => trap.enterprise,
                                  'agent_addr' => trap.agent_addr.to_s,
                                  'specific_trap' => trap.specific_trap,
                                  'generic_trap' => trap.generic_trap.to_s,
                                  'varbind_list' => trap.varbind_list,
                                  'timestamp' => trap.timestamp.to_s
                                }
                              end
                            else
                              raise Fluent::ConfigError, "Unknown emit_event_format: '#{@emit_event_format}'"
                            end
      end

      def start
        super
        @listener = SNMP::TrapListener.new(host: @host, port: @port) do |manager|
          manager.on_trap_default do |trap|
            time = Fluent::EventTime.now
            record = @record_generator.call(trap)
            record['tags'] = { 'type' => 'alert', 'host' => trap.source_ip }
            router.emit(@tag, time, record)
          end
        end
      end

      def shutdown
        super
        @listener.exit if @listener
      end
    end
  end
end
