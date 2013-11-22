require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

module CMI
  module IssueBpoDatesRequiredPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable

        validate :issue_dates_required
      end
    end

    module ClassMethods
      
    end

    module InstanceMethods
      def issue_dates_required
        if due_date.nil? && tracker.id == Setting.plugin_redmine_cmi['bpo_tracker'].to_i
          errors.add :due_date, :empty        
        end
        if start_date.nil? && tracker.id == Setting.plugin_redmine_cmi['bpo_tracker'].to_i 
          errors.add :start_date, :empty
        end
      end
    end

  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    # use require_dependency if you plan to utilize development mode
    Issue.send(:include, CMI::IssueBpoDatesRequiredPatch)
  end
else
  Dispatcher.to_prepare do
    Issue.send(:include, CMI::IssueBpoDatesRequiredPatch)
  end
end