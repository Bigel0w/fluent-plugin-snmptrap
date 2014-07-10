# Fluent::Plugin::SnmpTrap

fluentd-plugin-snmptrap is an input plugin for [Fluentd](http://fluentd.org)

## Installation

These instructions assume you already have fluentd installed. 
If you don't, please run through [quick start for fluentd] (https://github.com/fluent/fluentd#quick-start)

Add this line to your application's Gemfile:

    gem 'fluent-plugin-snmptrap'

Or install it yourself as:

    $ gem install fluent-plugin-snmptrap

## Usage
Add the following into your fluentd config.

    <source>
      type snmptrap       # required, chossing the input plugin.
      host 127.0.0.1      # optional, interface to listen on, default 0 for all.
      port 162            # optional, port to listen for traps, default is 1062
      tag alert.snmptrap  # optional, tag to assign to events, default is alert.snmptrap 
    </source>
    
    <match alert.snmptrap>
      type stdout
    </match>    