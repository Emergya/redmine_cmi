class CheckpointsController < ApplicationController
  unloadable

  menu_item :metrics
  before_filter :find_project_by_project_id, :authorize
  before_filter :get_roles, :only => [:new, :edit, :show]
  before_filter :find_checkpoint, :only => [:show, :edit, :update, :destroy]

  helper :cmi

  def index
    @limit = per_page_option
    @count = CmiCheckpoint.where('project_id = ?', @project).count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.current.offset
    @sort = sort_column
    @order = sort_direction
    @checkpoints = CmiCheckpoint.all(:conditions => ['project_id = ?', @project],
                                     :order => [@sort, @order].join(' '),
                                     :offset => @offset,
                                     :limit => @limit,
                                     :include => :cmi_checkpoint_efforts)
  end

  def new
    @checkpoint = CmiCheckpoint.new @project
    
    if @project.first_checkpoint.blank?
      @checkpoint.base_line = true
    else
      @checkpoint.base_line = false
    end
    
    @roles.each do |role|
      @checkpoint.cmi_checkpoint_efforts.build :role => role
    end
  end

  def create
    @checkpoint = CmiCheckpoint.new params[:checkpoint]
    @checkpoint.project = @project
    @checkpoint.author = User.current
    if @checkpoint.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => :index
    else
      get_roles
      render :action => 'new'
    end
  end

  def show
    @journals = @checkpoint.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  def edit
    @journal = @checkpoint.current_journal
  end

  def update
    @checkpoint.init_journal(User.current, params[:notes])
    @checkpoint.attributes = params[:checkpoint]
    if @checkpoint.save
      flash[:notice] = l(:notice_successful_update)
      redirect_back_or_default({:action => 'show', :id => @checkpoint})
    else
      get_roles
      @journal = @checkpoint.current_journal
      render :action => 'edit'
    end
  end

  def destroy
    @checkpoint.destroy
    redirect_back_or_default(:action => 'index', :project_id => @project)
  end

  def preview
    find_checkpoint unless params[:id].blank?
    if @checkpoint
      @description = params[:checkpoint] && params[:checkpoint][:description]
      if @description && @description.gsub(/(\r?\n|\n\r?)/, "\n") == @checkpoint.description.to_s.gsub(/(\r?\n|\n\r?)/, "\n")
        @description = nil
      end
      @notes = params[:notes]
    else
      @description = (params[:checkpoint] ? params[:checkpoint][:description] : nil)
    end
    render :layout => false
  end

  def new_journal
    journal = Journal.find(params[:journal_id]) if params[:journal_id]
    if journal
      user = journal.user
      text = journal.notes
    else
      find_checkpoint
      user = @checkpoint.author
      text = @checkpoint.description
    end
    # Replaces pre blocks with [...]
    text = text.to_s.strip.gsub(%r{<pre>((.|\s)*?)</pre>}m, '[...]')
    content = "#{ll(Setting.default_language, :text_user_wrote, user)}\n> "
    content << text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"

    render(:update) { |page|
      page.<< "$('notes').value = \"#{escape_javascript content}\";"
      page.show 'update'
      page << "Form.Element.focus('notes');"
      page << "Element.scrollTo('update');"
      page << "$('notes').scrollTop = $('notes').scrollHeight - $('notes').clientHeight;"
    }
  end

  def edit_journal
    @journal = Journal.find(params[:id])
    (render_403; return false) unless @journal.editable_by?(User.current)
    if request.post?
      @journal.update_attributes(:notes => params[:notes]) if params[:notes]
      @journal.destroy if @journal.details.empty? && @journal.notes.blank?
      respond_to do |format|
        format.html { redirect_to :action => 'show', :id => @journal.journalized_id }
        format.js { render :template => 'metrics/update' }
      end
    else
      respond_to do |format|
        format.html {
          # TODO: implement non-JS journal update
          render :nothing => true
        }
        format.js { render :template => 'metrics/edit_journal' }
      end
    end
  end

  private

  def find_checkpoint
    @checkpoint = CmiCheckpoint.find params[:id], :include => :cmi_checkpoint_efforts
    unless @checkpoint.project_id == @project.id
      deny_access
      return
    end
  end

  def sort_column
    CmiCheckpoint.column_names.include?(params[:sort]) ? params[:sort] : "checkpoint_date"
  end

  def sort_direction
    %w[asc desc].include?(params[:order]) ? params[:order] : "desc"
  end

  def get_roles
    @roles = User.roles
  end
end
