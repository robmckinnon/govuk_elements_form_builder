# coding: utf-8
require 'rails_helper'
require 'spec_helper'

class TestHelper < ActionView::Base; end

RSpec.describe GovukElementsFormBuilder::FormBuilder do
  include TranslationHelper

  it "should have a version" do
    expect(GovukElementsFormBuilder::VERSION).to eq("0.0.1")
  end

  let(:helper) { TestHelper.new }
  let(:resource)  { Person.new }
  let(:builder) { described_class.new :person, resource, helper, {} }

  def expect_equal output, expected
    split_output = output.gsub(">\n</textarea>", ' />').split("<").join("\n<").split(">").join(">\n").squeeze("\n").strip + '>'
    split_expected = expected.join("\n")
    expect(split_output).to eq split_expected
  end

  shared_examples_for 'input field' do |method, type|

    def element_for(method)
      method == :text_area ? 'textarea' : 'input'
    end

    def type_for(method, type)
      method == :text_area ? '' : %'type="#{type}" '
    end

    def size(method, size)
      method == :text_area ? '' : %'size="#{size}" '
    end

    it 'outputs label and input wrapped in div' do
      output = builder.send method, :name

      expect_equal output, [
        '<div class="form-group">',
        '<label class="form-label" for="person_name">',
        'Full name',
        '</label>',
        %'<#{element_for(method)} class="form-control" #{type_for(method, type)}name="person[name]" id="person_name" />',
        '</div>'
      ]
    end

    it 'adds custom class to input when passed class: "custom-class"' do
      output = builder.send method, :name, class: 'custom-class'

      expect_equal output, [
        '<div class="form-group">',
        '<label class="form-label" for="person_name">',
        'Full name',
        '</label>',
        %'<#{element_for(method)} class="form-control custom-class" #{type_for(method, type)}name="person[name]" id="person_name" />',
        '</div>'
      ]
    end

    it 'adds custom classes to input when passed class: ["custom-class", "another-class"]' do
      output = builder.send method, :name, class: ['custom-class', 'another-class']

      expect_equal output, [
        '<div class="form-group">',
        '<label class="form-label" for="person_name">',
        'Full name',
        '</label>',
        %'<#{element_for(method)} class="form-control custom-class another-class" #{type_for(method, type)}name="person[name]" id="person_name" />',
        '</div>'
      ]
    end

    it 'passes options passed to text_field onto super text_field implementation' do
      output = builder.send method, :name, size: 100
      expect_equal output, [
        '<div class="form-group">',
        '<label class="form-label" for="person_name">',
        'Full name',
        '</label>',
        %'<#{element_for(method)} #{size(method, 100)}class="form-control" #{type_for(method, type)}name="person[name]" id="person_name" />',
        '</div>'
      ]
    end

    context 'when hint text provided' do
      it 'outputs hint text in span inside label' do
        output = builder.send method, :ni_number
        expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_ni_number">',
          'National Insurance number',
          '<span class="form-hint">',
          'It’ll be on your last payslip. For example, JH 21 90 0A.',
          '</span>',
          '</label>',
          %'<#{element_for(method)} class="form-control" #{type_for(method, type)}name="person[ni_number]" id="person_ni_number" />',
          '</div>'
        ]
      end
    end

    context 'when fields_for used' do
      it 'outputs label and input with correct ids' do
        output = builder.fields_for(:address, Address.new) do |f|
          f.send method, :postcode
        end
        expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_address_attributes_postcode">',
          'Postcode',
          '</label>',
          %'<#{element_for(method)} class="form-control" #{type_for(method, type)}name="person[address_attributes][postcode]" id="person_address_attributes_postcode" />',
          '</div>'
        ]
      end
    end

    context 'when validation error on object' do
      it 'outputs error message in span inside label' do
        resource.valid?
        output = builder.send method, :name
        expected = expected_error_html method, type, 'person_name',
          'person[name]', 'Full name', 'Full name is required'
        expect_equal output, expected
      end

      it 'outputs custom error message format in span inside label' do
        translations = YAML.load(%'
            errors:
              format: "%{message}"
            activemodel:
              errors:
                models:
                  person:
                    attributes:
                      name:
                        blank: "Enter your full name"
        ')
        with_translations(:en, translations) do
          resource.valid?
          output = builder.send method, :name
          expected = expected_error_html method, type, 'person_name',
            'person[name]', 'Name', 'Enter your full name'
          expect_equal output, expected
        end
      end
    end

    context 'when validation error on child object' do
      it 'outputs error message in span inside label' do
        resource.address = Address.new
        resource.address.valid?

        output = builder.fields_for(:address) do |f|
          f.send method, :postcode
        end

        expected = expected_error_html method, type, 'person_address_attributes_postcode',
          'person[address_attributes][postcode]', 'Postcode', 'Postcode is required'
        expect_equal output, expected
      end
    end

    context 'when validation error on twice nested child object' do
      it 'outputs error message in span inside label' do
        resource.address = Address.new
        resource.address.country = Country.new
        resource.address.country.valid?

        output = builder.fields_for(:address) do |address|
          address.fields_for(:country) do |country|
            country.send method, :name
          end
        end

        expected = expected_error_html method, type, 'person_address_attributes_country_attributes_name',
          'person[address_attributes][country_attributes][name]', 'Country', 'Country is required'
        expect_equal output, expected
      end
    end

  end

  def expected_error_html method, type, attribute, name_value, label, error
    [
      %'<div class="form-group error" id="error_#{attribute}">',
      %'<label class="form-label" for="#{attribute}">',
      label,
      %'<span class="error-message" id="error_message_#{attribute}">',
      error,
      '</span>',
      '</label>',
      %'<#{element_for(method)} aria-describedby="error_message_#{attribute}" class="form-control" #{type_for(method, type)}name="#{name_value}" id="#{attribute}" />',
      '</div>'
    ]
  end

  describe '#text_field' do
    include_examples 'input field', :text_field, :text
  end

  describe '#text_area' do
    include_examples 'input field', :text_area, nil
  end

  describe '#email_field' do
    include_examples 'input field', :email_field, :email
  end

  describe "#number_field" do
    include_examples 'input field', :number_field, :number
  end

  describe '#password_field' do
    include_examples 'input field', :password_field, :password
  end

  describe '#phone_field' do
    include_examples 'input field', :phone_field, :tel
  end

  describe '#range_field' do
    include_examples 'input field', :range_field, :range
  end

  describe '#search_field' do
    include_examples 'input field', :search_field, :search
  end

  describe '#telephone_field' do
    include_examples 'input field', :telephone_field, :tel
  end

  describe '#url_field' do
    include_examples 'input field', :url_field, :url
  end

  describe '#radio_button_fieldset' do
    let(:pretty_output) { HtmlBeautifier.beautify output }
    let(:output) do
      builder.radio_button_fieldset :location,
                                    choices: [
                                      :ni,
                                      :isle_of_man_channel_islands,
                                      :british_abroad
                                    ]
    end

    it 'adds a legend' do
      expect(pretty_output).to have_tag('div.form-group > fieldset') do |div|
        expect(div).to have_tag('legend') do |legend|
          with_text I18n.t 'helpers.fieldset.person.location'
          expect(legend).to have_tag('span.form-hint') do
            with_text I18n.t 'helpers.hint.person.location'
          end
        end
      end
    end

    it 'outputs radio buttons wrapped in labels' do
      expect(pretty_output).to have_tag('div.form-group > fieldset') do |div|
        expect(div).to have_tag('label[for=person_location_ni].block-label') do |label|
          with_text I18n.t 'helpers.label.person.location.ni'
          expect(label).to have_tag('input', with: {
                                      type: 'radio',
                                      name: 'person[location]',
                                      value: 'ni'
                                    })
        end
        expect(div).to have_tag 'label.block-label', with: {
                   for: 'person_location_isle_of_man_channel_islands'
                 } do |label|
          with_text I18n.t 'helpers.label.person.location.isle_of_man_channel_islands'
          expect(label).to have_tag 'input', with: {
                     id: 'person_location_isle_of_man_channel_islands',
                     type: 'radio',
                     name: 'person[location]',
                     value: 'isle_of_man_channel_islands'
                   }
        end
        expect(div).to have_tag 'label.block-label', with: {
                   for: 'person_location_british_abroad'
                 } do |label|
          with_text I18n.t 'helpers.label.person.location.british_abroad'
          expect(label).to have_tag 'input', with: {
                     id: 'person_location_british_abroad',
                     type: 'radio',
                     name: 'person[location]',
                     value: 'british_abroad'
                   }
        end
      end
      # expect_equal output, [
      #   '<fieldset>',
      #   '<legend class="heading-medium">',
      #   'Where do you live?',
      #   '<span class="form-hint">',
      #   'Select from these options because you answered you do not reside in England, Wales, or Scotland',
      #   '</span>',
      #   '</legend>',
      #   '<label class="block-label" for="person_location_ni">',
      #   '<input type="radio" value="ni" name="person[location]" id="person_location_ni" />',
      #   'Northern Ireland',
      #   '</label>',
      #   '<label class="block-label" for="person_location_isle_of_man_channel_islands">',
      #   '<input type="radio" value="isle_of_man_channel_islands" name="person[location]" id="person_location_isle_of_man_channel_islands" />',
      #   'Isle of Man or Channel Islands',
      #   '</label>',
      #   '<label class="block-label" for="person_location_british_abroad">',
      #   '<input type="radio" value="british_abroad" name="person[location]" id="person_location_british_abroad" />',
      #   'I am a British citizen living abroad',
      #   '</label>',
      #   '</fieldset>'
      # ]
    end

    context 'no choices passed in' do
      let(:output) { builder.radio_button_fieldset :has_user_account }

      it 'outputs yes/no choices' do
        expect(output).to have_tag('div.form-group > fieldset') do |div|
          expect(div).to have_tag('label.block-label', with: {
                                    for: 'person_has_user_account_yes'
                                  }) do |label|
            expect(label).to have_tag('input', with: {
                                        id: 'person_has_user_account_yes',
                                        name: 'person[has_user_account]',
                                        value: 'yes'
                                      })
          end
        end
      end
    end

    context 'inline radio buttons' do
      let(:output) do
        builder.radio_button_fieldset :has_user_account, inline: true
      end

      it 'displays options inline' do
        expect(output).to have_tag('div.form-group > fieldset.inline')
      end
    end
      # expect_equal output, [
      #   '<fieldset class="inline">',
      #   '<legend class="heading-medium">',
      #   'Do you already have a personal user account?',
      #   '</legend>',
      #   '<label class="block-label" for="person_has_user_account_yes">',
      #   '<input type="radio" value="yes" name="person[has_user_account]" id="person_has_user_account_yes" />',
      #   'Yes',
      #   '</label>',
      #   '<label class="block-label" for="person_has_user_account_no">',
      #   '<input type="radio" value="no" name="person[has_user_account]" id="person_has_user_account_no" />',
      #   'No',
      #   '</label>',
      #   '</fieldset>'
      # ]

    context 'the resource is invalid' do
      let(:resource) { Person.new.tap { |p| p.valid? } }
      let(:output) { builder.radio_button_fieldset :gender }

      it 'outputs error messages' do
        expect(pretty_output).to have_tag('div.form-group.error > fieldset') do |div|
          expect(div).to have_tag('legend') do |legend|
            expect(legend).to have_tag('span.form-label-bold', 'Gender')
            expect(legend).to have_tag('span.error-message', 'Gender is required')
          end
        end
      end
      #   expect_equal output, [
      #                  '<div class="form-group error">',
      #                  '<fieldset>',
      #                  '<legend class="heading-medium">',
      #                  '<span class="form-label-bold">',
      #                  'Which email address should we use??',
      #                  '</span>',
      #                  '<span class="error-message">',
      #                  'Please select an option.',
      #                  '</span>',
      #                  '</legend>',
      #                  '<label class="block-label" for="person_has_user_account_no">',
      #                  '<input type="radio" value="no" name="person[has_user_account]" id="person_has_user_account_no" />',
      #                  'No',
      #                  '</label>',
      #                  '</fieldset>',
      #                  '</div>'
      #                ]
      # end
    end
  end

  describe '#check_box_fieldset' do
    it 'outputs checkboxes wrapped in labels' do
      resource.waste_transport = WasteTransport.new
      output = builder.fields_for(:waste_transport) do |f|
        f.check_box_fieldset :waste_transport, [:animal_carcasses, :mines_quarries, :farm_agricultural]
      end

      expect(output).to have_tag('div.form-group > fieldset') do
      end

      # expect_equal output, [
      #   '<fieldset>',
      #   '<legend class="heading-medium">',
      #   'Which types of waste do you transport regularly?',
      #   '<span class="form-hint">',
      #   'Select all that apply',
      #   '</span>',
      #   '</legend>',
      #   '<label class="block-label" for="person_waste_transport_attributes_animal_carcasses">',
      #   '<input name="person[waste_transport_attributes][animal_carcasses]" type="hidden" value="0" />',
      #   '<input type="checkbox" value="1" name="person[waste_transport_attributes][animal_carcasses]" id="person_waste_transport_attributes_animal_carcasses" />',
      #   'Waste from animal carcasses',
      #   '</label>',
      #   '<label class="block-label" for="person_waste_transport_attributes_mines_quarries">',
      #   '<input name="person[waste_transport_attributes][mines_quarries]" type="hidden" value="0" />',
      #   '<input type="checkbox" value="1" name="person[waste_transport_attributes][mines_quarries]" id="person_waste_transport_attributes_mines_quarries" />',
      #   'Waste from mines or quarries',
      #   '</label>',
      #   '<label class="block-label" for="person_waste_transport_attributes_farm_agricultural">',
      #   '<input name="person[waste_transport_attributes][farm_agricultural]" type="hidden" value="0" />',
      #   '<input type="checkbox" value="1" name="person[waste_transport_attributes][farm_agricultural]" id="person_waste_transport_attributes_farm_agricultural" />',
      #   'Farm or agricultural waste',
      #   '</label>',
      #   '</fieldset>'
      # ]
    end

  end

  describe '#collection_select' do

    it 'outputs label and input wrapped in div ' do
      @gender = [:male, :female]
      output = builder.collection_select :gender, @gender , :to_s, :to_s
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_gender">',
          'Gender',

          '</label>',
          %'<select class="form-control" name="person[gender]" id="person_gender">',
          %'<option value="male">',
          'male',
          %'</option>',
          %'<option value="female">',
          'female',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end

    it 'outputs select lists with labels and hints' do
      @location = [:ni, :isle_of_man_channel_islands]
      output = builder.collection_select :location, @location , :to_s, :to_s, {}
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_location">',
          '{:ni=&gt;&quot;Northern Ireland&quot;, :isle_of_man_channel_islands=&gt;&quot;Isle of Man or Channel Islands&quot;, :british_abroad=&gt;&quot;I am a British citizen living abroad&quot;}',
          %'<span class="form-hint">',
          'Select from these options because you answered you do not reside in England, Wales, or Scotland',
          %'</span>',
          '</label>',
          %'<select class="form-control" name="person[location]" id="person_location">',
          %'<option value="ni">',
          'ni',
          %'</option>',%'<option value="isle_of_man_channel_islands">',
          'isle_of_man_channel_islands',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end

    it 'adds custom class to input when passed class: "custom-class"' do
      @gender = [:male, :female]
      output = builder.collection_select :gender, @gender , :to_s, :to_s, {}, class: "my-custom-style"
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_gender">',
          'Gender',
          '</label>',
          %'<select class="form-control my-custom-style" name="person[gender]" id="person_gender">',
          %'<option value="male">',
          'male',
          %'</option>',
          %'<option value="female">',
          'female',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end
    it 'includes blanks' do
      @gender = [:male, :female]
      output = builder.collection_select :gender, @gender , :to_s, :to_s, {include_blank: "Please select an option"}, {class: "my-custom-style"}
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_gender">',
          'Gender',
          '</label>',
          %'<select class="form-control my-custom-style" name="person[gender]" id="person_gender">',
          %'<option value="">',
          'Please select an option',
          %'</option>',
          %'<option value="male">',
          'male',
          %'</option>',
          %'<option value="female">',
          'female',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end
  end
end
