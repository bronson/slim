module Slim
  # Handle logic-less mode
  # This filter can be activated with the option "sections"
  # @api private
  class Sections < Filter
    # dictionary_access is not used if dictionary_type == :object
    set_default_options :dictionary => 'self',
                        :sections => false,
                        :dictionary_access => :symbol, # :symbol, :string, :method
                        :wrap_dictionary => true

    def initialize(opts = {})
      super

      unless [:method, :string, :symbol].include?(options[:dictionary_access])
        raise "Invalid dictionary access #{options[:dictionary_access].inspect}"
      end
    end

    def compile(exp)
      if options[:sections]
        # Store the dictionary in the _slimdict variable
        dictionary = options[:dictionary]
        dictionary = "Slim::Wrapper.new(#{dictionary})" if options[:wrap_dictionary]
        [:multi,
         [:block, "_slimdict = #{dictionary}"],
         super]
      else
        exp
      end
    end

    # Interpret control blocks as sections or inverted sections
    def on_slim_control(name, content)
      if name =~ /^!\s*(.*)/
        on_slim_inverted_section($1, content)
      else
        on_slim_section(name, content)
      end
    end

    def on_slim_inverted_section(name, content)
      tmp = tmp_var('section')
      [:multi,
       [:block, "#{tmp} = #{access name}"],
       [:block, "if !#{tmp} || #{tmp}.respond_to?(:empty) && #{tmp}.empty?"],
                  compile!(content),
       [:block, 'end']]
    end

    def on_slim_section(name, content)
      content = compile!(content)
      tmp1, tmp2 = tmp_var('dict'), tmp_var('dict')

      [:multi,
       [:block, "if #{tmp1} = #{access name}"],
       [:block,   "if #{tmp1} == true"],
                     content,
       [:block,   'else'],
                    # Wrap map in array because maps implement each
       [:block,     "#{tmp1} = [#{tmp1}] if #{tmp1}.respond_to?(:has_key?) || !#{tmp1}.respond_to?(:map)"],
       [:block,     "#{tmp2} = _slimdict"],
       [:block,     "#{tmp1}.each do |_slimdict|"],
                      content,
       [:block,     'end'],
       [:block,     "_slimdict = #{tmp2}"],
       [:block,   'end'],
       [:block, 'end']]
    end

    def on_slim_output(escape, name, content)
      raise 'Output statements with content are forbidden in sections mode' if !empty_exp?(content)
      [:slim, :output, escape, access(name), content]
    end

    private

    def access(name)
      return name if name == 'yield'
      case options[:dictionary_access]
      when :method
        "_slimdict.#{name}"
      when :string
        "_slimdict[#{name.to_s.inspect}]"
      else
        "_slimdict[#{name.to_sym.inspect}]"
      end
    end
  end
end
