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
end
