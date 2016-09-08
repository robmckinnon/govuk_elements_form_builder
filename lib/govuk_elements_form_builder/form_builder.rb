module GovukElementsFormBuilder
  class FormBuilder < ActionView::Helpers::FormBuilder

    delegate :content_tag, :tag, :safe_join, to: :@template
    delegate :errors, to: :@object

    def initialize *args
      ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
        add_error_to_html_tag! html_tag
      end
      super
    end

    # Ensure fields_for yields a GovukElementsFormBuilder.
    def fields_for record_name, record_object = nil, fields_options = {}, &block
      super record_name, record_object, fields_options.merge(builder: self.class), &block
    end

    %i[
      email_field
      password_field
      number_field
      phone_field
      range_field
      search_field
      telephone_field
      text_area
      text_field
      url_field
    ].each do |method_name|
      define_method(method_name) do |attribute, *args|
        content_tag :div, class: form_group_classes(attribute), id: form_group_id(attribute) do
          options = args.extract_options!
          set_field_classes! options

          label = label(attribute, class: "form-label")
          add_hint :label, label, attribute
          (label + super(attribute, options.except(:label)) ).html_safe
        end
      end
    end

    def radio_button_fieldset attribute, options={}
      content_tag :div,
                  class: form_group_classes(attribute),
                  id: form_group_id(attribute) do
        content_tag :fieldset, fieldset_options(attribute, options) do
          safe_join([
                      fieldset_legend(attribute),
                      radio_inputs(attribute, options)
                    ], "\n")
        end
      end
    end

    def check_box_fieldset legend_key, attributes, options={}
      content_tag :div,
                  class: form_group_classes(attributes),
                  id: form_group_id(attributes) do
        content_tag :fieldset, fieldset_options(attributes, options) do
          safe_join([
                      fieldset_legend(legend_key),
                      check_box_inputs(attributes)
                    ], "\n")
        end
      end
    end

    def collection_select method, collection, value_method, text_method, options = {}, *args

      content_tag :div, class: form_group_classes(method), id: form_group_id(method) do

        html_options = args.extract_options!
        set_field_classes! html_options

        label = label(method, class: "form-label")
        add_hint :label, label, method

        (label+ super(method, collection, value_method, text_method, options , html_options)).html_safe
      end

    end

    private

    def set_field_classes! options
      text_field_class = "form-control"
      options[:class] = case options[:class]
                        when String
                          [text_field_class, options[:class]]
                        when Array
                          options[:class].unshift text_field_class
                        else
                          options[:class] = text_field_class
                        end
    end

    def check_box_inputs attributes
      attributes.map do |attribute|
        label(attribute, class: 'block-label') do |tag|
          input = check_box(attribute)
          input + localized_label("#{attribute}")
        end
      end
    end

    def radio_inputs attribute, options
      choices = options[:choices] || [ :yes, :no ]
      choices.map do |choice|
        label(attribute, class: 'block-label', value: choice) do |tag|
          input = radio_button(attribute, choice)
          input + localized_label("#{attribute}.#{choice}")
        end
      end
    end

    def fieldset_legend attribute
      legend = content_tag(:legend) do
        tags = [content_tag(
                  :span,
                  fieldset_text(attribute),
                  class: 'form-label-bold'
                )]

        if error_for? attribute
          tags << content_tag(
            :span,
            error_full_message_for(attribute),
            class: 'error-message'
          )
        end

        hint = hint_text attribute
        tags << content_tag(:span, hint, class: 'form-hint') if hint

        safe_join tags
      end
      add_hint :legend, legend, attribute
      legend.html_safe
    end

    def fieldset_options attributes, options
      fieldset_options = {}
      fieldset_options[:class] = 'inline' if options[:inline] == true
      fieldset_options
    end

    def add_error_to_html_tag! html_tag
      case html_tag
      when /^<label/
        add_error_to_label! html_tag
      when /^<input/
        add_error_to_input! html_tag, 'input'
      when /^<textarea/
        add_error_to_input! html_tag, 'textarea'
      # when /^<fieldset/
      #   add_error_to_input! html_tag
      else
        html_tag
      end
    end

    def attribute_prefix
      @object_name.to_s.tr('[]','_').squeeze('_').chomp('_')
    end

    def form_group_id attribute
      "error_#{attribute_prefix}_#{attribute}" if error_for? attribute
    end

    def add_error_to_label! html_tag
      field = html_tag[/for="([^"]+)"/, 1]
      object_attribute = object_attribute_for field
      message = error_full_message_for object_attribute
      if message
        html_tag.sub(
          '</label',
          %Q{<span class="error-message" id="error_message_#{field}">#{message}</span></label}
        ).html_safe # sub() returns a String, not a SafeBuffer
      else
        html_tag
      end
    end

    def add_error_to_input! html_tag, element
      field = html_tag[/id="([^"]+)"/, 1]
      html_tag.sub(
        element,
        %Q{#{element} aria-describedby="error_message_#{field}"}
      ).html_safe # sub() returns a String, not a SafeBuffer
    end

    def form_group_classes attributes
      attributes = [attributes] if !attributes.respond_to? :count
      classes = 'form-group'
      classes += ' error' if attributes.find { |a| error_for? a }
      classes
    end

    def error_full_message_for attribute
      message = errors.full_messages_for(attribute).first
      message&.sub default_label(attribute), localized_label(attribute)
    end

    def error_for? attribute
      errors.messages.key?(attribute) && !errors.messages[attribute].empty?
    end

    def object_attribute_for field
      field.to_s.
        sub("#{attribute_prefix}_", '').
        to_sym
    end

    def add_hint tag, element, name
      if hint = hint_text(name)
        hint_span = content_tag(:span, hint, class: 'form-hint')
        element.sub!("</#{tag}>", "#{hint_span}</#{tag}>".html_safe)
      end
    end

    def fieldset_text attribute
      localized 'helpers.fieldset', attribute, default_label(attribute)
    end

    def hint_text attribute
      localized 'helpers.hint', attribute, ''
    end

    def default_label attribute
      attribute.to_s.split('.').last.humanize.capitalize
    end

    def localized_label attribute
      localized 'helpers.label', attribute, default_label(attribute)
    end

    def localized scope, attribute, default
      key = "#{object_name}.#{attribute}"
      I18n.t(key,
        default: default,
        scope: scope).presence
    end
  end
end
