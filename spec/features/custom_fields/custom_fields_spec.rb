require 'spec_helper'
require 'support/pages/custom_fields'

describe 'custom fields', js: true do
  let(:user) { FactoryBot.create :admin }
  let(:cf_page) { Pages::CustomFields.new }

  before do
    login_as(user)
  end

  describe "creating a new list custom field" do
    before do
      cf_page.visit!

      click_on "Create a new custom field"
    end

    it "creates a new list custom field with its options in the right order" do
      cf_page.set_name "Operating System"

      select "List", from: "custom_field_field_format"
      expect(page).to have_text("Allow multi-select")

      expect(page).to have_selector('.custom-option-row', count: 1)
      within all(".custom-option-row").last do
        find(".custom-option-value input").set "Windows"
        find(".custom-option-default-value input").set true
      end

      click_on "add-custom-option"

      expect(page).to have_selector('.custom-option-row', count: 2)
      within all(".custom-option-row").last do
        find(".custom-option-value input").set "Linux"
      end

      click_on "add-custom-option"

      expect(page).to have_selector('.custom-option-row', count: 3)
      within all(".custom-option-row").last do
        find(".custom-option-value input").set "Solaris"

        click_on "Move to top"
      end

      click_on "Save"

      expect(page).to have_text("Successful creation")

      click_on "Operating System"

      expect(page).to have_selector('.custom-option-row', count: 3)
      values = all(".custom-option-value input")

      expect(values[0].value).to eql("Solaris")
      expect(values[1].value).to eql("Windows")
      expect(values[2].value).to eql("Linux")

      defaults = all(".custom-option-default-value input")

      expect(defaults[0]).not_to be_checked
      expect(defaults[1]).to be_checked
      expect(defaults[2]).not_to be_checked
    end
  end

  context "with an existing list custom field" do
    let!(:custom_field) do
      FactoryBot.create(
        :list_wp_custom_field,
        name: "Platform",
        possible_values: ["Playstation", "Xbox", "Nintendo", "PC"]
      )
    end

    before do
      with_enterprise_token(:multiselect_custom_fields)

      cf_page.visit!
      expect_angular_frontend_initialized

      click_on custom_field.name
      expect_angular_frontend_initialized
    end

    it "adds new options" do
      click_on "add-custom-option"

      expect(page).to have_selector('.custom-option-row', count: 5)
      within all(".custom-option-row").last do
        find(".custom-option-value input").set "Sega"
      end

      click_on "add-custom-option"

      expect(page).to have_selector('.custom-option-row', count: 6)
      within all(".custom-option-row").last do
        find(".custom-option-value input").set "Atari"
      end

      click_on "Save"

      expect(page).to have_text("Successful update")
      expect(page).to have_text("Platform")
      expect(page).to have_selector('.custom-option-row', count: 6)

      values = all(".custom-option-value input").map(&:value)

      expect(values).to eq ["Playstation", "Xbox", "Nintendo", "PC", "Sega", "Atari"]
    end

    it "updates the values and orders of the custom options" do
      expect(page).to have_text("Platform")

      expect(page).to have_selector('.custom-option-row', count: 4)
      expect(page).to have_field("custom_field_custom_options_attributes_0_value", with: "Playstation")
      expect(page).to have_field("custom_field_custom_options_attributes_1_value", with: "Xbox")
      expect(page).to have_field("custom_field_custom_options_attributes_2_value", with: "Nintendo")
      expect(page).to have_field("custom_field_custom_options_attributes_3_value", with: "PC")

      fill_in("custom_field_custom_options_attributes_1_value", with: "Sega")
      check("custom_field_multi_value")
      check("custom_field_custom_options_attributes_0_default_value")
      check("custom_field_custom_options_attributes_2_default_value")
      within all(".custom-option-row").first do
        click_on "Move to bottom"
      end
      click_on "Save"

      expect(page).to have_text("Successful update")
      expect(page).to have_text("Platform")
      expect(page).to have_field("custom_field_multi_value", checked: true)

      expect(page).to have_field("custom_field_custom_options_attributes_0_value", with: "Sega")
      expect(page).to have_field("custom_field_custom_options_attributes_1_value", with: "Nintendo")
      expect(page).to have_field("custom_field_custom_options_attributes_2_value", with: "PC")
      expect(page).to have_field("custom_field_custom_options_attributes_3_value", with: "Playstation")

      expect(page).to have_field("custom_field_custom_options_attributes_0_default_value", checked: false)
      expect(page).to have_field("custom_field_custom_options_attributes_1_default_value", checked: true)
      expect(page).to have_field("custom_field_custom_options_attributes_2_default_value", checked: false)
      expect(page).to have_field("custom_field_custom_options_attributes_3_default_value", checked: true)
    end

    context "with work packages using the options" do
      before do
        FactoryBot.create_list(
          :work_package_custom_value,
          3,
          custom_field: custom_field,
          value: custom_field.custom_options[1].id
        )
      end

      it "deletes a custom option and all values using it" do
        within all(".custom-option-row")[1] do
          find('.icon-delete').click

          cf_page.accept_alert_dialog!
        end

        expect(page).to have_text("Option 'Xbox' and its 3 occurrences were deleted.")

        rows = all(".custom-option-value input")

        expect(rows.size).to eql(3)

        expect(rows[0].value).to eql("Playstation")
        expect(rows[1].value).to eql("Nintendo")
        expect(rows[2].value).to eql("PC")
      end
    end
  end
end
