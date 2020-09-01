#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe 'Projects index page',
         type: :feature,
         with_ee: %i[custom_fields_in_projects_list],
         js: true,
         with_settings: { login_required?: false } do
  using_shared_fixtures :admin

  let!(:string_cf) { FactoryBot.create(:string_project_custom_field, name: 'Foobar') }

  let(:cv_a) { FactoryBot.build :custom_value, custom_field: string_cf, value: 'A' }
  let(:cv_b) { FactoryBot.build :custom_value, custom_field: string_cf, value: 'B' }

  let!(:project_a) { FactoryBot.create :project, name: 'A', types: [type_milestone], custom_values: [cv_a] }
  let!(:project_b) { FactoryBot.create :project, name: 'B', types: [type_milestone], custom_values: [cv_b] }

  let!(:type_milestone) { FactoryBot.create :type, name: 'Milestone', is_milestone: true }

  let!(:work_package_a) { FactoryBot.create :work_package, subject: 'WP A', type: type_milestone, project: project_a }
  let!(:work_package_b) { FactoryBot.create :work_package, subject: 'WP B', type: type_milestone, project: project_b }

  let(:modal) { ::Components::WorkPackages::TableConfigurationModal.new }
  let(:model_filters) { ::Components::WorkPackages::TableConfiguration::Filters.new }
  let(:columns) { ::Components::WorkPackages::Columns.new }
  let(:filters) { ::Components::WorkPackages::Filters.new }
  let(:wp_table) { ::Pages::WorkPackagesTable.new }

  before do
    login_as admin
  end

  it 'can manage and browse the project portfolio Gantt' do
    visit projects_settings_path

    # It has checked all selected settings
    Setting.enabled_projects_columns.each do |name|
      expect(page).to have_selector(%(input[value="#{name}"]:checked))
    end

    # Uncheck all selected columns
    page.all('.form--matrix input[type="checkbox"]').each do |el|
      el.uncheck if el.checked?
    end

    # Check the status and custom field only
    find('input[value="project_status"]').check
    find(%(input[value="cf_#{string_cf.id}"])).check

    expect(page).to have_selector('input[value="project_status"]:checked')
    expect(page).to have_selector(%(input[value="cf_#{string_cf.id}"]:checked))

    # Edit the project gantt query
    scroll_to_and_click(find('a', text: 'Edit query'))

    columns.assume_opened
    columns.uncheck_all save_changes: false
    columns.add 'ID', save_changes: false
    columns.add 'Subject', save_changes: false
    columns.add 'Project', save_changes: false

    modal.switch_to 'Filters'

    model_filters.expect_filter_count 2
    # Add a project filter that gets overridden
    model_filters.add_filter_by('Project', 'is', project_a.name)

    model_filters.add_filter_by('Type', 'is', type_milestone.name)
    model_filters.save

    # Save the page
    scroll_to_and_click(find('.button', text: 'Save'))

    expect(page).to have_selector('.flash.notice', text: 'Successful update.')

    RequestStore.clear!
    query = JSON.parse Setting.project_gantt_query
    expect(query['f']).to include({ 'n' => 'type', 'o' => '=', 'v' => [type_milestone.id.to_s] })

    # Go to project page
    visit projects_path

    # Click the gantt button
    new_window = window_opened_by { click_on 'Open as Gantt view' }
    switch_to_window new_window

    wp_table.expect_work_package_listed work_package_a, work_package_b

    # Expect grouped and filtered for both projects
    expect(page).to have_selector '.group--value', text: 'A'
    expect(page).to have_selector '.group--value', text: 'B'

    # Expect status, type and project filters
    filters.expect_filter_count 3
    filters.open

    filters.expect_filter_by('Type', 'is', [type_milestone.name])
    filters.expect_filter_by('Project', 'is', [project_a.name, project_b.name])

    # Expect columns
    columns.open_modal
    columns.expect_checked 'ID'
    columns.expect_checked 'Subject'
    columns.expect_checked 'Project'

    columns.expect_unchecked 'Assignee'
    columns.expect_unchecked 'Type'
    columns.expect_unchecked 'Priority'
  end
end
