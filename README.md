# Fluent::Plugin::SnmpTrap, a plugin for [Fluentd](http://fluentd.org)

Fluentd snmp trap input plugin

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-snmptrap'

Or install it yourself as:

    $ gem install fluent-plugin-snmptrap

## Usage

    <source>
      type snmptrap
      port 162
      type snmptrap
      tag alert.snmptrap
    </source>
    
    <match alert.snmp*>
      type stdout
    </match>
