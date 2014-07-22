require 'helper'

class SnmpTrapInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    host 0
    port 1062
    tag alert.snmptrap
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SnmpTrapInput).configure(conf)
  end

  def test_configure
    d = create_driver('')
    assert_equal "0".to_i, d.instance.host
    assert_equal "1062".to_i, d.instance.port
    assert_equal 'alert.snmptrap', d.instance.tag
  end
end