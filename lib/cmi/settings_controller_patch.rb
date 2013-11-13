require 'dispatcher'

# Patches Redmine's Issue dynamically.  Adds relationships
# Issue +has_one+ to Incident and ImprovementAction
module CMI
  module SettingsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will be reloaded in development
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def show_tracker_custom_fields
        render :layout => false
      end 
    end
  end
end

Dispatcher.to_prepare do
  require_dependency 'settings_controller'
  SettingsController.send(:include, CMI::SettingsControllerPatch)
end
