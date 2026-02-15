class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]

  def new
  end

  def create
    user = User.find_by(username: params[:username].to_s)
    if user&.authenticate(params[:password].to_s)
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "ログインしました"
    else
      flash.now[:alert] = "アカウント名またはパスワードが違います"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "ログアウトしました"
  end
end

