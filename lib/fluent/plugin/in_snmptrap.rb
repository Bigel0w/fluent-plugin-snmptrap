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
      config_param :ports, :array, default: [], value_type: :integer
      config_param :community, :string, default: 'public'
      config_param :emit_event_format, :string, default: 'jsonized'
      config_param :mib_dir, :string, default: nil
      config_param :mib_modules, :string, default: nil
      config_param :restart_wait, :float, default: 1.0

      def initialize
        super
        require 'snmp'
      end

      def configure(conf)
        super
        @conf = conf
        @ports = [@port] if @ports.empty?
        @mib_modules = @mib_modules.split(',').map { |str| str.strip } unless @mib_modules.nil?
        @snmp_init_params = {
          host: @host,
          mib_dir: @mib_dir,
          mib_modules: @mib_modules,
        }
        @record_generator = case @emit_event_format
                            when 'jsonized'
                              ->(trap) { { 'value' => trap.inspect.to_json } }
                            when 'record'
                              lambda do |trap|
                                case trap
                                when SNMP::SNMPv1_Trap
                                  {
                                    'source_ip' => trap.source_ip,
                                    'enterprise' => trap.enterprise,
                                    'oid' => trap.enterprise.to_str,
                                    'name' => trap.enterprise.to_s,
                                    'agent_addr' => trap.agent_addr.to_s,
                                    'specific_trap' => trap.specific_trap,
                                    'generic_trap' => trap.generic_trap.to_s,
                                    'varbind' => Hash[*trap.varbind_list.map do |vb|
                                      if SNMP::Integer === vb.value
                                        [vb.name.to_s, { 'value' => vb.value.to_i, 'asn1_type' => vb.value.asn1_type }]
                                      else
                                        [vb.name.to_s, { 'value' => vb.value.to_s, 'asn1_type' => vb.value.asn1_type }]
                                      end
                                    end.flatten],
                                    'timestamp' => trap.timestamp.to_s
                                  }
                                when SNMP::SNMPv2_Trap
                                  {
                                    'source_ip' => trap.source_ip,
                                    'sys_up_time' => trap.sys_up_time.to_s,
                                    'trap_oid' => trap.trap_oid,
                                    'oid' => trap.trap_oid.to_str,
                                    'name' => trap.trap_oid.to_s,
                                    'request_id' => trap.request_id,
                                    'error_status' => trap.error_status.to_s,
                                    'error_index' => trap.error_index,
                                    'varbind' => Hash[*trap.varbind_list.map do |vb|
                                      if SNMP::Integer === vb.value
                                        [vb.name.to_s, { 'value' => vb.value.to_i, 'asn1_type' => vb.value.asn1_type }]
                                      else
                                        [vb.name.to_s, { 'value' => vb.value.to_s, 'asn1_type' => vb.value.asn1_type }]
                                      end
                                    end.flatten]
                                  }
                                end
                              end
                            else
                              raise Fluent::ConfigError, "Unknown emit_event_format: '#{@emit_event_format}'"
                            end
      end

      def start
        super
        @stopped = false
        @listener_threads = @ports.map { |p| run_listener_thread(p) }
      end

      def shutdown
        super
        @stopped = true
        if @listener_threads
          @listener_threads.each(&:kill)
          @listener_threads.each(&:join)
        end
      end

      private

      def create_snmp_listener(port)
        params = @snmp_init_params.merge(port: port)
        SNMP::TrapListener.new(params) do |manager|
          manager.on_trap_default do |trap|
            tag = @tag
            timestamp = Engine.now
            if SNMP::SNMPv1_Trap === trap
              trap.enterprise.with_mib(manager.instance_variable_get(:@mib))
            end
            record = @record_generator.call(trap)
            record['tags'] = { 'type' => 'alert', 'host' => trap.source_ip }
            router.emit(tag, timestamp, record)
          end
        end
      end

      def run_listener_thread(port)
        Thread.new do
          until @stopped
            listener = nil
            begin
              listener = create_snmp_listener(port)
              listener.join
            rescue => e
              log.error "SNMP trap listener on port #{port} failed: #{e}"
            ensure
              listener&.exit
            end
            sleep @restart_wait unless @stopped
          end
        end
      end
    end
  end
end
