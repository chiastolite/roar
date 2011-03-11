module Roar
  module Representer
    class Roxml < Base
      include ROXML
      
      def serialize(represented, mime_type)
        to_xml(represented).serialize
      end
      
      def to_xml(represented)
        attributes = represented.attributes # DISCUSS: dependency to model#attributes.
        
        self.class.roxml_attrs.each { |attr|
          value = attributes[attr.name]
          
          public_send("#{attr.name}=", value)
        }
        
        super(:name => represented.class.model_name)
      end
        
      
      class << self
        def deserialize(represented_class, mime_type, data, *args)    # FIXME: too many params.
          xml = ROXML::XML::Node.from(data)
          
          config = roxml_attrs.collect { |attr| attr.to_ref(nil, self) }  # FIXME: see Definition#initialize
          
          represented = represented_class.new(*args)
          
          
          config.each do |ref|
            value = ref.value_in(xml)
            
            represented.send(ref.opts.setter, value)
          end
          
          represented
        end
        
        def has_one(attr_name, options={})
          if klass = options.delete(:class)
            options[:as] = klass.representer_class_for(mime_type) or raise "No representer found for #{mime_type}"
          end
          
          xml_accessor attr_name, options
        end     
      end
      
    end
  end
end
