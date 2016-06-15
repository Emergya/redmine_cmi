class CmiCheckpoint < ActiveRecord::Base
  unloadable

  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  has_many :cmi_checkpoint_efforts, :dependent => :destroy, :inverse_of => :cmi_checkpoint
  has_many :journals, :as => :journalized, :dependent => :destroy

  accepts_nested_attributes_for :cmi_checkpoint_efforts, :allow_destroy => true

  validates_presence_of :project, :author
  validates_format_of :checkpoint_date, :with => /^\d{4}-\d{2}-\d{2}$/, :message => :not_a_date, :allow_nil => false
  validates_format_of :scheduled_finish_date, :with => /^\d{4}-\d{2}-\d{2}$/, :message => :not_a_date, :allow_nil => false
  validates_numericality_of :held_qa_meetings, :only_integer => true
  validate :role_efforts
  validate :base_line, :only_integer => true, :allow_nil => false
  validate :target_margin, numericality: { only_integer: true }, :inclusion => (0..100), :allow_nil => false

  attr_protected :project_id, :author_id
  attr_reader :current_journal
  after_save :create_journal, :set_first_base_line
  after_destroy :set_first_base_line

  def attachments
    []
  end

  def initialize(copy_from_project=nil)
    if copy_from_project.is_a? Project
      previous = CmiCheckpoint.find :first,
                                    :conditions => ['project_id = ?', copy_from_project],
                                    :order => 'checkpoint_date DESC'
      super((previous.nil? ? {} : previous.attributes).merge(:checkpoint_date => Date.today))

      if previous.present?
        # Copy previous checkpoint efforts
        efforts = previous.cmi_checkpoint_efforts
        efforts.each do |eff|
          eff.id = nil
          eff.created_at = Date.today
          eff.updated_at = Date.today
        end
        self.cmi_checkpoint_efforts = efforts
      end
    else
      super
    end
  end

  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)
    @self_before_change = self.clone
    @scheduled_role_effort_hash_before_change = scheduled_role_effort_hash
    # Make sure updated_on is updated when adding a note.
    updated_at_will_change!
    @current_journal
  end

  def scheduled_role_effort(role)
    effort = cmi_checkpoint_efforts.detect{ |effort| effort.role == role }
    effort.nil? ? 0.0 : effort.scheduled_effort
  end

  def scheduled_role_effort_id(role)
    effort = cmi_checkpoint_efforts.detect{ |effort| effort.role == role }
    effort.nil? ? nil : effort.id
  end

  def cmi_checkpoint_efforts_attributes_with_auto_delete=(attrs)
    @cmi_checkpoint_efforts_attributes = attrs
    cmi_checkpoint_efforts.each do |old|
      old.mark_for_destruction unless attrs.detect{ |new| new["role"] == old.role }
    end
    self.cmi_checkpoint_efforts_attributes_without_auto_delete = attrs
  end
  alias_method_chain :cmi_checkpoint_efforts_attributes=, :auto_delete

  private

  def scheduled_role_effort_hash
    cmi_checkpoint_efforts.reduce({}) do |hash, effort|
      hash.merge! effort.role => effort.scheduled_effort
    end
  end

  # Role effort validation
  def role_efforts
    User.roles.each do |role|
      attr = @cmi_checkpoint_efforts_attributes.try(:detect){ |effort| effort['role'] == role }
      if attr
        begin
          Kernel.Float attr['scheduled_effort']
        rescue ArgumentError
          error = [I18n.translate(:"cmi.label_scheduled_role_effort", :role => role),
                   I18n.translate(:"activerecord.errors.messages.not_a_number")].join " "
          errors.add(:base, error)
        end
      end
    end
  end

  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if @current_journal
      # attributes changes
      (self.class.column_names - %w(id author_id created_at updated_at)).each {|c|
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => c,
                                                      :old_value => @self_before_change.send(c),
                                                      :value => send(c)) unless send(c) == @self_before_change.send(c)
      }
      # scheduled role effort
      unless scheduled_role_effort_hash == @scheduled_role_effort_hash_before_change
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => 'scheduled_role_effort',
                                                      :old_value => @scheduled_role_effort_hash_before_change,
                                                      :value => scheduled_role_effort_hash)
      end
      # custom fields changes
      @current_journal.save
      # reset current journal
      init_journal @current_journal.user, @current_journal.notes
    end
  end

  # Update oldest checkpoint as base line
  # Called after_save and after_destroy
  def set_first_base_line
    first_checkpoint = project.first_checkpoint
    
    if first_checkpoint.present? && !first_checkpoint.base_line
      first_checkpoint.base_line = true
      first_checkpoint.save
    end
  end
end
