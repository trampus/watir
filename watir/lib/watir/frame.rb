module Watir
  class Frame
    include Container
    include PageContainer
    
    # Find the frame denoted by how and what in the container and return its ole_object
    def locate
      how = @how
      what = @what
      frames = @container.document.frames
      target = nil
      
      for i in 0..(frames.length - 1)
        this_frame = frames.item(i)
        case how
        when :index
          index = i + 1
          return @o = this_frame if index == what
        when :name
          begin
            return @o = this_frame if what.matches(this_frame.name)
          rescue # access denied?
          end
        when :id, :src, :title
          # We assume that pages contain frames or iframes, but not both.
          return if tag_match? this_frame, i, what, "FRAME", how
          return if tag_match? this_frame, i, what, "IFRAME", how
        else
          raise ArgumentError, "Argument #{how} not supported"
        end
      end
      
      raise UnknownFrameException, "Unable to locate a frame with #{how} #{what}"
    end

    # Returns whether the attribute of the tag for the indexed frame matches the what.
    # If so, also sets @o and @tag.
    def tag_match? frame, index, what, tag_name, attribute
      tag = @container.document.getElementsByTagName(tag_name).item(index)
      return false if tag.nil?
      if what.matches(tag.invoke(attribute.to_s))
        @o = frame
        @tag = tag
        true
      else
        false
      end
    end
    private :tag_match?
    
    def initialize(container, how, what)
      set_container container
      @how = how
      @what = what
      locate
      copy_test_config container
    end
    
    def document
      @o.document
    end

    def attach_command
      @container.page_container.attach_command + ".frame(#{@how.inspect}, #{@what.inspect})"
    end
    
    def src
      @tag.src
    end
  end
end