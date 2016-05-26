#
# Fluentd
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

require 'fluent/output'
require 'fluent/config/error'
require 'fluent/event'

module Fluent
  class CopyOutput < MultiOutput
    Plugin.register_output('copy', self)

    desc 'If true, pass different record to each `store` plugin.'
    config_param :deep_copy, :bool, default: false

    def initialize
      super
      @outputs = []
    end

    attr_reader :outputs

    def configure(conf)
      super
      conf.elements.select {|e|
        e.name == 'store'
      }.each {|e|
        type = e['@type']
        unless type
          raise ConfigError, "Missing 'type' parameter on <store> directive"
        end
        log.debug "adding store type=#{type.dump}"

        output = Plugin.new_output(type)
        output.router = router
        output.configure(e)
        @outputs << output
      }
    end

    def start
      super

      @outputs.each do |o|
        o.start unless o.started?
      end
    end

    def shutdown
      @outputs.each do |o|
        o.shutdown unless o.shutdown?
      end

      super
    end

    def emit(tag, es, chain)
      unless es.repeatable?
        m = MultiEventStream.new
        es.each {|time,record|
          m.add(time, record)
        }
        es = m
      end
      if @deep_copy
        chain = CopyOutputChain.new(@outputs, tag, es, chain)
      else
        chain = OutputChain.new(@outputs, tag, es, chain)
      end
      chain.next
    end
  end
end
