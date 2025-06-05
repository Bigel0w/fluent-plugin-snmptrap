require 'helper'

class SnmpTrapInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    host 0
    port 1062
    tag alert.snmptrap
    mib_modules SNMPv2-SMI, SNMPv2-MIB
  ]

  CONFIG_PORTS = %[
    host 0
    ports 1062, 1063
    tag alert.snmptrap
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::SnmpTrapInput).configure(conf)
  end

  def test_configure
    d = create_driver()
    assert_equal "0", d.instance.host
    assert_equal 1062, d.instance.port
    assert_equal 'alert.snmptrap', d.instance.tag
    assert_equal ['SNMPv2-SMI', 'SNMPv2-MIB'], d.instance.mib_modules
  end

  def test_ports_configure
    d = create_driver(CONFIG_PORTS)
    assert_equal [1062, 1063], d.instance.ports
  end

  def test_multiple_listeners_created
    trap_listener_backup = SNMP::TrapListener
    dummy = Class.new do
      @@instances = []
      attr_reader :params

      def initialize(params)
        @params = params
        @@instances << self
        yield self if block_given?
      end

      def self.instances
        @@instances
      end

      def on_trap_default(&block); end

      def join; end

      def exit; end
    end

    SNMP.send(:remove_const, :TrapListener)
    SNMP.const_set(:TrapListener, dummy)

    d = create_driver(CONFIG_PORTS)
    d.instance.start
    10.times do
      break if dummy.instances.size >= 2
      sleep 0.1
    end
    assert_equal 2, dummy.instances.size
    ports = dummy.instances.map { |i| i.params[:port] }.sort
    assert_equal [1062, 1063], ports
    d.instance.shutdown
  ensure
    SNMP.send(:remove_const, :TrapListener)
    SNMP.const_set(:TrapListener, trap_listener_backup)
  end

  def test_listener_restart_on_failure
    trap_listener_backup = SNMP::TrapListener
    dummy = Class.new do
      @@instances = []
      attr_reader :params

      def initialize(params)
        @params = params
        @@instances << self
        yield self if block_given?
      end

      def self.instances
        @@instances
      end

      def on_trap_default(&block); end

      def join
        raise 'boom'
      end

      def exit; end
    end

    SNMP.send(:remove_const, :TrapListener)
    SNMP.const_set(:TrapListener, dummy)

    d = create_driver(CONFIG + "\nrestart_wait 0.1")
    d.instance.start
    20.times do
      break if dummy.instances.size >= 2
      sleep 0.1
    end
    assert_operator dummy.instances.size, :>=, 2
    d.instance.shutdown
  ensure
    SNMP.send(:remove_const, :TrapListener)
    SNMP.const_set(:TrapListener, trap_listener_backup)
  end
end
