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
    config_param :mib_dir, :string, :default => nil
    config_param :mib_modules, :string, :default => nil

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
      @mib_modules = @mib_modules.split(',').map{|str| str.strip} unless @mib_modules.nil?
      @snmp_init_params = {
        :host            => @host,
        :port            => @port,
        :mib_dir         => @mib_dir,
        :mib_modules     => @mib_modules,
      }
      @record_generator = case @emit_event_format
                          when 'jsonized'
                            Proc.new { |trap|
                              {'value' => trap.inspect.to_json}
                            }
                          when 'record'
                            Proc.new { |trap|
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
                                  'varbind' => Hash[*trap.varbind_list.map { |vb|
                                    if SNMP::Integer === vb.value
                                      [vb.name.to_s, { 'value' => vb.value.to_i, 'asn1_type' => vb.value.asn1_type}]
                                    else
                                      [vb.name.to_s, { 'value' => vb.value.to_s, 'asn1_type' => vb.value.asn1_type}]
                                    end
                                  }.flatten],
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
                                  'varbind' => Hash[*trap.varbind_list.map { |vb|
                                    if SNMP::Integer === vb.value
                                      [vb.name.to_s, { 'value' => vb.value.to_i, 'asn1_type' => vb.value.asn1_type}]
                                    else
                                      [vb.name.to_s, { 'value' => vb.value.to_s, 'asn1_type' => vb.value.asn1_type}]
                                    end
                                  }.flatten]
                                }
                              end
                            }
                          else
                            raise ConfigError, "Unknown emit_event_format: '#{@emit_event_format}'"
                          end
    end # def configure

    # Start SNMP Trap listener
    def start
      super
      @m = SNMP::TrapListener.new(@snmp_init_params) do |manager|
        manager.on_trap_default do |trap|
          tag = @tag
          timestamp = Engine.now
          # trap.enterprise doesn't have MIB information
          if SNMP::SNMPv1_Trap === trap
            trap.enterprise.with_mib(manager.instance_variable_get(:@mib))
          end
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
