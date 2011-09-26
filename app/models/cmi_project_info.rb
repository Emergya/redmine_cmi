class CmiProjectInfo < ActiveRecord::Base
  belongs_to :project

  validates_presence_of :project

  validates_format_of :actual_start_date, :with => /^\d{4}-\d{2}-\d{2}$/, :message => :not_a_date, :allow_nil => false
  validates_format_of :scheduled_start_date, :with => /^\d{4}-\d{2}-\d{2}$/, :message => :not_a_date, :allow_nil => false
  validates_format_of :scheduled_finish_date, :with => /^\d{4}-\d{2}-\d{2}$/, :message => :not_a_date, :allow_nil => false

  validates_numericality_of :scheduled_qa_meetings, :only_integer => true
  validates_numericality_of :scheduled_material_budget
  validates_numericality_of :total_income

  serialize :scheduled_role_effort, Hash

  validate :role_effort

  def scheduled_role_effort
    self[:scheduled_role_effort] ||= {}
  end

  private

  # Role effort validation
  def role_effort
    User.roles.each do |role|
      unless scheduled_role_effort[role] =~ /\A[+-]?\d+\Z/
        error = [I18n.translate(:"cmi.label_scheduled_role_effort", :role => role),
                 I18n.translate(:"activerecord.errors.messages.not_a_number")].join " "
        errors.add_to_base(error)
      end
    end
  end
end
