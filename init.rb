Dir["#{File.dirname(__FILE__)}/config/initializers/**/*.rb"].sort.each do |initializer|
  Kernel.load(initializer)
end

require 'redmine'
require 'scoreboard_menu_helper_patch'
require 'issue_patch'
require 'timelog_controller_patch'
require 'users_controller_patch'
require 'user_patch'
require 'users_helper_patch'
require 'project_patch'

Redmine::Plugin.register :redmine_cmiplugin do
  name 'cmi.plugin_name'.to_sym
  author 'Emergya Consultoría'
  description 'cmi.plugin_description'.to_sym
  version '0.9.2'

  settings :default => { }

  requires_redmine :version_or_higher => '1.0.0'
  project_module :cmiplugin do
  #     permission :view_cmi, {:cmi => [:projects, :groups, :show]}
        permission :view_metrics, {:metrics => [:show]}
  end

  menu :project_menu, :metrics, {:controller => 'metrics', :action => 'show' }, :caption => 'cmi.caption_metrics'.to_sym, :after => :settings, :param => :project_id
  menu :top_menu, :cmi, {:controller => 'management', :action => 'projects'}, :caption => 'CMI', :if => Proc.new { User.current.admin? }
  menu :scoreboard_menu, :projects, {:controller => 'management', :action => 'projects' }, :caption => 'cmi.caption_projects'.to_sym
  menu :scoreboard_menu, :status, {:controller => 'management', :action => 'status' }, :caption => 'cmi.caption_status'.to_sym
  menu :scoreboard_menu, :groups, {:controller => 'management', :action => 'groups' }, :caption => 'cmi.caption_groups'.to_sym
  menu :admin_menu, 'cmi.label_cost_history'.to_sym, {:controller => 'admin', :action => 'cost_history'}, :class => 'issue_statuses', :caption => 'cmi.label_cost_history'.to_sym
end
