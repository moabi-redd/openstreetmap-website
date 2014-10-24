class GroupCommentsController < ApplicationController
  layout 'site'
  
  before_filter :authorize_web
  before_filter :set_locale
  before_filter :check_database_readable
  before_filter :check_database_writable
  
  before_filter :require_user,  :except => [:index, :show ]
                
  before_filter :find_group
  before_filter :find_comment, :only => [:show, :edit, :update, :destroy]
  before_filter :require_author, :only => [:edit, :update ]
  before_filter :require_author_moderator_or_lead, :only => [:destroy ]
  

  def index
    @group_comments = @group.root_comments.visible
    
    @page = (params[:page] || 1).to_i
    @page_size = 5

    @group_comments = @group_comments.order("created_at DESC")
    @group_comments = @group_comments.offset((@page - 1) * @page_size)
    @group_comments = @group_comments.limit(@page_size)    
  end
  
  def show
  end
  
  def new
    @group_comment = @group.comments.build
  end
  
  def reply
    @parent_comment = GroupComment.find(params[:comment_id])
    @group_comment = @group.comments.new(:parent_id => @parent_comment.id)
    render :new
  end
  
  def create
    @group_comment = GroupComment.new(group_comment_params)
    @group_comment.author = @user
    @group_comment.group = @group
    if  @group_comment.save
      flash[:notice] = "comment saved"
      if group_comment_params[:parent_id].nil?
        redirect_to :action => "show", :id => @group_comment.id, :group_id => @group.id
      else
        redirect_to :action => "show", :id => group_comment_params[:parent_id], :group_id => @group.id
      end
    else
      flash[:error] = "Something went wrong trying to save this"
      render :action => "new"
    end
  end
  
  def edit
    @group_comment = GroupComment.find(params[:id])
  end
  
  def update
    if @group_comment.update_attributes(group_comment_params)
      flash[:notice] = "comment updated"
      redirect_to :action => "show", :id => @group_comment.id, :group_id => @group.id
    else
      flash[:notice] = "Something went wrong trying to update this"
      render:action => "edit"
    end
  end
  
  def destroy    
    if @group_comment.update_attributes(:visible => false)
      flash[:notice] = "Comment deleted"
    else
      flash[:error] = "Something went wrong trying to delete the comment"
    end
    redirect_to :back
  end
  
  private

  def group_comment_params
    params.require(:group_comment).permit(:title, :body, :parent_id) 
  end
  
  def find_group
    @group = Group.find(params[:group_id])
  end
  
  def find_comment
    @group_comment =  GroupComment.where({:id => params[:id].to_i, :visible => true}).take!
  end
  
  def require_author
   unless @group_comment.author == @user
     flash[:error] = "Action not permitted. User is not the author"
     redirect_to :index
   end
  end
  
  def require_author_moderator_or_lead
     unless @group_comment.author == @user || @user.moderator? || @group.leadership_includes?(@user)
      flash[:error] = "Action not permitted. User is not the author or moderator or a group lead"
      redirect_to :index
    end
  end

  
end
